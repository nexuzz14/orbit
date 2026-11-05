import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class ProjectsScreen extends StatefulWidget {
  final String initialTab; // 'kegiatan' | 'piutang'
  final bool forceLoading;
  final String? forceError;

  const ProjectsScreen({
    super.key,
    this.initialTab = 'kegiatan',
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  AppDatabase get _db => AppDatabase.shared;
  final _uuid = const Uuid();

  late String _activeTab;
  bool _loading = true;
  String? _errorMessage;

  List<LocalProject> _projects = [];
  List<LocalProjectPayment> _payments = [];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadProjects();
      SyncService.instance.pullAllFromSupabase().then((_) {
        if (mounted) _loadProjects();
      });
    }
  }

  Future<void> _loadProjects({bool pull = false}) async {
    if (widget.forceLoading) return;
    setState(() {
      _loading = true;
      _errorMessage = widget.forceError;
    });

    if (widget.forceError != null) {
      setState(() => _loading = false);
      return;
    }

    if (pull) {
      await SyncService.instance.pullAllFromSupabase();
    }

    try {
      final projects = await _db.select(_db.localProjects).get();
      final payments = await _db.select(_db.localProjectPayments).get();

      if (mounted) {
        setState(() {
          _projects = projects.where((p) => p.deletedAt == null).toList();
          _payments = payments.where((p) => p.deletedAt == null).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat kegiatan & piutang: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddProjectSheet() {
    final nameCtrl = TextEditingController();
    String selectedKind = 'freelance';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: AppTokens.space4,
            right: AppTokens.space4,
            top: AppTokens.space4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tambah Kegiatan Baru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Kegiatan / Proyek / Mata Kuliah',
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              Wrap(
                spacing: AppTokens.space2,
                runSpacing: AppTokens.space2,
                children: [
                  for (final k in const [
                    'intern',
                    'freelance',
                    'kuliah',
                    'pribadi',
                  ])
                    ChoiceChip(
                      label: Text(AppColors.getKindLabel(k)),
                      selected: selectedKind == k,
                      onSelected: (_) =>
                          setModalState(() => selectedKind = k),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
              SizedBox(
                height: AppTokens.minTouchTarget,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final wsId =
                        await SyncService.instance.getWorkspaceId() ??
                            'ws-local';
                    final projId = _uuid.v4();
                    final name = nameCtrl.text.trim();

                    await _db.into(_db.localProjects).insert(
                          LocalProjectsCompanion.insert(
                            id: projId,
                            workspaceId: wsId,
                            kind: selectedKind,
                            name: name,
                            color: const Value('#0284C7'),
                          ),
                        );

                    SyncService.instance.pushRecord(
                      tableName: 'projects',
                      recordId: projId,
                      action: 'insert',
                      payload: {
                        'id': projId,
                        'workspace_id': wsId,
                        'kind': selectedKind,
                        'name': name,
                        'color': '#0284C7',
                        'status': 'berjalan',
                      },
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadProjects();
                  },
                  child: const Text('Simpan Kegiatan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    double totalUnpaid = 0;
    for (final pay in _payments) {
      if (pay.status != 'paid' && pay.status != 'lunas') {
        totalUnpaid += (pay.amount - pay.paidAmount);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kegiatan & Piutang',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showAddProjectSheet,
            tooltip: 'Tambah Kegiatan',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadProjects(pull: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space3,
            AppTokens.space4,
            96,
          ),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'kegiatan', label: Text('Kegiatan')),
                ButtonSegment(value: 'piutang', label: Text('Piutang')),
              ],
              selected: {_activeTab},
              onSelectionChanged: (s) =>
                  setState(() => _activeTab = s.first),
            ),
            const SizedBox(height: AppTokens.space4),

            if (_errorMessage != null) ...[
              OrbitErrorState(
                message: _errorMessage!,
                onRetry: _loadProjects,
              ),
              const SizedBox(height: AppTokens.space4),
            ],

            if (_loading) ...[
              const OrbitSkeleton(height: 84),
              const SizedBox(height: AppTokens.space3),
              const OrbitSkeleton(height: 84),
            ] else if (_activeTab == 'piutang') ...[
              OrbitCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Piutang Belum Lunas',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRupiah(totalUnpaid),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningColor(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const OrbitStatusBadge(
                      label: 'Piutang Aktif',
                      variant: OrbitBadgeVariant.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              if (_payments.isEmpty)
                OrbitEmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'Belum ada piutang tercatat',
                  description:
                      'Tambahkan termin pembayaran pada proyek freelance atau magang Anda.',
                  actionLabel: 'Tambah Kegiatan',
                  onAction: _showAddProjectSheet,
                )
              else
                for (final pay in _payments) ...[
                  OrbitCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pay.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              OrbitStatusBadge(
                                label: (pay.status == 'paid' ||
                                        pay.status == 'lunas')
                                    ? 'Lunas'
                                    : 'Menunggu Pembayaran',
                                variant: (pay.status == 'paid' ||
                                        pay.status == 'lunas')
                                    ? OrbitBadgeVariant.income
                                    : OrbitBadgeVariant.warning,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatRupiah(pay.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                ],
            ] else if (_projects.isEmpty) ...[
              OrbitEmptyState(
                icon: Icons.work_outline,
                title: 'Belum ada kegiatan aktif',
                description:
                    'Kelompokkan jadwal, tugas, dan transaksi ke dalam kegiatan magang, freelance, kuliah, atau pribadi.',
                actionLabel: 'Tambah Kegiatan',
                onAction: _showAddProjectSheet,
              ),
            ] else ...[
              for (final p in _projects) ...[
                OrbitCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTokens.space2),
                            OrbitKindBadge(kind: p.kind),
                          ],
                        ),
                      ),
                      const OrbitStatusBadge(
                        label: 'Aktif',
                        variant: OrbitBadgeVariant.neutral,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
