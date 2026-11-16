import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/android_auto_capture_bridge.dart';
import 'package:orbit_app/core/services/bank_notification_parser.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/notification_service.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const MethodChannel _homeWidgetChannel = MethodChannel(
    'id.my.nabilcf.orbit/home_widget',
  );

  OrbitNotificationPrefs _prefs = const OrbitNotificationPrefs();
  bool _loading = true;
  bool _notificationsEnabled = false;
  List<PendingNotificationRequest> _pending = [];
  List<LocalWorkspaceMember> _members = const [];
  List<LocalCalendarConnection> _calendarConnections = const [];
  List<Map<String, dynamic>> _invites = const [];
  String? _statusMessage;

  // Wave 3 state
  bool _bankAccessGranted = false;
  bool _bankListenerEnabled = false;
  Set<String> _bankWhitelist = {};
  WeeklyDigestSummary? _weeklyDigest;
  int _conflictCount = 0;
  int _stagnantCount = 0;
  OrbitWidgetSnapshot? _widgetSnapshot;
  bool _biometricAvailable = false;
  OutboxHealthSummary? _outboxHealth;
  final TextEditingController _parserTestController = TextEditingController();
  String? _parserTestOutput;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _parserTestController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    if (_prefs == const OrbitNotificationPrefs() && _weeklyDigest == null) {
      setState(() => _loading = true);
    }

    // Fase 1: muat preferensi lokal, status notifikasi, dan ringkasan Drift DB
    // tanpa menunggu MethodChannel/jaringan agar UI tampil seketika.
    final coreResults = await Future.wait<dynamic>([
      OrbitNotificationPrefs.load(),
      NotificationService.areNotificationsEnabled(),
      NotificationService.getPendingRequests(),
      AndroidAutoCaptureBridge.instance.loadListenerEnabledPref(),
      AndroidAutoCaptureBridge.instance.loadWhitelistedPackages(),
    ]);

    final prefs = coreResults[0] as OrbitNotificationPrefs;
    final enabled = coreResults[1] as bool;
    final pending = coreResults[2] as List<PendingNotificationRequest>;
    final bankEnabled = coreResults[3] as bool;
    final whitelist = coreResults[4] as Set<String>;

    List<LocalWorkspaceMember> members = const [];
    List<LocalCalendarConnection> calConns = const [];
    WeeklyDigestSummary? digest;
    OrbitWidgetSnapshot? widgetSnap;
    OutboxHealthSummary? outboxHealth;
    int conflicts = 0;
    int stagnants = 0;

    try {
      final db = AppDatabase.shared;
      final dbResults = await Future.wait<dynamic>([
        db.select(db.localEvents).get(),
        db.select(db.localTasks).get(),
        db.select(db.localRecurringBills).get(),
        db.select(db.localBudgets).get(),
        db.select(db.localTransactions).get(),
        db.select(db.localCategories).get(),
        HomeWidgetBridge.buildSnapshotFromDatabase(db),
        SyncService.instance.getOutboxHealthSummary(),
      ]);

      final events = dbResults[0] as List<LocalEvent>;
      final tasks = dbResults[1] as List<LocalTask>;
      final bills = dbResults[2] as List<LocalRecurringBill>;
      final budgets = dbResults[3] as List<LocalBudget>;
      final txs = dbResults[4] as List<LocalTransaction>;
      final cats = dbResults[5] as List<LocalCategory>;
      widgetSnap = dbResults[6] as OrbitWidgetSnapshot;
      outboxHealth = dbResults[7] as OutboxHealthSummary;

      final plan = NotificationSchedulerService.evaluatePlan(
        nowUtc: DateTime.now().toUtc(),
        prefs: prefs,
        events: events,
        tasks: tasks,
        bills: bills,
        budgets: budgets,
        transactions: txs,
        categories: cats,
      );
      digest = plan.weeklyDigest;
      conflicts = plan.scheduleConflicts.length;
      stagnants = plan.stagnantTasks.length;

      final wsId =
          (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
      final wsLocal = await Future.wait<dynamic>([
        (db.select(
          db.localWorkspaceMembers,
        )..where((m) => m.workspaceId.equals(wsId))).get(),
        (db.select(
          db.localCalendarConnections,
        )..where((c) => c.workspaceId.equals(wsId))).get(),
      ]);
      members = wsLocal[0] as List<LocalWorkspaceMember>;
      calConns = wsLocal[1] as List<LocalCalendarConnection>;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _notificationsEnabled = enabled;
      _pending = pending;
      _members = members;
      _calendarConnections = calConns;
      _bankListenerEnabled = bankEnabled;
      _bankWhitelist = whitelist;
      _weeklyDigest = digest;
      _conflictCount = conflicts;
      _stagnantCount = stagnants;
      _widgetSnapshot = widgetSnap;
      _outboxHealth = outboxHealth;
      _loading = false;
    });

    // Fase 2: cek izin OS native (NotificationListener, Biometric) & undangan jaringan.
    unawaited(_loadPlatformAndNetworkExtras());
  }

  Future<void> _loadPlatformAndNetworkExtras() async {
    try {
      final results = await Future.wait<dynamic>([
        AndroidAutoCaptureBridge.instance.isNotificationAccessGranted(),
        AppLockService.instance.isBiometricAvailable(),
        SyncService.instance.fetchWorkspaceInvites(),
      ]);
      if (!mounted) return;
      setState(() {
        _bankAccessGranted = results[0] as bool;
        _biometricAvailable = results[1] as bool;
        _invites = results[2] as List<Map<String, dynamic>>;
      });
    } catch (_) {}
  }

  Future<void> _copyWeeklyDigest() async {
    final text = _weeklyDigest?.summaryText ?? 'Ringkasan Mingguan Orbit belum tersedia.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Ringkasan mingguan disalin ke papan klip.';
    });
  }

  Future<void> _emailWeeklyDigest() async {
    final text = _weeklyDigest?.summaryText ?? 'Ringkasan Mingguan Orbit';
    var launched = false;
    try {
      launched =
          await _homeWidgetChannel.invokeMethod<bool>('openMailto', {
            'subject': 'Ringkasan Mingguan Orbit',
            'body': text,
          }) ??
          false;
    } on MissingPluginException {
      launched = false;
    } on PlatformException {
      launched = false;
    }
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    if (!mounted) return;
    setState(() {
      _statusMessage = launched
          ? 'Membuka aplikasi email dengan ringkasan mingguan.'
          : 'Ringkasan disalin ke papan klip (aplikasi email belum tersedia).';
    });
  }

  Future<void> _refreshWidgetsNow() async {
    final snap = await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
    await HomeWidgetBridge.triggerBackgroundRefreshNow();
    if (!mounted) return;
    setState(() {
      _widgetSnapshot = snap;
      _statusMessage =
          'Widget Android disegarkan (${snap.updatedAtLabelWib}, saldo: ${snap.balanceDisplayText}).';
    });
  }

  Future<void> _showSetupPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            AppLockService.instance.hasPin
                ? 'Ubah PIN Aplikasi'
                : 'Pasang PIN Aplikasi',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan 4 sampai 6 digit angka. PIN disimpan sebagai hash SHA-256 pada penyimpanan terenkripsi perangkat.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('settings_setup_pin_field'),
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN baru (4-6 digit)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('settings_setup_pin_confirm_field'),
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Konfirmasi PIN',
                  errorText: errorMsg,
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('settings_setup_pin_save_btn'),
              onPressed: () async {
                final pin = pinController.text.trim();
                final confirm = confirmController.text.trim();
                if (!AppLockService.isValidPinFormat(pin)) {
                  setDialogState(
                    () => errorMsg = 'PIN harus 4 sampai 6 digit angka.',
                  );
                  return;
                }
                if (pin != confirm) {
                  setDialogState(
                    () => errorMsg = 'Konfirmasi PIN tidak cocok.',
                  );
                  return;
                }
                await AppLockService.instance.setupPin(
                  pin,
                  enableBiometric: _biometricAvailable,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() {
                    _statusMessage = 'Kunci PIN aplikasi diaktifkan.';
                  });
                }
              },
              child: const Text('Simpan PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _runLocalParserTest() {
    final parsed = BankNotificationParser.parse(
      title: 'Uji Notifikasi Lokal',
      body: _parserTestController.text,
    );
    if (!parsed.accepted || parsed.amount <= 0) {
      setState(() {
        _parserTestOutput =
            'Ditolak: ${parsed.rejectionReason ?? 'Nominal <= 0 atau format tidak dikenali.'}';
      });
      return;
    }
    final statusBadge = parsed.needsReview ? 'Perlu dicek' : 'Siap';
    setState(() {
      _parserTestOutput =
          '${parsed.provider} | ${parsed.type == 'income' ? '+' : '-'}${parsed.amount.toStringAsFixed(0)} ${parsed.currency} | Merchant: ${parsed.merchant ?? '-'} | Status: $statusBadge';
    });
  }

  Future<void> _updatePrefs(OrbitNotificationPrefs next) async {
    setState(() => _prefs = next);
    await next.save();
    final count =
        await NotificationSchedulerService.rescheduleAll(AppDatabase.shared);
    final pending = await NotificationService.getPendingRequests();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _statusMessage = 'Preferensi disimpan ($count pengingat dijadwalkan).';
    });
  }

  Future<void> _requestOsPermission() async {
    final granted = await NotificationService.requestPermission();
    final enabled = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = granted && enabled;
      _statusMessage = _notificationsEnabled
          ? 'Izin notifikasi Android aktif.'
          : 'Izin notifikasi masih ditolak. Aktifkan di Pengaturan sistem Android.';
    });
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _prefs.morningHour,
        minute: _prefs.morningMinute,
      ),
    );
    if (picked != null) {
      await _updatePrefs(
        _prefs.copyWith(
          morningHour: picked.hour,
          morningMinute: picked.minute,
        ),
      );
    }
  }

  Future<void> _sendInstantTest() async {
    await NotificationService.requestPermission();
    await NotificationService.showNotification(
      id: NotificationSchedulerService.testInstantId,
      title: 'Orbit: Notifikasi Aktif',
      body: 'Notifikasi dan deep link bekerja. Ketuk untuk membuka Hari Ini.',
      channelId: NotificationService.channelGeneralId,
      channelName: NotificationService.channelGeneralName,
      channelDescription: NotificationService.channelGeneralDesc,
      payload: const NotificationPayload(type: 'today', targetTab: 0),
    );
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Notifikasi tes instan telah dikirim.';
    });
  }

  Future<void> _schedule5SecondTest() async {
    await NotificationService.requestPermission();
    final targetTime = DateTime.now().add(const Duration(seconds: 5));
    await NotificationService.scheduleZonedNotification(
      id: NotificationSchedulerService.testScheduledId,
      title: 'Orbit: Tes Penjadwalan WIB',
      body: 'Notifikasi terjadwal (Asia/Jakarta) berhasil muncul setelah 5 detik.',
      scheduledAt: targetTime,
      channelId: NotificationService.channelScheduleId,
      channelName: NotificationService.channelScheduleName,
      channelDescription: NotificationService.channelScheduleDesc,
      payload: const NotificationPayload(
        type: 'task',
        targetTab: 1,
        agendaMode: 'tugas',
      ),
    );
    final pending = await NotificationService.getPendingRequests();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _statusMessage =
          'Notifikasi terjadwal untuk 5 detik lagi (${DateFormat('HH:mm:ss').format(targetTime)}). Anda dapat meminimalkan app untuk mengujinya.';
    });
  }

  Future<void> _rescheduleNow() async {
    final count =
        await NotificationSchedulerService.rescheduleAll(AppDatabase.shared);
    final pending = await NotificationService.getPendingRequests();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _statusMessage =
          'Berhasil menjadwalkan $count pengingat lokal (aktif di background & setelah restart).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final morningStr =
        '${_prefs.morningHour.toString().padLeft(2, '0')}:${_prefs.morningMinute.toString().padLeft(2, '0')} WIB';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan & Notifikasi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadState,
            tooltip: 'Segarkan status',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(AppTokens.space4),
              children: const [
                OrbitSkeleton(height: 88),
                SizedBox(height: AppTokens.space3),
                OrbitSkeleton(height: 220),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space3,
                AppTokens.space4,
                48,
              ),
              children: [
                if (_statusMessage != null) ...[
                  OrbitCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.accentColor(context),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                ],

                // Status Izin Android
                OrbitCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Status Izin Notifikasi Android',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          OrbitStatusBadge(
                            label: _notificationsEnabled ? 'Aktif' : 'Nonaktif',
                            variant: _notificationsEnabled
                                ? OrbitBadgeVariant.income
                                : OrbitBadgeVariant.expense,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        _notificationsEnabled
                            ? 'Android mengizinkan Orbit menampilkan pengingat jadwal, tenggat tugas, tagihan, dan ringkasan pagi.'
                            : 'Notifikasi masih diblokir oleh sistem Android. Ketuk tombol di bawah untuk mengizinkan.',
                        style: TextStyle(fontSize: 12, color: secondaryColor),
                      ),
                      const SizedBox(height: AppTokens.space3),
                      Wrap(
                        spacing: AppTokens.space2,
                        runSpacing: AppTokens.space2,
                        children: [
                          if (!_notificationsEnabled)
                            FilledButton.icon(
                              onPressed: _requestOsPermission,
                              icon: const Icon(Icons.notifications_active_outlined, size: 16),
                              label: const Text('Izinkan Notifikasi'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _sendInstantTest,
                            icon: const Icon(Icons.send_outlined, size: 16),
                            label: const Text('Tes Sekarang'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _schedule5SecondTest,
                            icon: const Icon(Icons.schedule, size: 16),
                            label: const Text('Tes Terjadwal 5 Detik'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Preferensi Pengingat (PRD M13 & M14)
                OrbitCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.space4,
                          AppTokens.space3,
                          AppTokens.space4,
                          AppTokens.space1,
                        ),
                        child: Text(
                          'Preferensi Pengingat Lokal (WIB)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Ringkasan Pagi', style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'Setiap hari pukul $morningStr (jumlah saja, tanpa judul sensitif)',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        value: _prefs.morningSummaryEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(morningSummaryEnabled: v),
                        ),
                      ),
                      if (_prefs.morningSummaryEnabled)
                        ListTile(
                          title: const Text('Jam Ringkasan Pagi', style: TextStyle(fontSize: 14)),
                          trailing: Text(
                            morningStr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentColor(context),
                            ),
                          ),
                          onTap: _pickMorningTime,
                        ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Pengingat Jadwal', style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${_prefs.defaultEventReminderMinutes} menit sebelum acara dimulai',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        value: _prefs.scheduleRemindersEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(scheduleRemindersEnabled: v),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Pengingat Tenggat Tugas', style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'H-1 pukul 18:00 WIB atau 1 jam sebelum batas waktu',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        value: _prefs.taskRemindersEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(taskRemindersEnabled: v),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Tagihan Rutin & Batas Anggaran', style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'Pengingat tagihan H-3/Hari-H dan peringatan anggaran 80%/100%',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        value: _prefs.billRemindersEnabled && _prefs.budgetAlertsEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(
                            billRemindersEnabled: v,
                            budgetAlertsEnabled: v,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Tampilkan Judul di Notifikasi', style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'Matikan untuk privasi di layar kunci (PRD 9.9).',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        value: _prefs.showTitleOnLockscreen,
                        onChanged: (v) async {
                          await _updatePrefs(
                            _prefs.copyWith(showTitleOnLockscreen: v),
                          );
                          await _loadState();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Ringkasan Mingguan & Pengingat Cerdas (Wave 3)
                OrbitCard(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ringkasan Mingguan & Pengingat Cerdas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jadwal bentrok hari ini: $_conflictCount | Tugas macet (>5 hari): $_stagnantCount',
                        style: TextStyle(fontSize: 12, color: secondaryColor),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Ringkasan Mingguan (Senin 08:00 WIB)',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _prefs.weeklyDigestEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(weeklyDigestEnabled: v),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Peringatan Jadwal Bentrok WIB',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _prefs.smartConflictAlertsEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(smartConflictAlertsEnabled: v),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Pengingat Tugas Macet (>5 hari)',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _prefs.stagnantTaskAlertsEnabled,
                        onChanged: (v) => _updatePrefs(
                          _prefs.copyWith(stagnantTaskAlertsEnabled: v),
                        ),
                      ),
                      if (_weeklyDigest != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.subtleColor(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.borderColor(context),
                            ),
                          ),
                          child: Text(
                            _weeklyDigest!.summaryText,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            height: AppTokens.minTouchTarget,
                            child: OutlinedButton.icon(
                              key: const Key('settings_copy_digest_btn'),
                              onPressed: _copyWeeklyDigest,
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              label: const Text('Salin Ringkasan'),
                            ),
                          ),
                          SizedBox(
                            height: AppTokens.minTouchTarget,
                            child: OutlinedButton.icon(
                              key: const Key('settings_email_digest_btn'),
                              onPressed: _emailWeeklyDigest,
                              icon: const Icon(Icons.mail_outline, size: 18),
                              label: const Text('Kirim Email (mailto)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Widget Android & Sync Latar (Wave 3)
                OrbitCard(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Widget Android & Sync Latar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menyediakan widget Hari Ini (4x2), Tugas (2x2), Tambah Cepat (4x1), dan Saldo (2x1) dengan pembaruan WorkManager 15 menit.',
                        style: TextStyle(fontSize: 12, color: secondaryColor),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: PrivacyModeController
                            .instance
                            .hideWidgetBalanceNotifier,
                        builder: (context, hideWidgetBal, _) => SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Sembunyikan Saldo Widget (Rp ••••••)',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: hideWidgetBal,
                          onChanged: (v) async {
                            await PrivacyModeController.instance
                                .setHideWidgetBalance(v);
                            await _refreshWidgetsNow();
                          },
                        ),
                      ),
                      if (_widgetSnapshot != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Pratinjau Saldo Widget: ${_widgetSnapshot!.balanceDisplayText}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: OutlinedButton.icon(
                          key: const Key('settings_refresh_widget_btn'),
                          onPressed: _refreshWidgetsNow,
                          icon: const Icon(Icons.widgets_outlined, size: 18),
                          label: const Text('Uji Segarkan Widget'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Pembaca Notifikasi Bank & Share Target (Wave 3)
                OrbitCard(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Pembaca Notifikasi Bank & Share Target',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          OrbitStatusBadge(
                            label: _bankAccessGranted ? 'Aktif' : 'Perlu Izin',
                            variant: _bankAccessGranted
                                ? OrbitBadgeVariant.income
                                : OrbitBadgeVariant.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hanya memproses paket bank/e-wallet terdaftar di bawah tanpa menyimpan teks mentah notifikasi dan tanpa logging.',
                        style: TextStyle(fontSize: 12, color: secondaryColor),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: OutlinedButton.icon(
                          key: const Key('settings_open_notif_listener_btn'),
                          onPressed: () async {
                            await AndroidAutoCaptureBridge.instance
                                .openNotificationAccessSettings();
                            await _loadState();
                          },
                          icon: const Icon(Icons.notifications_outlined, size: 18),
                          label: const Text(
                            'Buka Pengaturan Akses Notifikasi Android',
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Aktifkan Pembaca Notifikasi Bank',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _bankListenerEnabled,
                        onChanged: (v) async {
                          await AndroidAutoCaptureBridge.instance
                              .setListenerEnabledPref(v);
                          if (mounted) {
                            setState(() => _bankListenerEnabled = v);
                          }
                        },
                      ),
                      const Text(
                        'Whitelist Paket Bank & E-Wallet:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final app in BankNotificationParser.supportedApps)
                            FilterChip(
                              label: Text(
                                app.displayName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _bankWhitelist.contains(app.packageName),
                              onSelected: (selected) async {
                                final next = Set<String>.from(_bankWhitelist);
                                if (selected) {
                                  next.add(app.packageName);
                                } else {
                                  next.remove(app.packageName);
                                }
                                setState(() => _bankWhitelist = next);
                                await AndroidAutoCaptureBridge.instance
                                    .saveWhitelistedPackages(next);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('settings_bank_parser_test_field'),
                        controller: _parserTestController,
                        decoration: const InputDecoration(
                          labelText: 'Uji Parser Lokal Aman',
                          hintText:
                              'Contoh: BCA QRIS di Kopi Kenangan Rp 32.000 berhasil',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: OutlinedButton(
                          key: const Key('settings_bank_parser_test_btn'),
                          onPressed: _runLocalParserTest,
                          child: const Text('Uji Parser Lokal'),
                        ),
                      ),
                      if (_parserTestOutput != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _parserTestOutput!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Keamanan & Privasi Aplikasi (Wave 3)
                OrbitCard(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Keamanan & Privasi Aplikasi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: PrivacyModeController.instance.notifier,
                        builder: (context, hidden, _) => SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Mode Privasi (Sembunyikan Nominal)',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'Menyamarkan seluruh nominal Rupiah menjadi Rp ••••••.',
                            style: TextStyle(fontSize: 12, color: secondaryColor),
                          ),
                          value: hidden,
                          onChanged: (v) async {
                            await PrivacyModeController.instance.setEnabled(v);
                            await _loadState();
                          },
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            AppLockService.instance.isLockEnabledNotifier,
                        builder: (context, lockEnabled, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  height: AppTokens.minTouchTarget,
                                  child: FilledButton.icon(
                                    key: const Key('settings_setup_pin_btn'),
                                    onPressed: _showSetupPinDialog,
                                    icon: const Icon(Icons.lock_outline, size: 18),
                                    label: Text(
                                      lockEnabled
                                          ? 'Ubah PIN Aplikasi'
                                          : 'Aktifkan Kunci PIN',
                                    ),
                                  ),
                                ),
                                if (lockEnabled)
                                  SizedBox(
                                    height: AppTokens.minTouchTarget,
                                    child: OutlinedButton(
                                      key: const Key(
                                        'settings_disable_lock_btn',
                                      ),
                                      onPressed: () async {
                                        await AppLockService.instance
                                            .disableLock();
                                        if (mounted) {
                                          setState(() {
                                            _statusMessage =
                                                'Kunci aplikasi dinonaktifkan.';
                                          });
                                        }
                                      },
                                      child: const Text('Nonaktifkan Kunci'),
                                    ),
                                  ),
                              ],
                            ),
                            if (lockEnabled)
                              ValueListenableBuilder<bool>(
                                valueListenable: AppLockService
                                    .instance
                                    .isBiometricEnabledNotifier,
                                builder: (context, bioEnabled, _) =>
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Buka Kunci dengan Biometrik',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        _biometricAvailable
                                            ? 'Sidik jari / wajah tersedia di perangkat ini.'
                                            : 'Sensor biometrik belum tersedia; PIN tetap digunakan.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryColor,
                                        ),
                                      ),
                                      value: bioEnabled,
                                      onChanged: _biometricAvailable
                                          ? (v) => AppLockService.instance
                                                .setBiometricEnabled(v)
                                          : null,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Antrean Penjadwalan Aktif
                OrbitCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Antrean Pengingat Terjadwal (${_pending.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          TextButton(
                            onPressed: _rescheduleNow,
                            child: const Text('Jadwalkan Ulang'),
                          ),
                        ],
                      ),
                      if (_pending.isEmpty)
                        Text(
                          'Belum ada jadwal pengingat aktif di antrean Android.',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        )
                      else
                        for (final item in _pending.take(6)) ...[
                          const Divider(height: 12),
                          Text(
                            item.title ?? 'Pengingat Orbit',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.body != null)
                            Text(
                              item.body!,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryColor,
                              ),
                            ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Kolaborasi & Koneksi Kalender
                OrbitCard(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kolaborasi & Koneksi Kalender',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Anggota Workspace (${_members.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_members.isEmpty)
                        Text(
                          'Belum ada daftar anggota kolaborasi tersimpan lokal. Tarik data saat online untuk memuat anggota & undangan workspace.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedColor(context),
                          ),
                        )
                      else
                        for (final m in _members)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: AppColors.textSecondaryColor(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    m.displayName ?? m.email ?? m.userId,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                OrbitStatusBadge(
                                  label: m.role,
                                  variant: OrbitBadgeVariant.neutral,
                                ),
                              ],
                            ),
                          ),
                      if (_invites.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space2),
                        Text(
                          'Undangan Tertunda (${_invites.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final inv in _invites.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${inv['email'] ?? '-'} (${inv['role'] ?? 'editor'})',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMutedColor(context),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: AppTokens.space3),
                      Divider(color: AppColors.borderColor(context)),
                      const SizedBox(height: AppTokens.space2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Google Calendar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                          ),
                          OrbitStatusBadge(
                            label: _calendarConnections.any((c) => c.enabled)
                                ? 'Terhubung'
                                : 'Manual .ics',
                            variant: _calendarConnections.any((c) => c.enabled)
                                ? OrbitBadgeVariant.income
                                : OrbitBadgeVariant.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sinkronisasi OAuth Google Calendar dua arah dikonfigurasi via Orbit Web OAuth. Ekspor dan impor .ics tersedia langsung pada halaman Agenda.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Integrasi Otomatis R5: Pembaca notifikasi bank whitelist, Share Target Android, OCR struk lokal, dan Realtime workspace aktif.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Kesehatan Antrean Sync Outbox (Wave 4)
                OrbitCard(
                  padding: const EdgeInsets.all(AppTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Kesehatan Antrean Sinkronisasi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          OrbitStatusBadge(
                            label: (_outboxHealth?.hasIssues ?? false)
                                ? '${_outboxHealth!.failedCount} Gagal'
                                : ((_outboxHealth?.pendingCount ?? 0) > 0
                                    ? '${_outboxHealth!.pendingCount} Tertunda'
                                    : 'Sehat'),
                            variant: (_outboxHealth?.hasIssues ?? false)
                                ? OrbitBadgeVariant.expense
                                : ((_outboxHealth?.pendingCount ?? 0) > 0
                                    ? OrbitBadgeVariant.warning
                                    : OrbitBadgeVariant.income),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tertunda: ${_outboxHealth?.pendingCount ?? 0} | Gagal: ${_outboxHealth?.failedCount ?? 0} | Tersinkron: ${_outboxHealth?.syncedCount ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (_outboxHealth?.lastError != null &&
                          _outboxHealth!.failedCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Galat terakhir: ${_outboxHealth!.lastError}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.expenseColor(context),
                          ),
                        ),
                      ],
                      if ((_outboxHealth?.failedCount ?? 0) > 0) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: AppTokens.minTouchTarget,
                          child: OutlinedButton.icon(
                            key: const Key('settings_retry_failed_sync_btn'),
                            onPressed: () async {
                              final retried = await SyncService.instance
                                  .retryFailedOutboxOps();
                              await _loadState();
                              if (!mounted) return;
                              setState(() {
                                _statusMessage =
                                    '$retried antrean sync gagal diulang.';
                              });
                            },
                            icon: const Icon(Icons.replay_outlined, size: 18),
                            label: Text(
                              'Coba Ulang Sync Gagal (${_outboxHealth!.failedCount})',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),

                // Sinkronisasi & Keluar
                OutlinedButton.icon(
                  onPressed: () async {
                    await SyncService.instance.pullAllFromSupabase();
                    await _rescheduleNow();
                    await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Tarik Data Web & Perbarui Pengingat'),
                ),
                const SizedBox(height: AppTokens.space3),
                OutlinedButton.icon(
                  onPressed: () async {
                    await SyncService.instance.unsubscribeRealtime();
                    SyncService.instance.clearCachedWorkspace();
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {}
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.logout, color: AppColors.expenseColor(context)),
                  label: Text(
                    'Keluar dari Akun',
                    style: TextStyle(color: AppColors.expenseColor(context)),
                  ),
                ),
              ],
            ),
    );
  }
}
