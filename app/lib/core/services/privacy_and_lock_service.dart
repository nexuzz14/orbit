import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstraksi penyimpanan aman untuk PIN & flag kunci aplikasi.
abstract class SecureLockStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureLockStorageAdapter implements SecureLockStorageAdapter {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // Aman diabaikan saat headless test tanpa plugin native.
    } on PlatformException {
      // Aman diabaikan bila keystore belum tersedia.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // Aman diabaikan saat headless test.
    } on PlatformException {
      // Aman diabaikan.
    }
  }
}

/// Penyimpanan in-memory untuk pengujian unit & widget headless.
class InMemorySecureLockStorage implements SecureLockStorageAdapter {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// Abstraksi autentikasi biometrik agar mudah diuji dan aman saat offline/headless.
abstract class BiometricAuthAdapter {
  Future<bool> isAvailable();
  Future<bool> authenticate({required String reason});
}

class MethodChannelBiometricAdapter implements BiometricAuthAdapter {
  static const MethodChannel _channel = MethodChannel(
    'id.my.nabilcf.orbit/biometric',
  );

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      final result = await _channel.invokeMethod<bool>('authenticate', {
        'title': 'Buka Kunci Orbit',
        'subtitle': reason,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Pengendali global Mode Privasi (menyembunyikan nominal Rupiah menjadi Rp ••••••)
/// serta opsi menyembunyikan saldo di Widget Android.
class PrivacyModeController {
  PrivacyModeController._();

  static final PrivacyModeController instance = PrivacyModeController._();

  static const String maskedPlaceholder = 'Rp ••••••';
  static const String _prefPrivacyMode = 'orbit_privacy_mode_enabled';
  static const String _prefHideWidgetBalance = 'orbit_widget_hide_balance';

  final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hideWidgetBalanceNotifier = ValueNotifier<bool>(
    false,
  );

  Future<void> Function()? _onPrivacyOrWidgetSettingChanged;
  bool _persistWithSharedPrefs = true;

  bool get enabled => notifier.value;
  bool get hideWidgetBalance => hideWidgetBalanceNotifier.value;
  bool get shouldMaskWidgetBalance => enabled || hideWidgetBalance;

  void registerSyncHook(Future<void> Function()? callback) {
    _onPrivacyOrWidgetSettingChanged = callback;
  }

  Future<void> load() async {
    if (!_persistWithSharedPrefs) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      notifier.value = prefs.getBool(_prefPrivacyMode) ?? false;
      hideWidgetBalanceNotifier.value =
          prefs.getBool(_prefHideWidgetBalance) ?? false;
    } on MissingPluginException {
      // Aman saat headless test.
    } catch (_) {
      // Aman diabaikan.
    }
  }

  Future<void> setEnabled(bool value) async {
    if (notifier.value == value) return;
    notifier.value = value;
    if (_persistWithSharedPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefPrivacyMode, value);
      } on MissingPluginException {
        // Headless test safe.
      } catch (_) {}
    }
    await _onPrivacyOrWidgetSettingChanged?.call();
  }

  Future<void> toggle() => setEnabled(!enabled);

  Future<void> setHideWidgetBalance(bool value) async {
    if (hideWidgetBalanceNotifier.value == value) return;
    hideWidgetBalanceNotifier.value = value;
    if (_persistWithSharedPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefHideWidgetBalance, value);
      } on MissingPluginException {
        // Headless test safe.
      } catch (_) {}
    }
    await _onPrivacyOrWidgetSettingChanged?.call();
  }

  void resetForTesting({
    bool initialPrivacy = false,
    bool initialHideWidgetBalance = false,
    bool persistWithSharedPrefs = false,
  }) {
    _persistWithSharedPrefs = persistWithSharedPrefs;
    notifier.value = initialPrivacy;
    hideWidgetBalanceNotifier.value = initialHideWidgetBalance;
    _onPrivacyOrWidgetSettingChanged = null;
  }

  /// Format nominal yang otomatis berubah menjadi `Rp ••••••` saat Mode Privasi aktif.
  static String formatAmount(
    double value, {
    String currency = 'IDR',
    bool? privacyOverride,
  }) {
    final isHidden = privacyOverride ?? instance.enabled;
    if (isHidden) {
      return currency == 'IDR' ? maskedPlaceholder : '$currency ••••••';
    }
    return formatRupiah(value, currency: currency);
  }
}

/// Layanan Kunci Aplikasi (PIN SHA-256 di flutter_secure_storage + Biometrik opt-in).
/// Default dalam kondisi nonaktif agar tidak menghalangi pengguna baru atau test.
class AppLockService {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  static const _keyLockEnabled = 'orbit_app_lock_enabled_v1';
  static const _keyBiometricEnabled = 'orbit_app_lock_biometric_v1';
  static const _keyPinHash = 'orbit_app_lock_pin_hash_v1';
  static const _keyPinSalt = 'orbit_app_lock_pin_salt_v1';

  SecureLockStorageAdapter _storage = FlutterSecureLockStorageAdapter();
  BiometricAuthAdapter _biometric = MethodChannelBiometricAdapter();

  final ValueNotifier<bool> isLockEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBiometricEnabledNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> hasPinNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  bool get isLockEnabled => isLockEnabledNotifier.value;
  bool get isBiometricEnabled => isBiometricEnabledNotifier.value;
  bool get hasPin => hasPinNotifier.value;
  bool get isLocked => isLockedNotifier.value;

  void overrideForTesting({
    SecureLockStorageAdapter? storage,
    BiometricAuthAdapter? biometric,
  }) {
    _storage = storage ?? InMemorySecureLockStorage();
    _biometric = biometric ?? MethodChannelBiometricAdapter();
    isLockEnabledNotifier.value = false;
    isBiometricEnabledNotifier.value = false;
    hasPinNotifier.value = false;
    isLockedNotifier.value = false;
    _failedAttempts = 0;
  }

  void resetToDefaults() {
    _storage = FlutterSecureLockStorageAdapter();
    _biometric = MethodChannelBiometricAdapter();
  }

  Future<void> init() async {
    final enabledRaw = await _storage.read(_keyLockEnabled);
    final biometricRaw = await _storage.read(_keyBiometricEnabled);
    final hashRaw = await _storage.read(_keyPinHash);

    final hasPin = hashRaw != null && hashRaw.isNotEmpty;
    final enabled = enabledRaw == 'true' && hasPin;
    final biometric = biometricRaw == 'true' && enabled;

    hasPinNotifier.value = hasPin;
    isLockEnabledNotifier.value = enabled;
    isBiometricEnabledNotifier.value = biometric;
    isLockedNotifier.value = enabled;
    _failedAttempts = 0;
  }

  Future<bool> isBiometricAvailable() => _biometric.isAvailable();

  static bool isValidPinFormat(String pin) =>
      RegExp(r'^\d{4,6}$').hasMatch(pin.trim());

  /// Hitung digest SHA-256 dengan salt acak (tidak pernah menyimpan PIN polos).
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  static String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> setupPin(String pin, {bool enableBiometric = false}) async {
    final cleaned = pin.trim();
    if (!isValidPinFormat(cleaned)) {
      throw ArgumentError('PIN harus berupa 4 sampai 6 digit angka.');
    }
    final salt = _generateSalt();
    final digest = hashPin(cleaned, salt);

    await _storage.write(_keyPinSalt, salt);
    await _storage.write(_keyPinHash, digest);
    await _storage.write(_keyLockEnabled, 'true');
    await _storage.write(
      _keyBiometricEnabled,
      enableBiometric ? 'true' : 'false',
    );

    hasPinNotifier.value = true;
    isLockEnabledNotifier.value = true;
    isBiometricEnabledNotifier.value = enableBiometric;
    isLockedNotifier.value = false;
    _failedAttempts = 0;
  }

  Future<bool> verifyPin(String pin, {bool unlockOnSuccess = true}) async {
    final salt = await _storage.read(_keyPinSalt);
    final storedHash = await _storage.read(_keyPinHash);
    if (salt == null || storedHash == null || storedHash.isEmpty) {
      return false;
    }
    final candidateHash = hashPin(pin, salt);
    final matched = _constantTimeEquals(candidateHash, storedHash);
    if (matched) {
      _failedAttempts = 0;
      if (unlockOnSuccess) {
        isLockedNotifier.value = false;
      }
    } else {
      _failedAttempts += 1;
    }
    return matched;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (!hasPinNotifier.value) {
      await _storage.write(_keyBiometricEnabled, 'false');
      isBiometricEnabledNotifier.value = false;
      return;
    }
    await _storage.write(_keyBiometricEnabled, enabled ? 'true' : 'false');
    isBiometricEnabledNotifier.value = enabled;
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Verifikasi identitas untuk membuka aplikasi Orbit',
  }) async {
    if (!isLockEnabledNotifier.value || !isBiometricEnabledNotifier.value) {
      return false;
    }
    final ok = await _biometric.authenticate(reason: reason);
    if (ok) {
      _failedAttempts = 0;
      isLockedNotifier.value = false;
    }
    return ok;
  }

  Future<void> disableLock() async {
    await _storage.write(_keyLockEnabled, 'false');
    await _storage.write(_keyBiometricEnabled, 'false');
    await _storage.delete(_keyPinHash);
    await _storage.delete(_keyPinSalt);

    hasPinNotifier.value = false;
    isLockEnabledNotifier.value = false;
    isBiometricEnabledNotifier.value = false;
    isLockedNotifier.value = false;
    _failedAttempts = 0;
  }

  void lockNow() {
    if (isLockEnabledNotifier.value) {
      isLockedNotifier.value = true;
    }
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lockNow();
    }
  }
}
