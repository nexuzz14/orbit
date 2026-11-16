import 'dart:async';
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/android_auto_capture_bridge.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/notification_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/accounts/accounts_screen.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/planning/planning_screen.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/settings/notification_settings_screen.dart';
import 'package:orbit_app/features/tasks/orbit_task_detail_page.dart';
import 'package:orbit_app/features/tasks/tasks_screen.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_add_task_sheet.dart';
import 'package:orbit_app/features/today/today_screen.dart';
import 'package:orbit_app/features/transactions/transactions_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  String _agendaMode = 'jadwal'; // jadwal | tugas
  String? _selectedSavedViewId;
  String? _selectedProjectId;
  String? _selectedTaskViewMode;
  int _refreshCounter = 0;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<NotificationPayload>? _notifTapSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initNotifications();
    _initNativeBridges();
    _initSync();
  }

  void _initNativeBridges() {
    HomeWidgetBridge.registerQuickAddHandler((actionType) {
      if (mounted) _handleQuickAddAction(actionType);
    });
    AndroidAutoCaptureBridge.instance.attachListener(
      onDraftsImported: (_) async {
        await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
        if (mounted) _triggerRefresh();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AndroidAutoCaptureBridge.instance.pushConfigToNative();
      final imported = await AndroidAutoCaptureBridge.instance
          .syncPendingAutoCaptures(AppDatabase.shared);
      await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
      if (imported.draftsCreated > 0 && mounted) {
        _triggerRefresh();
      }
      final pendingQuickAdd =
          await HomeWidgetBridge.consumePendingQuickAddAction();
      if (pendingQuickAdd != null && mounted) {
        _handleQuickAddAction(pendingQuickAdd);
      }
    });
  }

  Future<void> _handleQuickAddAction(String actionType) async {
    if (!mounted) return;
    switch (actionType) {
      case 'transaction':
        await TransactionFormSheet.show(
          context,
          onSaved: () async {
            await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
            if (mounted) _triggerRefresh();
          },
        );
        break;
      case 'task':
        await showOrbitAddTaskSheet(context);
        await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
        if (mounted) _triggerRefresh();
        break;
      case 'receipt':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const InboxScreen(initialOpenReceiptScanner: true),
          ),
        );
        await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
        if (mounted) _triggerRefresh();
        break;
    }
  }

  void _initNotifications() {
    _notifTapSub = NotificationService.onNotificationTap.listen((payload) {
      if (mounted) _handleNotificationPayload(payload);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pendingPayload = NotificationService.consumePendingPayload();
      if (pendingPayload != null) {
        _handleNotificationPayload(pendingPayload);
      }
      await NotificationService.requestPermission();
      await NotificationSchedulerService.rescheduleAll(AppDatabase.shared);
    });
  }

  void _handleNotificationPayload(NotificationPayload payload) {
    if (!mounted) return;
    setState(() {
      _currentIndex = payload.targetTab.clamp(0, 3);
      if (payload.targetTab == 1 && payload.agendaMode != null) {
        _agendaMode = payload.agendaMode!;
      }
    });

    if (payload.targetTab == 2 &&
        (payload.uangSection == 'tagihan' ||
            payload.uangSection == 'anggaran')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlanningScreen(initialTab: payload.uangSection ?? 'tagihan'),
        ),
      );
    }
  }

  void _initSync() {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        SyncService.instance.subscribeRealtime(
          onSynced: () {
            if (mounted) _triggerRefresh();
          },
        );
        SyncService.instance.pullAllFromSupabase().then((_) async {
          await NotificationSchedulerService.rescheduleAll(AppDatabase.shared);
          await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
          if (mounted) _triggerRefresh();
        });
      }

      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          SyncService.instance.subscribeRealtime(
            onSynced: () {
              if (mounted) _triggerRefresh();
            },
          );
          SyncService.instance.pullAllFromSupabase().then((_) async {
            await NotificationSchedulerService.rescheduleAll(AppDatabase.shared);
            await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
            if (mounted) _triggerRefresh();
          });
        } else {
          SyncService.instance.unsubscribeRealtime();
          SyncService.instance.clearCachedWorkspace();
        }
      });
    } catch (_) {
      // Aman diabaikan saat widget test dijalankan tanpa inisialisasi Supabase.
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifTapSub?.cancel();
    SyncService.instance.unsubscribeRealtime();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  void _triggerRefresh() {
    setState(() {
      _refreshCounter++;
    });
  }

  void _openAddTaskSheetModal() {
    showOrbitAddTaskSheet(context).then((createdId) {
      if (createdId != null && mounted) {
        _triggerRefresh();
      }
    });
  }

  void _openCommandSearchModal() {
    showOrbitCommandSearch(
      context,
      onGoToToday: () {
        if (mounted) setState(() => _currentIndex = 0);
      },
      onCreateTask: _openAddTaskSheetModal,
      onCreateTransaction: () {
        TransactionFormSheet.show(context, onSaved: _triggerRefresh);
      },
      onSelectHit: (hit) {
        if (!mounted) return;
        if (hit.entityType == 'task') {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => OrbitTaskDetailPage(taskId: hit.entityId),
                ),
              )
              .then((_) {
            if (mounted) _triggerRefresh();
          });
        } else if (hit.entityType == 'project') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProjectsScreen(initialTab: 'kegiatan'),
            ),
          );
        } else if (hit.entityType == 'event') {
          setState(() {
            _currentIndex = 1;
            _agendaMode = 'jadwal';
          });
        } else if (hit.entityType == 'transaction') {
          setState(() => _currentIndex = 2);
        }
      },
    );
  }

  void _handleFabPressed() {
    // Di tab Uang langsung membuka form transaksi
    if (_currentIndex == 2) {
      TransactionFormSheet.show(context, onSaved: _triggerRefresh);
      return;
    }

    // Di tab Agenda: jika mode tugas langsung buka Add Task sheet v2
    if (_currentIndex == 1) {
      if (_agendaMode == 'tugas') {
        _openAddTaskSheetModal();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
        );
      }
      return;
    }

    // Di tab Hari Ini & Lainnya membuka bottom sheet pilihan Transaksi, Tugas, Jadwal
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tambah Cepat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTokens.space2),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Transaksi Baru'),
                subtitle: const Text('Catat pengeluaran, pemasukan, atau transfer'),
                onTap: () {
                  Navigator.pop(ctx);
                  TransactionFormSheet.show(context, onSaved: _triggerRefresh);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Tugas Baru'),
                subtitle: const Text('Buat tugas dengan template, pengulangan, dan tenggat'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddTaskSheetModal();
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Jadwal Baru'),
                subtitle: const Text('Tambahkan jadwal kuliah, rapat, atau kerja'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TodayScreen(key: ValueKey('today_$_refreshCounter')),
      _AgendaHubTab(
        key: ValueKey('agenda_${_refreshCounter}_$_selectedSavedViewId'),
        activeMode: _agendaMode,
        selectedSavedViewId: _selectedSavedViewId,
        selectedProjectId: _selectedProjectId,
        selectedTaskViewMode: _selectedTaskViewMode,
        onModeChanged: (mode) => setState(() => _agendaMode = mode),
      ),
      TransactionsScreen(key: ValueKey('tx_$_refreshCounter')),
      const _LainnyaHubTab(),
    ];

    return OrbitShellScope(
      openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      openCommandSearch: _openCommandSearchModal,
      openNewTask: _openAddTaskSheetModal,
      openNewTransaction: () =>
          TransactionFormSheet.show(context, onSaved: _triggerRefresh),
      openSavedView: (viewId, {viewMode}) {
        setState(() {
          _currentIndex = 1;
          _agendaMode = 'tugas';
          _selectedSavedViewId = viewId;
          _selectedTaskViewMode = viewMode;
        });
      },
      child: PopScope(
        canPop: _currentIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            _scaffoldKey.currentState?.closeDrawer();
            return;
          }
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          drawer: OrbitWorkspaceDrawer(
            onOpenCommandSearch: _openCommandSearchModal,
            onSelectSavedView: (view) {
              setState(() {
                _currentIndex = 1;
                _agendaMode = 'tugas';
                _selectedSavedViewId = view.id;
                _selectedProjectId = null;
                _selectedTaskViewMode = view.viewMode;
              });
            },
            onSelectProject: (project) {
              setState(() {
                _currentIndex = 1;
                _agendaMode = 'tugas';
                _selectedProjectId = project.id;
                _selectedSavedViewId = null;
              });
            },
            onOpenProjects: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ProjectsScreen(initialTab: 'kegiatan'),
                    ),
                  )
                  .then((_) {
                if (mounted) _triggerRefresh();
              });
            },
            onOpenInbox: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (_) => const InboxScreen()),
                  )
                  .then((_) {
                if (mounted) _triggerRefresh();
              });
            },
            onOpenAccounts: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (_) => const AccountsScreen()),
                  )
                  .then((_) {
                if (mounted) _triggerRefresh();
              });
            },
            onOpenPlanning: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (_) => const PlanningScreen()),
                  )
                  .then((_) {
                if (mounted) _triggerRefresh();
              });
            },
            onOpenNotificationSettings: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _handleFabPressed,
            tooltip: 'Tambah Transaksi, Tugas, atau Jadwal',
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.borderColor(context),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBar(
              height: 68,
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) {
                setState(() => _currentIndex = idx);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: 'Hari Ini',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note),
                  label: 'Agenda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Uang',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Lainnya',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaHubTab extends StatelessWidget {
  final String activeMode;
  final String? selectedSavedViewId;
  final String? selectedProjectId;
  final String? selectedTaskViewMode;
  final ValueChanged<String> onModeChanged;

  const _AgendaHubTab({
    super.key,
    required this.activeMode,
    this.selectedSavedViewId,
    this.selectedProjectId,
    this.selectedTaskViewMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: OrbitShellScope.maybeOf(context) != null
            ? const OrbitShellMenuButton()
            : null,
        title: const Text(
          'Agenda',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (OrbitShellScope.maybeOf(context) != null)
            const OrbitShellSearchButton(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space4,
              0,
              AppTokens.space4,
              AppTokens.space3,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'jadwal', label: Text('Jadwal')),
                  ButtonSegment(value: 'tugas', label: Text('Tugas')),
                ],
                selected: {activeMode},
                onSelectionChanged: (s) => onModeChanged(s.first),
              ),
            ),
          ),
        ),
      ),
      body: activeMode == 'jadwal'
          ? const ScheduleScreen(embedded: true)
          : TasksScreen(
              embedded: true,
              initialSavedViewId: selectedSavedViewId,
              initialProjectId: selectedProjectId,
              initialViewMode: selectedTaskViewMode,
            ),
    );
  }
}

class _LainnyaHubTab extends StatelessWidget {
  const _LainnyaHubTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: Icons.work_outline,
        title: 'Kegiatan',
        subtitle: 'Proyek freelance, magang, dan mata kuliah',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProjectsScreen(initialTab: 'kegiatan'),
            ),
          );
        },
      ),
      (
        icon: Icons.request_quote_outlined,
        title: 'Piutang',
        subtitle: 'Tagihan termin proyek dan komitmen klien',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProjectsScreen(initialTab: 'piutang'),
            ),
          );
        },
      ),
      (
        icon: Icons.category_outlined,
        title: 'Kategori dan Aturan',
        subtitle: 'Kategori pemasukan/pengeluaran dan klasifikasi otomatis',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _SimpleDetailScreen(
                title: 'Kategori dan Aturan',
                description:
                    'Kelola kategori pemasukan/pengeluaran serta aturan pencocokan merchant otomatis.',
              ),
            ),
          );
        },
      ),
      (
        icon: Icons.sync_outlined,
        title: 'Sumber Otomatis',
        subtitle: 'Integrasi notifikasi dan penerusan email transaksi',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InboxScreen()),
          );
        },
      ),
      (
        icon: Icons.shield_outlined,
        title: 'Keamanan & Privasi',
        subtitle: 'PIN SHA-256, kunci biometrik, Mode Privasi, & pembaca notifikasi bank',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.group_outlined,
        title: 'Kolaborasi & Kalender',
        subtitle: 'Anggota workspace, status Google Calendar, & pengaturan sinkronisasi',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.settings_outlined,
        title: 'Pengaturan',
        subtitle: 'Preferensi notifikasi, pengingat WIB, tampilan, dan akun',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: OrbitShellScope.maybeOf(context) != null
            ? const OrbitShellMenuButton()
            : null,
        title: const Text(
          'Lainnya',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (OrbitShellScope.maybeOf(context) != null)
            const OrbitShellSearchButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space4,
          AppTokens.space3,
          AppTokens.space4,
          96,
        ),
        children: [
          OrbitCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(items[i].icon),
                    title: Text(
                      items[i].title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      items[i].subtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: items[i].onTap,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleDetailScreen extends StatelessWidget {
  final String title;
  final String description;

  const _SimpleDetailScreen({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrbitCard(
              child: Text(
                description,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
