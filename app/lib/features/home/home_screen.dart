import 'dart:async';
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/tasks/tasks_screen.dart';
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
  late int _currentIndex;
  String _agendaMode = 'jadwal'; // jadwal | tugas
  int _refreshCounter = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initSync();
  }

  void _initSync() {
    if (Supabase.instance.client.auth.currentUser != null) {
      SyncService.instance.pullAllFromSupabase().then((_) {
        if (mounted) _triggerRefresh();
      });
    }

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        SyncService.instance.pullAllFromSupabase().then((_) {
          if (mounted) _triggerRefresh();
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
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

  void _handleFabPressed() {
    // Di tab Uang langsung membuka form transaksi
    if (_currentIndex == 2) {
      TransactionFormSheet.show(context, onSaved: _triggerRefresh);
      return;
    }

    // Di tab Agenda langsung membuka sesuai mode aktif (Jadwal atau Tugas)
    if (_currentIndex == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _agendaMode == 'jadwal'
              ? const ScheduleScreen()
              : const TasksScreen(),
        ),
      );
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
                subtitle: const Text('Buat tugas dengan prioritas dan tenggat'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TasksScreen()),
                  );
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
        activeMode: _agendaMode,
        onModeChanged: (mode) => setState(() => _agendaMode = mode),
      ),
      TransactionsScreen(key: ValueKey('tx_$_refreshCounter')),
      const _LainnyaHubTab(),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
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
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: NavigationBar(
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
    );
  }
}

class _AgendaHubTab extends StatelessWidget {
  final String activeMode;
  final ValueChanged<String> onModeChanged;

  const _AgendaHubTab({
    required this.activeMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
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
          : const TasksScreen(embedded: true),
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
        title: 'Keamanan',
        subtitle: 'Autentikasi dua faktor (2FA) dan sesi perangkat aktif',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _SimpleDetailScreen(
                title: 'Keamanan',
                description:
                    'Pengaturan autentikasi dua faktor (TOTP 2FA), kunci biometrik, dan manajemen sesi aktif.',
              ),
            ),
          );
        },
      ),
      (
        icon: Icons.settings_outlined,
        title: 'Pengaturan',
        subtitle: 'Preferensi notifikasi, tampilan, dan akun',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _SimpleDetailScreen(
                title: 'Pengaturan',
                description:
                    'Atur pengingat pagi, preferensi tema terang/gelap, dan akun Orbit Anda.',
                showSignOut: true,
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lainnya',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
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
  final bool showSignOut;

  const _SimpleDetailScreen({
    required this.title,
    required this.description,
    this.showSignOut = false,
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
            if (showSignOut) ...[
              const SizedBox(height: AppTokens.space4),
              OutlinedButton.icon(
                onPressed: () async {
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
          ],
        ),
      ),
    );
  }
}
