import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class ScheduleScreen extends StatefulWidget {
  final bool embedded;
  final bool forceLoading;
  final String? forceError;

  const ScheduleScreen({
    super.key,
    this.embedded = false,
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  AppDatabase get _db => AppDatabase.shared;
  final _uuid = const Uuid();

  bool _loading = true;
  String? _errorMessage;
  String _selectedKind = 'all'; // all | intern | freelance | kuliah | pribadi
  String _viewMode = 'hari'; // hari | minggu

  List<LocalEvent> _events = [];

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadEvents();
      SyncService.instance.pullAllFromSupabase().then((_) {
        if (mounted) _loadEvents();
      });
    }
  }

  Future<void> _loadEvents({bool pull = false}) async {
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
      final events = await (_db.select(_db.localEvents)
            ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]))
          .get();

      if (mounted) {
        setState(() {
          _events = events.where((e) => e.deletedAt == null).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat jadwal: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Set<String> _computeConflictingIds(List<LocalEvent> items) {
    final conflicts = <String>{};
    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];
        if (a.startsAt.isBefore(b.endsAt) && b.startsAt.isBefore(a.endsAt)) {
          conflicts.add(a.id);
          conflicts.add(b.id);
        }
      }
    }
    return conflicts;
  }

  Future<void> _deleteEvent(String id) async {
    await (_db.update(_db.localEvents)..where((e) => e.id.equals(id)))
        .write(LocalEventsCompanion(deletedAt: Value(DateTime.now())));
    await _loadEvents();
  }

  void _showAddEventSheet() {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedKind = 'kuliah';
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 30);

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
                    'Tambah Jadwal Baru',
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
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Kegiatan / Kelas / Rapat',
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi / Tautan Rapat (Opsional)',
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
              const SizedBox(height: AppTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setModalState(() => startTime = picked);
                        }
                      },
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('Mulai: ${startTime.format(ctx)}'),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setModalState(() => endTime = picked);
                        }
                      },
                      icon: const Icon(Icons.access_time_filled, size: 16),
                      label: Text('Selesai: ${endTime.format(ctx)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
              SizedBox(
                height: AppTokens.minTouchTarget,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final now = DateTime.now();
                    final startsAt = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      startTime.hour,
                      startTime.minute,
                    );
                    var endsAt = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      endTime.hour,
                      endTime.minute,
                    );
                    if (!endsAt.isAfter(startsAt)) {
                      endsAt = startsAt.add(const Duration(hours: 1));
                    }
                    final wsId =
                        await SyncService.instance.getWorkspaceId() ??
                            'ws-local';
                    final eventId = _uuid.v4();
                    final title = titleCtrl.text.trim();
                    final loc = locationCtrl.text.trim().isEmpty
                        ? null
                        : locationCtrl.text.trim();

                    await _db.into(_db.localEvents).insert(
                          LocalEventsCompanion.insert(
                            id: eventId,
                            workspaceId: wsId,
                            kind: selectedKind,
                            title: title,
                            location: Value(loc),
                            startsAt: startsAt,
                            endsAt: endsAt,
                          ),
                        );

                    SyncService.instance.pushRecord(
                      tableName: 'events',
                      recordId: eventId,
                      action: 'insert',
                      payload: {
                        'id': eventId,
                        'workspace_id': wsId,
                        'kind': selectedKind,
                        'title': title,
                        'location': loc,
                        'starts_at': startsAt.toIso8601String(),
                        'ends_at': endsAt.toIso8601String(),
                        'all_day': false,
                        'timezone': 'Asia/Jakarta',
                      },
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadEvents();
                  },
                  child: const Text('Simpan Jadwal'),
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

    final filtered = _events.where((e) {
      if (_selectedKind == 'all') return true;
      return e.kind == _selectedKind;
    }).toList();

    final conflicts = _computeConflictingIds(filtered);

    final content = RefreshIndicator(
      onRefresh: () => _loadEvents(pull: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space4,
          AppTokens.space3,
          AppTokens.space4,
          96,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'hari', label: Text('Hari')),
                    ButtonSegment(value: 'minggu', label: Text('Minggu')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) =>
                      setState(() => _viewMode = s.first),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              IconButton(
                onPressed: _showAddEventSheet,
                tooltip: 'Tambah Jadwal',
                constraints: const BoxConstraints(
                  minWidth: AppTokens.minTouchTarget,
                  minHeight: AppTokens.minTouchTarget,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'Semua'),
                  ('intern', 'Intern'),
                  ('freelance', 'Freelance'),
                  ('kuliah', 'Kuliah'),
                  ('pribadi', 'Pribadi'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: AppTokens.space2),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _selectedKind == entry.$1,
                      onSelected: (_) =>
                          setState(() => _selectedKind = entry.$1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),

          if (conflicts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppTokens.space3),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.warningSubtleDark
                    : AppColors.warningSubtleLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                  color: AppColors.warningColor(context).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warningColor(context),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Expanded(
                    child: Text(
                      'Terdapat ${conflicts.length} jadwal yang saling berbenturan waktu.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space3),
          ],

          if (_errorMessage != null) ...[
            OrbitErrorState(
              message: _errorMessage!,
              onRetry: _loadEvents,
            ),
            const SizedBox(height: AppTokens.space4),
          ],

          if (_loading) ...[
            const OrbitSkeleton(height: 84),
            const SizedBox(height: AppTokens.space3),
            const OrbitSkeleton(height: 84),
            const SizedBox(height: AppTokens.space3),
            const OrbitSkeleton(height: 84),
          ] else if (filtered.isEmpty) ...[
            OrbitEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Tidak ada jadwal pada tampilan ini',
              description:
                  'Tambahkan jadwal kuliah, magang, atau rapat agar lini masa harian terpantau jelas.',
              actionLabel: 'Tambah Jadwal',
              onAction: _showAddEventSheet,
            ),
          ] else ...[
            for (final ev in filtered) ...[
              _buildEventCard(
                context,
                ev,
                conflicts.contains(ev.id),
                secondaryColor,
              ),
              const SizedBox(height: AppTokens.space3),
            ],
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jadwal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showAddEventSheet,
            tooltip: 'Tambah Jadwal',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    LocalEvent ev,
    bool hasConflict,
    Color secondaryColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kindColor = AppColors.getKindColor(ev.kind, isDark: isDark);
    final startStr =
        '${ev.startsAt.hour.toString().padLeft(2, '0')}:${ev.startsAt.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${ev.endsAt.hour.toString().padLeft(2, '0')}:${ev.endsAt.minute.toString().padLeft(2, '0')}';

    return OrbitCard(
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: kindColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startStr - $endStr',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateIndoShort(ev.startsAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ev.location != null && ev.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ev.location!,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ],
                const SizedBox(height: AppTokens.space2),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  children: [
                    OrbitKindBadge(kind: ev.kind),
                    if (hasConflict)
                      const OrbitStatusBadge(
                        label: 'Bentrok Waktu',
                        variant: OrbitBadgeVariant.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteEvent(ev.id),
            tooltip: 'Hapus Jadwal',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
