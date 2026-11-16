import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';

/// Konteks navigasi Orbit Shell agar tab di dalam HomeScreen dapat
/// membuka Workspace Drawer, Command Search, atau berpindah tab/view.
class OrbitShellScope extends InheritedWidget {
  final VoidCallback openDrawer;
  final VoidCallback openCommandSearch;
  final VoidCallback? openNewTask;
  final VoidCallback? openNewTransaction;
  final void Function(String savedViewId, {String? viewMode})?
      openSavedView;

  const OrbitShellScope({
    super.key,
    required this.openDrawer,
    required this.openCommandSearch,
    this.openNewTask,
    this.openNewTransaction,
    this.openSavedView,
    required super.child,
  });

  static OrbitShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OrbitShellScope>();
  }

  @override
  bool updateShouldNotify(covariant OrbitShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer ||
        openCommandSearch != oldWidget.openCommandSearch ||
        openNewTask != oldWidget.openNewTask ||
        openNewTransaction != oldWidget.openNewTransaction ||
        openSavedView != oldWidget.openSavedView;
  }
}

/// Tombol menu kiri & tombol cari global untuk AppBar pada layar utama.
class OrbitShellMenuButton extends StatelessWidget {
  const OrbitShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = OrbitShellScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Menu Workspace',
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(
        Icons.menu_rounded,
        size: 22,
        color: AppColors.textPrimaryColor(context),
      ),
      onPressed: scope.openDrawer,
    );
  }
}

/// Tombol Cari Global (>= 44x44px) yang membuka OrbitCommandSearch.
class OrbitShellSearchButton extends StatelessWidget {
  const OrbitShellSearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = OrbitShellScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Cari Global',
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(
        Icons.search_rounded,
        size: 22,
        color: AppColors.textPrimaryColor(context),
      ),
      onPressed: scope.openCommandSearch,
    );
  }
}

/// Badge status sinkronisasi ringkas untuk header Workspace Drawer.
class OrbitSyncStatusBadge extends StatelessWidget {
  const OrbitSyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: sync.isSyncingNotifier,
      builder: (context, syncing, _) {
        return StreamBuilder<int>(
          stream: sync.watchPendingOutboxCount(),
          initialData: 0,
          builder: (context, outboxSnap) {
            final pending = outboxSnap.data ?? 0;
            return ValueListenableBuilder<DateTime?>(
              valueListenable: sync.lastSyncedAtNotifier,
              builder: (context, lastSync, _) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final Color fg;
                final Color bg;
                final Color border;
                final IconData icon;
                final String label;

                if (syncing) {
                  fg = AppColors.accentColor(context);
                  bg = fg.withValues(alpha: 0.12);
                  border = AppColors.borderColor(context);
                  icon = Icons.sync_rounded;
                  label = 'Menyinkronkan...';
                } else if (pending > 0) {
                  fg = AppColors.warningColor(context);
                  bg = isDark
                      ? AppColors.warningSubtleDark
                      : AppColors.warningSubtleLight;
                  border = AppColors.borderColor(context);
                  icon = Icons.cloud_upload_outlined;
                  label = '$pending antrean';
                } else if (lastSync != null) {
                  fg = AppColors.incomeColor(context);
                  bg = isDark
                      ? AppColors.incomeSubtleDark
                      : AppColors.incomeSubtleLight;
                  border = AppColors.borderColor(context);
                  icon = Icons.cloud_done_outlined;
                  label = 'Tersinkron ${DateFormat('HH:mm').format(lastSync)}';
                } else {
                  fg = AppColors.textSecondaryColor(context);
                  bg = AppColors.subtleColor(context);
                  border = AppColors.borderColor(context);
                  icon = Icons.cloud_queue_outlined;
                  label = 'Mode Offline-First';
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: fg),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Drawer navigasi workspace ala Notion:
/// Saved Views, Proyek Aktif (maks 5), status sinkronisasi, dan pintasan keuangan.
class OrbitWorkspaceDrawer extends StatefulWidget {
  final void Function(LocalSavedView view) onSelectSavedView;
  final VoidCallback onOpenProjects;
  final void Function(LocalProject project)? onSelectProject;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenPlanning;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback? onOpenCommandSearch;

  const OrbitWorkspaceDrawer({
    super.key,
    required this.onSelectSavedView,
    required this.onOpenProjects,
    this.onSelectProject,
    required this.onOpenInbox,
    required this.onOpenAccounts,
    required this.onOpenPlanning,
    required this.onOpenNotificationSettings,
    this.onOpenCommandSearch,
  });

  @override
  State<OrbitWorkspaceDrawer> createState() => _OrbitWorkspaceDrawerState();
}

class _OrbitWorkspaceDrawerState extends State<OrbitWorkspaceDrawer> {
  late Future<String> _workspaceNameFuture;

  @override
  void initState() {
    super.initState();
    _workspaceNameFuture = SyncService.instance.getWorkspaceName();
  }

  Future<void> _manualSync() async {
    await SyncService.instance.pullAllFromSupabase();
    if (mounted) {
      setState(() {
        _workspaceNameFuture = SyncService.instance.getWorkspaceName();
      });
    }
  }

  String _viewModeLabel(String mode) {
    switch (mode) {
      case 'board':
        return 'Papan';
      case 'timeline':
        return 'Proyek';
      case 'calendar':
        return 'Kalender';
      default:
        return 'Daftar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.shared;
    final sidebarBg = AppColors.sidebarColor(context);
    final borderCol = AppColors.borderColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);

    return Drawer(
      backgroundColor: sidebarBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: borderCol, width: 1),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Header Workspace + Sinkronisasi
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.accentColor(context)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderCol),
                        ),
                        child: Icon(
                          Icons.hub_outlined,
                          size: 16,
                          color: AppColors.accentColor(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FutureBuilder<String>(
                          future: _workspaceNameFuture,
                          initialData: 'Orbit Workspace',
                          builder: (context, snap) => Text(
                            snap.data ?? 'Orbit Workspace',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sinkronisasi manual',
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: textSecondary,
                        ),
                        onPressed: _manualSync,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const OrbitSyncStatusBadge(),
                  if (widget.onOpenCommandSearch != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onOpenCommandSearch!();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                size: 17, color: textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cari tugas, proyek, acara...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: borderCol),

            // Bagian Saved Views
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'TAMPILAN TERSIMPAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AppColors.textMutedColor(context),
                ),
              ),
            ),
            StreamBuilder<List<LocalSavedView>>(
              stream: (db.select(db.localSavedViews)
                    ..where((v) => v.deletedAt.isNull())
                    ..orderBy([
                      (v) => OrderingTerm.desc(v.isPinned),
                      (v) => OrderingTerm.asc(v.sortOrder),
                      (v) => OrderingTerm.desc(v.createdAt),
                    ]))
                  .watch(),
              builder: (context, snap) {
                final views = snap.data ?? const [];
                if (views.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(
                      'Belum ada tampilan tersimpan. Buat di tab Tugas.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  );
                }
                return Column(
                  children: views.map((v) {
                    return _DrawerNavRow(
                      icon: v.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.filter_list_rounded,
                      label: v.name,
                      trailingText: _viewModeLabel(v.viewMode),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelectSavedView(v);
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: borderCol),

            // Bagian Proyek Aktif (maks 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PROYEK AKTIF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Lihat semua proyek',
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onOpenProjects();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: AppTokens.minTouchTarget,
                          minHeight: AppTokens.minTouchTarget,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Semua',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accentColor(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<List<LocalProject>>(
              stream: (db.select(db.localProjects)
                    ..where((p) =>
                        p.deletedAt.isNull() &
                        (p.status.equals('berjalan') |
                            p.status.equals('active')))
                    ..orderBy([
                      (p) => OrderingTerm.asc(p.deadline),
                      (p) => OrderingTerm.asc(p.name),
                    ])
                    ..limit(5))
                  .watch(),
              builder: (context, snap) {
                final projects = snap.data ?? const [];
                if (projects.isEmpty) {
                  return _DrawerNavRow(
                    icon: Icons.folder_open_outlined,
                    label: 'Kelola Proyek & Kegiatan',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenProjects();
                    },
                  );
                }
                return Column(
                  children: projects.map((p) {
                    return _DrawerNavRow(
                      icon: Icons.folder_outlined,
                      iconColor: AppColors.getKindColor(
                        p.kind,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      label: p.name,
                      trailingText:
                          AppColors.getKindLabel(p.kind),
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.onSelectProject != null) {
                          widget.onSelectProject!(p);
                        } else {
                          widget.onOpenProjects();
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: borderCol),

            // Bagian Keuangan & Pengelolaan
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'KEUANGAN & PENGELOLAAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AppColors.textMutedColor(context),
                ),
              ),
            ),
            _DrawerNavRow(
              icon: Icons.inbox_outlined,
              label: 'Kotak Masuk Transaksi',
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenInbox();
              },
            ),
            _DrawerNavRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Dompet & Akun',
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenAccounts();
              },
            ),
            _DrawerNavRow(
              icon: Icons.pie_chart_outline_rounded,
              label: 'Anggaran, Tagihan & Target',
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenPlanning();
              },
            ),
            _DrawerNavRow(
              icon: Icons.notifications_none_rounded,
              label: 'Pengaturan Pengingat',
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenNotificationSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? trailingText;
  final VoidCallback onTap;

  const _DrawerNavRow({
    required this.icon,
    this.iconColor,
    required this.label,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryColor(context);
    final textMuted = AppColors.textMutedColor(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.textSecondaryColor(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ),
              if (trailingText != null && trailingText!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  trailingText!,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
