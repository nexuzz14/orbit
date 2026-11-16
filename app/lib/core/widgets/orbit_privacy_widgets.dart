import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';

/// Menampilkan nominal mata uang yang otomatis tersamarkan menjadi `Rp ••••••`
/// ketika Mode Privasi global aktif.
class OrbitAmountText extends StatelessWidget {
  final double amount;
  final String currency;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? forceHidden;

  const OrbitAmountText({
    super.key,
    required this.amount,
    this.currency = 'IDR',
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.forceHidden,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyModeController.instance.notifier,
      builder: (context, hidden, _) {
        final isHidden = forceHidden ?? hidden;
        final display = isHidden
            ? (currency == 'IDR'
                  ? PrivacyModeController.maskedPlaceholder
                  : '$currency ••••••')
            : '$prefix${formatRupiah(amount, currency: currency)}$suffix';

        return Text(
          display,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: (style ?? const TextStyle()).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

/// Builder reaktif terhadap perubahan Mode Privasi untuk teks nominal majemuk.
class OrbitPrivacyBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isHidden) builder;

  const OrbitPrivacyBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyModeController.instance.notifier,
      builder: (context, hidden, _) => builder(context, hidden),
    );
  }
}

/// Tombol ikon Mata di AppBar untuk mengaktifkan/menonaktifkan Mode Privasi.
class OrbitPrivacyToggleButton extends StatelessWidget {
  final VoidCallback? onToggled;

  const OrbitPrivacyToggleButton({super.key, this.onToggled});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyModeController.instance.notifier,
      builder: (context, hidden, _) {
        final tooltip = hidden
            ? 'Mode Privasi aktif (tampilkan nominal)'
            : 'Aktifkan Mode Privasi (sembunyikan nominal)';
        return Semantics(
          button: true,
          toggled: hidden,
          label: tooltip,
          child: SizedBox(
            width: AppTokens.minTouchTarget,
            height: AppTokens.minTouchTarget,
            child: IconButton(
              key: const Key('orbit_privacy_toggle_btn'),
              tooltip: tooltip,
              onPressed: () async {
                await PrivacyModeController.instance.toggle();
                onToggled?.call();
              },
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Gerbang kunci aplikasi (PIN / Biometrik) yang aktif HANYA jika pengguna
/// mengaktifkan kunci di Pengaturan Keamanan (default nonaktif).
class OrbitAppLockGate extends StatefulWidget {
  final Widget child;

  const OrbitAppLockGate({super.key, required this.child});

  @override
  State<OrbitAppLockGate> createState() => _OrbitAppLockGateState();
}

class _OrbitAppLockGateState extends State<OrbitAppLockGate>
    with WidgetsBindingObserver {
  final TextEditingController _pinController = TextEditingController();
  String? _errorText;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLockService.instance.handleAppLifecycleState(state);
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (!AppLockService.isValidPinFormat(pin)) {
      setState(() => _errorText = 'Masukkan PIN 4 sampai 6 digit angka.');
      return;
    }
    setState(() {
      _verifying = true;
      _errorText = null;
    });
    final ok = await AppLockService.instance.verifyPin(pin);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      if (ok) {
        _pinController.clear();
        _errorText = null;
      } else {
        _errorText = 'PIN tidak cocok. Coba lagi.';
      }
    });
  }

  Future<void> _triggerBiometric() async {
    setState(() => _errorText = null);
    final ok = await AppLockService.instance.authenticateWithBiometrics();
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _errorText = 'Verifikasi biometrik gagal. Gunakan PIN Anda.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLockService.instance.isLockEnabledNotifier,
      builder: (context, lockEnabled, _) {
        if (!lockEnabled) {
          return widget.child;
        }
        return ValueListenableBuilder<bool>(
          valueListenable: AppLockService.instance.isLockedNotifier,
          builder: (context, locked, _) {
            if (!locked) {
              return widget.child;
            }
            return Scaffold(
              backgroundColor: AppColors.canvasColor(context),
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 36,
                                color: AppColors.accentColor(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Orbit Terkunci',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Masukkan PIN untuk membuka workspace pribadi Anda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondaryColor(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const Key('orbit_lock_pin_field'),
                                controller: _pinController,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onSubmitted: (_) => _submitPin(),
                                decoration: InputDecoration(
                                  labelText: 'PIN (4-6 digit)',
                                  errorText: _errorText,
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: AppTokens.minTouchTarget,
                                child: FilledButton(
                                  key: const Key('orbit_lock_unlock_btn'),
                                  onPressed: _verifying ? null : _submitPin,
                                  child: Text(
                                    _verifying ? 'Memeriksa...' : 'Buka Kunci',
                                  ),
                                ),
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: AppLockService
                                    .instance
                                    .isBiometricEnabledNotifier,
                                builder: (context, bioEnabled, _) {
                                  if (!bioEnabled) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: SizedBox(
                                      height: AppTokens.minTouchTarget,
                                      child: OutlinedButton.icon(
                                        key: const Key(
                                          'orbit_lock_biometric_btn',
                                        ),
                                        onPressed: _triggerBiometric,
                                        icon: const Icon(
                                          Icons.fingerprint_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('Gunakan Biometrik'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
