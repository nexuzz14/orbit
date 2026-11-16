import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_revision_dialog.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_time_tracker_block.dart';

/// Halaman detail tugas bergaya Notion/Jira dengan properti inline,
/// blok catatan, checklist, subtugas bersarang, tautan entitas, lampiran,
/// komentar, dan linimasa riwayat status.
class OrbitTaskDetailPage extends StatefulWidget {
  final String taskId;

  const OrbitTaskDetailPage({super.key, required this.taskId});

  @override
  State<OrbitTaskDetailPage> createState() => _OrbitTaskDetailPageState();
}

class _OrbitTaskDetailPageState extends State<OrbitTaskDetailPage> {
  final _db = AppDatabase.shared;
  final _descCtrl = TextEditingController();
  final _checklistCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool _loading = true;
  bool _descDirty = false;
  LocalTask? _task;
  LocalTask? _parentTask;
  LocalProject? _project;
  List<LocalProject> _allProjects = const [];
  List<LocalWorkspaceMember> _members = const [];
  List<LocalTaskChecklistItem> _checklists = const [];
  List<LocalTask> _subtasks = const [];
  List<LocalComment> _comments = const [];
  List<LocalAttachment> _attachments = const [];
  List<LocalTaskStatusHistory> _histories = const [];
  List<_ResolvedEntityLink> _links = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _checklistCtrl.dispose();
    _subtaskCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final task = await (_db.select(_db.localTasks)
          ..where((t) => t.id.equals(widget.taskId)))
        .getSingleOrNull();

    if (task == null) {
      if (mounted) {
        setState(() {
          _task = null;
          _loading = false;
        });
      }
      return;
    }

    LocalTask? parent;
    if (task.parentTaskId != null && task.parentTaskId!.isNotEmpty) {
      parent = await (_db.select(_db.localTasks)
            ..where((t) => t.id.equals(task.parentTaskId!)))
          .getSingleOrNull();
    }

    final projects = await (_db.select(_db.localProjects)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();

    LocalProject? currentProject;
    if (task.projectId != null) {
      for (final p in projects) {
        if (p.id == task.projectId) {
          currentProject = p;
          break;
        }
      }
    }

    final checklists = await (_db.select(_db.localTaskChecklistItems)
          ..where((c) => c.taskId.equals(widget.taskId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();

    final subtasks = await (_db.select(_db.localTasks)
          ..where((s) =>
              s.parentTaskId.equals(widget.taskId) & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();

    final comments = await (_db.select(_db.localComments)
          ..where((c) =>
              c.entityType.equals('task') &
              c.entityId.equals(widget.taskId) &
              c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();

    final attachments = await (_db.select(_db.localAttachments)
          ..where((a) =>
              a.ownerTable.equals('tasks') &
              a.ownerId.equals(widget.taskId) &
              a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .get();

    final histories = await (_db.select(_db.localTaskStatusHistories)
          ..where((h) => h.taskId.equals(widget.taskId))
          ..orderBy([(h) => OrderingTerm.desc(h.createdAt)]))
        .get();

    final rawLinks = await (_db.select(_db.localEntityLinks)
          ..where((l) =>
              (l.sourceType.equals('task') & l.sourceId.equals(widget.taskId)) |
              (l.targetType.equals('task') & l.targetId.equals(widget.taskId))))
        .get();
    final resolvedLinks = await _resolveEntityLinks(rawLinks);
    final members = await (_db.select(_db.localWorkspaceMembers)
          ..where((m) => m.workspaceId.equals(task.workspaceId)))
        .get();

    final initialDesc = _extractDescriptionText(task);
    if (!_descDirty) {
      _descCtrl.text = initialDesc;
    }

    if (mounted) {
      setState(() {
        _task = task;
        _parentTask = parent;
        _project = currentProject;
        _allProjects = projects;
        _members = members;
        _checklists = checklists;
        _subtasks = subtasks;
        _comments = comments;
        _attachments = attachments;
        _histories = histories;
        _links = resolvedLinks;
        _loading = false;
      });
    }
  }

  String _extractDescriptionText(LocalTask task) {
    if (task.description != null && task.description!.trim().isNotEmpty) {
      return task.description!;
    }
    if (task.descriptionBlocksJson != null &&
        task.descriptionBlocksJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(task.descriptionBlocksJson!);
        if (decoded is List) {
          final lines = decoded
              .whereType<Map>()
              .map((b) => b['text']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          if (lines.isNotEmpty) return lines.join('\n');
        }
      } catch (_) {}
    }
    return '';
  }

  Future<List<_ResolvedEntityLink>> _resolveEntityLinks(
    List<LocalEntityLink> raw,
  ) async {
    final result = <_ResolvedEntityLink>[];
    for (final link in raw) {
      final isOutgoing =
          link.sourceType == 'task' && link.sourceId == widget.taskId;
      final peerType = isOutgoing ? link.targetType : link.sourceType;
      final peerId = isOutgoing ? link.targetId : link.sourceId;
      final peerTitle = await _lookupEntityTitle(peerType, peerId);
      result.add(_ResolvedEntityLink(
        link: link,
        peerType: peerType,
        peerId: peerId,
        peerTitle: peerTitle,
      ));
    }
    return result;
  }

  Future<String> _lookupEntityTitle(String type, String id) async {
    switch (type) {
      case 'task':
        final t = await (_db.select(_db.localTasks)
              ..where((x) => x.id.equals(id)))
            .getSingleOrNull();
        return t?.title ?? 'Tugas ($id)';
      case 'project':
        final p = await (_db.select(_db.localProjects)
              ..where((x) => x.id.equals(id)))
            .getSingleOrNull();
        return p?.name ?? 'Proyek ($id)';
      case 'event':
        final e = await (_db.select(_db.localEvents)
              ..where((x) => x.id.equals(id)))
            .getSingleOrNull();
        return e?.title ?? 'Acara ($id)';
      case 'transaction':
        final tr = await (_db.select(_db.localTransactions)
              ..where((x) => x.id.equals(id)))
            .getSingleOrNull();
        return tr?.merchant ?? tr?.note ?? 'Transaksi';
      default:
        return '$type ($id)';
    }
  }

  Future<void> _saveDescription() async {
    final task = _task;
    if (task == null) return;
    final text = _descCtrl.text.trim();
    final blocks = text.isEmpty
        ? <Map<String, dynamic>>[]
        : text
            .split('\n')
            .map((line) => {'type': 'paragraph', 'text': line})
            .toList();

    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(
        description: Value(text.isEmpty ? null : text),
        descriptionBlocksJson: Value(jsonEncode(blocks)),
      ),
      remotePayload: {
        'description': text.isEmpty ? null : text,
        'description_blocks': blocks,
      },
    );
    _descDirty = false;
    await _loadData();
  }

  Future<void> _editTitle() async {
    final task = _task;
    if (task == null) return;
    final ctrl = TextEditingController(text: task.title);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Judul Tugas'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Judul tugas'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (updated == null || updated == task.title) return;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(title: Value(updated)),
      remotePayload: {'title': updated},
    );
    await _loadData();
  }

  Future<void> _pickKind() async {
    final task = _task;
    if (task == null) return;
    const kinds = ['pribadi', 'kuliah', 'intern', 'freelance'];
    final chosen = await _showSimpleChoiceSheet(
      title: 'Pilih Konteks',
      options: kinds.map((k) => MapEntry(k, AppColors.getKindLabel(k))).toList(),
      selectedKey: task.kind,
    );
    if (chosen == null) return;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(kind: Value(chosen)),
      remotePayload: {'kind': chosen},
    );
    await _loadData();
  }

  Future<void> _pickPriority() async {
    final task = _task;
    if (task == null) return;
    final chosen = await _showSimpleChoiceSheet(
      title: 'Pilih Prioritas',
      options: const [
        MapEntry('tinggi', 'Tinggi'),
        MapEntry('sedang', 'Sedang'),
        MapEntry('rendah', 'Rendah'),
      ],
      selectedKey: task.priority,
    );
    if (chosen == null) return;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(priority: Value(chosen)),
      remotePayload: {'priority': chosen},
    );
    await _loadData();
  }

  Future<void> _pickProject() async {
    final task = _task;
    if (task == null) return;
    final options = <MapEntry<String, String>>[
      const MapEntry('__none__', 'Tanpa Proyek'),
      ..._allProjects.map((p) => MapEntry(p.id, p.name)),
    ];
    final chosen = await _showSimpleChoiceSheet(
      title: 'Pilih Proyek',
      options: options,
      selectedKey: task.projectId ?? '__none__',
    );
    if (chosen == null) return;
    final nextId = chosen == '__none__' ? null : chosen;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(projectId: Value(nextId)),
      remotePayload: {'project_id': nextId},
    );
    await _loadData();
  }

  Future<void> _pickDueDate() async {
    final task = _task;
    if (task == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Pilih Tanggal & Jam'),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              if (task.dueAt != null)
                ListTile(
                  leading: Icon(Icons.event_busy_outlined,
                      color: AppColors.expenseColor(ctx)),
                  title: Text('Hapus Tenggat',
                      style: TextStyle(color: AppColors.expenseColor(ctx))),
                  onTap: () => Navigator.pop(ctx, 'clear'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'clear') {
      await SyncService.instance.updateTaskFields(
        taskId: task.id,
        companion: const LocalTasksCompanion(
          dueAt: Value(null),
          dueIsDateOnly: Value(false),
        ),
        remotePayload: {'due_at': null, 'due_is_date_only': false},
      );
      await _loadData();
      return;
    }

    final baseDate = task.dueAt ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: baseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        task.dueAt ?? DateTime(baseDate.year, baseDate.month, baseDate.day, 17),
      ),
    );
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? 23,
      pickedTime?.minute ?? 59,
    );
    final dateOnly = pickedTime == null;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(
        dueAt: Value(combined),
        dueIsDateOnly: Value(dateOnly),
      ),
      remotePayload: {
        'due_at': combined.toUtc().toIso8601String(),
        'due_is_date_only': dateOnly,
      },
    );
    await _loadData();
  }

  Future<void> _editEstimateMinutes() async {
    final task = _task;
    if (task == null) return;
    final ctrl = TextEditingController(
      text: task.estimateMinutes?.toString() ?? '',
    );
    final res = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estimasi Durasi (menit)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Contoh: 45 (kosongkan untuk hapus)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              if (raw.isEmpty) {
                Navigator.pop(ctx, 0);
                return;
              }
              final parsed = int.tryParse(raw);
              if (parsed != null && parsed > 0) {
                Navigator.pop(ctx, parsed);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null || res < 0) return;
    final nextEstimate = res == 0 ? null : res;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(estimateMinutes: Value(nextEstimate)),
      remotePayload: {'estimate_minutes': nextEstimate},
    );
    await _loadData();
  }

  String _assigneeLabel(String? assigneeId) {
    if (assigneeId == null || assigneeId.trim().isEmpty) {
      return 'Belum ditugaskan';
    }
    for (final m in _members) {
      if (m.userId == assigneeId) {
        if (m.displayName != null && m.displayName!.trim().isNotEmpty) {
          return m.displayName!;
        }
        if (m.email != null && m.email!.trim().isNotEmpty) {
          return m.email!;
        }
        return 'Anggota (${m.role})';
      }
    }
    return assigneeId.length > 10
        ? '${assigneeId.substring(0, 8)}...'
        : assigneeId;
  }

  Future<void> _pickAssignee() async {
    final task = _task;
    if (task == null) return;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pilih Penanggung Jawab',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(ctx),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                ListTile(
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('Belum ditugaskan'),
                  selected: task.assigneeId == null,
                  onTap: () => Navigator.of(ctx).pop(''),
                ),
                if (_members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Belum ada anggota kolaborasi lain tersinkron di workspace ini.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedColor(ctx),
                      ),
                    ),
                  )
                else
                  for (final m in _members)
                    ListTile(
                      minVerticalPadding: 12,
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        m.displayName ?? m.email ?? m.userId,
                      ),
                      subtitle: Text('Peran: ${m.role}'),
                      selected: task.assigneeId == m.userId,
                      onTap: () => Navigator.of(ctx).pop(m.userId),
                    ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    final nextAssignee = picked.isEmpty ? null : picked;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(assigneeId: Value(nextAssignee)),
      remotePayload: {'assignee_id': nextAssignee},
    );
    await _loadData();
  }

  Future<void> _editRecurrence() async {
    final task = _task;
    if (task == null) return;
    final current = _parseRecurrence(task.recurrenceRuleJson);
    String freq = current['freq'] as String? ?? 'none';
    int interval = (current['interval'] as num?)?.toInt() ?? 1;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atur Pengulangan Tugas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(ctx),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opt in const [
                      MapEntry('none', 'Tidak Berulang'),
                      MapEntry('daily', 'Harian'),
                      MapEntry('weekly', 'Mingguan'),
                      MapEntry('monthly', 'Bulanan'),
                    ])
                      ChoiceChip(
                        label: Text(opt.value),
                        selected: freq == opt.key,
                        onSelected: (_) => setModalState(() => freq = opt.key),
                      ),
                  ],
                ),
                if (freq != 'none') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Ulangi setiap:'),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Kurangi interval pengulangan',
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: interval > 1
                            ? () => setModalState(() => interval--)
                            : null,
                      ),
                      Text(
                        '$interval',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tambah interval pengulangan',
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: interval < 30
                            ? () => setModalState(() => interval++)
                            : null,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Simpan Pengulangan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final nextRule =
        freq == 'none' ? null : {'freq': freq, 'interval': interval};
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(
        recurrenceRuleJson:
            Value(nextRule != null ? jsonEncode(nextRule) : null),
      ),
      remotePayload: {'recurrence_rule': nextRule},
    );
    await _loadData();
  }

  Future<void> _editTags() async {
    final task = _task;
    if (task == null) return;
    final existing = _parseTags(task.tagsJson);
    final ctrl = TextEditingController(text: existing.join(', '));
    final updated = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tag Tugas'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Pisahkan dengan koma, mis: penting, klien, ui',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final list = ctrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();
              Navigator.pop(ctx, list);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (updated == null) return;
    await SyncService.instance.updateTaskFields(
      taskId: task.id,
      companion: LocalTasksCompanion(
        tagsJson: Value(updated.isEmpty ? null : jsonEncode(updated)),
      ),
      remotePayload: {'tags': updated},
    );
    await _loadData();
  }

  Future<void> _saveAsTemplate() async {
    final task = _task;
    if (task == null) return;
    final nameCtrl = TextEditingController(text: task.title);
    final chosenName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan sebagai Template'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Template'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            child: const Text('Simpan Template'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (chosenName == null) return;

    await SyncService.instance.saveTaskAsTemplate(
      name: chosenName,
      kind: task.kind,
      defaultPriority: task.priority,
      defaultEstimateMinutes: task.estimateMinutes,
      checklistTexts: _checklists.map((c) => c.textContent).toList(),
      blocksJson: task.descriptionBlocksJson,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "$chosenName" berhasil disimpan.')),
    );
  }

  Future<void> _deleteTask() async {
    final task = _task;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tugas?'),
        content: Text('Tugas "${task.title}" akan dipindahkan ke arsip hapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expenseColor(ctx),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SyncService.instance.deleteTask(task.id);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _addEntityLinkDialog() async {
    final task = _task;
    if (task == null) return;
    String targetType = 'project';
    String relationType = 'related';

    final projects = _allProjects;
    final tasks = await (_db.select(_db.localTasks)
          ..where(
              (t) => t.deletedAt.isNull() & t.id.equals(task.id).not())
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
    final events = await (_db.select(_db.localEvents)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.startsAt)])
          ..limit(20))
        .get();
    final transactions = await (_db.select(_db.localTransactions)
          ..where((tr) => tr.deletedAt.isNull())
          ..orderBy([(tr) => OrderingTerm.desc(tr.occurredAt)])
          ..limit(20))
        .get();

    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final candidates = <MapEntry<String, String>>[];
          if (targetType == 'project') {
            for (final p in projects) {
              candidates.add(MapEntry(p.id, p.name));
            }
          } else if (targetType == 'task') {
            for (final t in tasks) {
              candidates.add(MapEntry(t.id, t.title));
            }
          } else if (targetType == 'event') {
            for (final e in events) {
              candidates.add(MapEntry(e.id, e.title));
            }
          } else if (targetType == 'transaction') {
            for (final tr in transactions) {
              candidates.add(MapEntry(
                tr.id,
                tr.merchant ?? tr.note ?? formatRupiah(tr.amount),
              ));
            }
          }

          return FractionallySizedBox(
            heightFactor: 0.72,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Text(
                      'Tautkan Entitas Terkait',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(ctx),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (final entry in const [
                          MapEntry('project', 'Proyek'),
                          MapEntry('task', 'Tugas'),
                          MapEntry('event', 'Acara'),
                          MapEntry('transaction', 'Transaksi'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: targetType == entry.key,
                              onSelected: (_) =>
                                  setModalState(() => targetType = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: relationType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Relasi',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'related', child: Text('Terkait (Related)')),
                        DropdownMenuItem(
                            value: 'blocks', child: Text('Memblokir (Blocks)')),
                        DropdownMenuItem(
                            value: 'blocked_by',
                            child: Text('Diblokir oleh (Blocked by)')),
                        DropdownMenuItem(
                            value: 'funded_by',
                            child: Text('Didanai oleh (Funded by)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => relationType = v);
                      },
                    ),
                  ),
                  Divider(height: 1, color: AppColors.borderColor(ctx)),
                  Expanded(
                    child: candidates.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada item untuk tipe ini.',
                              style: TextStyle(
                                color: AppColors.textSecondaryColor(ctx),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: candidates.length,
                            itemBuilder: (ctx, idx) {
                              final item = candidates[idx];
                              return ListTile(
                                title: Text(item.value),
                                trailing:
                                    const Icon(Icons.add_link_rounded, size: 18),
                                onTap: () => Navigator.pop(ctx, {
                                  'targetType': targetType,
                                  'targetId': item.key,
                                  'relationType': relationType,
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null) return;
    await SyncService.instance.addEntityLink(
      sourceType: 'task',
      sourceId: task.id,
      targetType: result['targetType']!,
      targetId: result['targetId']!,
      relationType: result['relationType']!,
    );
    await _loadData();
  }

  Future<void> _addAttachmentDialog() async {
    final task = _task;
    if (task == null) return;
    final nameCtrl = TextEditingController();
    final sizeCtrl = TextEditingController(text: '256');
    String mime = 'application/pdf';

    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambah Metadata Lampiran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mencatat referensi dokumen secara offline-first. Unggahan berkas biner ke bucket Storage memerlukan akses file perangkat dan koneksi cloud.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nama berkas',
                        hintText: 'Contoh: brief-desain-v2.pdf',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mime,
                      decoration: const InputDecoration(labelText: 'Jenis MIME'),
                      items: const [
                        DropdownMenuItem(
                            value: 'application/pdf',
                            child: Text('PDF (application/pdf)')),
                        DropdownMenuItem(
                            value: 'image/png', child: Text('Gambar PNG')),
                        DropdownMenuItem(
                            value: 'image/jpeg', child: Text('Gambar JPEG')),
                        DropdownMenuItem(
                            value: 'image/webp', child: Text('Gambar WEBP')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => mime = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sizeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Perkiraan ukuran (KB)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: () {
                          final n = nameCtrl.text.trim();
                          if (n.isEmpty) return;
                          final kb = int.tryParse(sizeCtrl.text.trim()) ?? 100;
                          Navigator.pop(ctx, {
                            'fileName': n,
                            'mime': mime,
                            'size': kb * 1024,
                          });
                        },
                        child: const Text('Simpan Lampiran'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    nameCtrl.dispose();
    sizeCtrl.dispose();
    if (res == null) return;

    await SyncService.instance.addAttachmentMetadata(
      ownerTable: 'tasks',
      ownerId: task.id,
      fileName: res['fileName'] as String,
      mime: res['mime'] as String,
      size: res['size'] as int,
    );
    await _loadData();
  }

  Future<String?> _showSimpleChoiceSheet({
    required String title,
    required List<MapEntry<String, String>> options,
    required String selectedKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(ctx),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.borderColor(ctx)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((opt) {
                    final selected = opt.key == selectedKey;
                    return ListTile(
                      title: Text(opt.value),
                      trailing: selected
                          ? Icon(Icons.check_rounded,
                              color: AppColors.accentColor(ctx))
                          : null,
                      onTap: () => Navigator.pop(ctx, opt.key),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseRecurrence(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return const {};
    try {
      final d = jsonDecode(jsonStr);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return const {};
  }

  List<String> _parseTags(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return const [];
    try {
      final d = jsonDecode(jsonStr);
      if (d is List) return d.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  String _recurrenceLabel(String? jsonStr) {
    final rec = _parseRecurrence(jsonStr);
    final freq = rec['freq']?.toString();
    final interval = (rec['interval'] as num?)?.toInt() ?? 1;
    switch (freq) {
      case 'daily':
        return interval <= 1 ? 'Setiap hari' : 'Tiap $interval hari';
      case 'weekly':
        return interval <= 1 ? 'Setiap minggu' : 'Tiap $interval minggu';
      case 'monthly':
        return interval <= 1 ? 'Setiap bulan' : 'Tiap $interval bulan';
      default:
        return 'Tidak berulang';
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'tinggi':
        return 'Tinggi';
      case 'rendah':
        return 'Rendah';
      default:
        return 'Sedang';
    }
  }

  String _relationLabel(String rel) {
    switch (rel) {
      case 'blocks':
        return 'Memblokir';
      case 'blocked_by':
        return 'Diblokir oleh';
      case 'funded_by':
        return 'Didanai oleh';
      case 'derived_from':
        return 'Turunan dari';
      default:
        return 'Terkait';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final borderCol = AppColors.borderColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);
    final textMuted = AppColors.textMutedColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Tugas')),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final task = _task;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Tugas')),
        body: OrbitEmptyState(
          icon: Icons.assignment_late_outlined,
          title: 'Tugas tidak ditemukan',
          description: 'Tugas mungkin telah dihapus atau belum disinkronkan.',
          actionLabel: 'Kembali',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    final tags = _parseTags(task.tagsJson);
    final lockedProgress = _checklists.isNotEmpty || _subtasks.isNotEmpty;
    final isOverdue = isOrbitTaskOverdue(task);
    final isStagnant = isOrbitTaskStagnant(task);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          IconButton(
            tooltip: 'Simpan sebagai Template',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.library_add_outlined, size: 20),
            onPressed: _saveAsTemplate,
          ),
          IconButton(
            tooltip: 'Hapus Tugas',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.expenseColor(context),
            ),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
          children: [
            // Breadcrumb Parent Task jika ini adalah subtugas
            if (_parentTask != null) ...[
              InkWell(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              OrbitTaskDetailPage(taskId: _parentTask!.id),
                        ),
                      )
                      .then((_) => _loadData());
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.subtleColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.subdirectory_arrow_left_rounded,
                          size: 15, color: textSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Subtugas dari: ${_parentTask!.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accentColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Kind & Revision Quick Tags
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickKind,
                  child: OrbitKindBadge(kind: task.kind),
                ),
                OrbitTaskStatusBadge(status: task.status),
                if (task.revisionCount > 0)
                  OrbitStatusBadge(
                    label: 'Revisi ${task.revisionCount} kali',
                    variant: OrbitBadgeVariant.warning,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Editable Title
            InkWell(
              onTap: _editTitle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          decoration: task.status == 'done'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(Icons.edit_outlined,
                          size: 18, color: textMuted),
                    ),
                  ],
                ),
              ),
            ),

            // Alert Revisi / Overdue / Macet >5 hari
            if (task.status == 'revisi' || isOverdue || isStagnant) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? (isDark
                          ? AppColors.expenseSubtleDark
                          : AppColors.expenseSubtleLight)
                      : AppColors.getTaskStatusBg('revisi', isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: AppColors.getTaskStatusBorder('revisi',
                        isDark: isDark),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.status == 'revisi') ...[
                      Text(
                        'Catatan Revisi Terbaru',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTaskStatusFg('revisi',
                              isDark: isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (task.latestRevisionNote != null &&
                                task.latestRevisionNote!.trim().isNotEmpty)
                            ? task.latestRevisionNote!
                            : 'Menunggu perbaikan revisi.',
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      ),
                    ],
                    if (isOverdue)
                      Text(
                        'Tugas telah melewati tenggat waktu.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.expenseColor(context),
                        ),
                      ),
                    if (isStagnant)
                      Text(
                        'Status belum berubah selama lebih dari 5 hari.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warningColor(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Inline Property Grid bergaya Notion
            OrbitBlockContainer(
              title: 'Properti',
              child: Column(
                children: [
                  OrbitPropertyRow(
                    label: 'Status',
                    value: OrbitPropertyChip(
                      icon: Icons.flag_outlined,
                      label: AppColors.getTaskStatusLabel(task.status),
                      foreground: AppColors.getTaskStatusFg(task.status,
                          isDark: isDark),
                      background: AppColors.getTaskStatusBg(task.status,
                          isDark: isDark),
                      borderColor: AppColors.getTaskStatusBorder(task.status,
                          isDark: isDark),
                      onTap: () => showOrbitStatusPickerSheet(
                        context,
                        task: task,
                        onSelected: (toStatus, note) async {
                          await SyncService.instance.changeTaskStatus(
                            taskId: task.id,
                            toStatus: toStatus,
                            note: note,
                          );
                          await _loadData();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Prioritas',
                    value: OrbitPropertyChip(
                      icon: Icons.low_priority_rounded,
                      label: _priorityLabel(task.priority),
                      foreground: task.priority == 'tinggi'
                          ? AppColors.expenseColor(context)
                          : null,
                      onTap: _pickPriority,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Tenggat',
                    value: OrbitPropertyChip(
                      icon: Icons.calendar_today_outlined,
                      label: task.dueAt != null
                          ? (task.dueIsDateOnly
                              ? DateFormat('dd MMM yyyy').format(task.dueAt!)
                              : DateFormat('dd MMM yyyy, HH:mm')
                                  .format(task.dueAt!))
                          : 'Atur tenggat',
                      foreground:
                          isOverdue ? AppColors.expenseColor(context) : null,
                      onTap: _pickDueDate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Proyek',
                    value: OrbitPropertyChip(
                      icon: Icons.folder_outlined,
                      label: _project?.name ?? 'Tanpa proyek',
                      onTap: _pickProject,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Estimasi',
                    value: OrbitPropertyChip(
                      icon: Icons.timer_outlined,
                      label: task.estimateMinutes != null
                          ? '${task.estimateMinutes} menit'
                          : 'Atur estimasi',
                      onTap: _editEstimateMinutes,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Penanggung',
                    value: OrbitPropertyChip(
                      icon: Icons.person_outline,
                      label: _assigneeLabel(task.assigneeId),
                      onTap: _pickAssignee,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Pengulangan',
                    value: OrbitPropertyChip(
                      icon: Icons.repeat_rounded,
                      label: _recurrenceLabel(task.recurrenceRuleJson),
                      onTap: _editRecurrence,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Revisi',
                    value: OrbitPropertyChip(
                      icon: Icons.history_rounded,
                      label: 'Revisi ${task.revisionCount} kali',
                      onTap: null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitPropertyRow(
                    label: 'Tag',
                    value: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...tags.map(
                          (tg) => OrbitPropertyChip(
                            icon: Icons.label_outline_rounded,
                            label: tg,
                            onTap: _editTags,
                          ),
                        ),
                        OrbitPropertyChip(
                          icon: Icons.add_rounded,
                          label: tags.isEmpty ? 'Tambah Tag' : 'Ubah Tag',
                          onTap: _editTags,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Progress Control (otomatis terkunci jika ada checklist / subtugas)
            OrbitBlockContainer(
              title: 'Progres Penyelesaian',
              trailing: lockedProgress
                  ? Text(
                      _checklists.isNotEmpty
                          ? 'Otomatis dari checklist'
                          : 'Otomatis dari subtugas',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    )
                  : null,
              child: OrbitProgressControl(
                value: task.progressPercent,
                lockedByChecklist: lockedProgress,
                onChanged: lockedProgress
                    ? null
                    : (val) async {
                        await SyncService.instance
                            .updateTaskProgressManual(task.id, val);
                        await _loadData();
                      },
              ),
            ),

            const SizedBox(height: 14),

            OrbitTimeTrackerBlock(
              taskId: task.id,
              estimateMinutes: task.estimateMinutes,
              onChanged: _loadData,
            ),

            const SizedBox(height: 14),

            // Deskripsi Notion-Sederhana
            OrbitBlockContainer(
              title: 'Catatan & Deskripsi',
              trailing: _descDirty
                  ? TextButton(
                      onPressed: _saveDescription,
                      child: const Text('Simpan'),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Tulis catatan, ringkasan, atau blok langkah kerja...',
                    ),
                    onChanged: (_) {
                      if (!_descDirty) {
                        setState(() => _descDirty = true);
                      }
                    },
                  ),
                  if (_descDirty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(110, 40),
                        ),
                        onPressed: _saveDescription,
                        child: const Text('Simpan Catatan'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Checklist Block
            OrbitBlockContainer(
              title: 'Checklist',
              trailing: Text(
                '${_checklists.where((c) => c.done).length}/${_checklists.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              child: Column(
                children: [
                  ..._checklists.map((item) => InkWell(
                        onTap: () async {
                          await SyncService.instance.toggleChecklistItem(
                            itemId: item.id,
                            done: !item.done,
                          );
                          await _loadData();
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            children: [
                              Checkbox(
                                value: item.done,
                                onChanged: (v) async {
                                  await SyncService.instance
                                      .toggleChecklistItem(
                                    itemId: item.id,
                                    done: v ?? false,
                                  );
                                  await _loadData();
                                },
                              ),
                              Expanded(
                                child: Text(
                                  item.textContent,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: item.done ? textMuted : textPrimary,
                                    decoration: item.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus item checklist',
                                constraints: const BoxConstraints(
                                    minWidth: 44, minHeight: 44),
                                icon: Icon(Icons.close_rounded,
                                    size: 17, color: textMuted),
                                onPressed: () async {
                                  await SyncService.instance
                                      .deleteChecklistItem(item.id);
                                  await _loadData();
                                },
                              ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checklistCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Tambah item checklist...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleAddChecklist(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _handleAddChecklist,
                          child: const Text('Tambah'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Nested Subtasks
            OrbitBlockContainer(
              title: 'Subtugas',
              trailing: Text(
                '${_subtasks.where((s) => s.status == 'done').length}/${_subtasks.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              child: Column(
                children: [
                  ..._subtasks.map((sub) {
                    final subDone = sub.status == 'done';
                    return ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          Checkbox(
                            value: subDone,
                            onChanged: (v) async {
                              await SyncService.instance.changeTaskStatus(
                                taskId: sub.id,
                                toStatus: (v ?? false) ? 'done' : 'todo',
                              );
                              await _loadData();
                            },
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            OrbitTaskDetailPage(taskId: sub.id),
                                      ),
                                    )
                                    .then((_) => _loadData());
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sub.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: subDone
                                              ? textMuted
                                              : textPrimary,
                                          decoration: subDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    OrbitTaskStatusBadge(
                                      status: sub.status,
                                      compact: true,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 16, color: textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subtaskCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Tambah subtugas baru...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleAddSubtask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _handleAddSubtask,
                          child: const Text('Tambah'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Entity Links
            OrbitBlockContainer(
              title: 'Tautan Entitas',
              trailing: TextButton.icon(
                onPressed: _addEntityLinkDialog,
                icon: const Icon(Icons.add_link_rounded, size: 17),
                label: const Text('Tautkan'),
              ),
              child: _links.isEmpty
                  ? Text(
                      'Belum ada proyek, acara, transaksi, atau tugas yang ditautkan.',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    )
                  : Column(
                      children: _links.map((item) {
                        return ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            children: [
                              OrbitStatusBadge(
                                label: _relationLabel(item.link.relationType),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.peerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Putus tautan',
                                constraints: const BoxConstraints(
                                    minWidth: 44, minHeight: 44),
                                icon: Icon(Icons.link_off_rounded,
                                    size: 17, color: textMuted),
                                onPressed: () async {
                                  await SyncService.instance
                                      .deleteEntityLink(item.link.id);
                                  await _loadData();
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 14),

            // Lampiran
            OrbitBlockContainer(
              title: 'Lampiran',
              trailing: TextButton.icon(
                onPressed: _addAttachmentDialog,
                icon: const Icon(Icons.attach_file_rounded, size: 17),
                label: const Text('Tambah'),
              ),
              child: _attachments.isEmpty
                  ? Text(
                      'Belum ada lampiran metadata.',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    )
                  : Column(
                      children: _attachments.map((att) {
                        return ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file_outlined,
                                  size: 18, color: textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      att.fileName ?? att.storagePath,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${att.mime} - ${_formatBytes(att.size)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textMuted,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus lampiran',
                                constraints: const BoxConstraints(
                                    minWidth: 44, minHeight: 44),
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 18, color: textMuted),
                                onPressed: () async {
                                  await SyncService.instance
                                      .deleteAttachmentMetadata(att.id);
                                  await _loadData();
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 14),

            // Komentar
            OrbitBlockContainer(
              title: 'Komentar',
              trailing: Text(
                '${_comments.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              child: Column(
                children: [
                  if (_comments.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Belum ada komentar.',
                          style: TextStyle(fontSize: 12.5, color: textMuted),
                        ),
                      ),
                    )
                  else
                    ..._comments.map((c) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.subtleColor(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderCol),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm')
                                        .format(c.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textMuted,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () async {
                                      await SyncService.instance
                                          .deleteComment(c.id);
                                      await _loadData();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(Icons.delete_outline_rounded,
                                          size: 15, color: textMuted),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.body,
                                style:
                                    TextStyle(fontSize: 13.5, color: textPrimary),
                              ),
                            ],
                          ),
                        )),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Tulis komentar atau catatan progres...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleAddComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Kirim komentar',
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        onPressed: _handleAddComment,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Riwayat Status
            OrbitBlockContainer(
              title: 'Riwayat Status',
              child: _histories.isEmpty
                  ? Text(
                      'Belum ada perubahan status tercatat.',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    )
                  : Column(
                      children: _histories.map((h) {
                        final fromLabel = h.fromStatus != null
                            ? AppColors.getTaskStatusLabel(h.fromStatus!)
                            : 'Awal';
                        final toLabel =
                            AppColors.getTaskStatusLabel(h.toStatus);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.getTaskStatusFg(
                                      h.toStatus,
                                      isDark: isDark,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$fromLabel -> $toLabel',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd MMM yyyy, HH:mm')
                                          .format(h.createdAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textMuted,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    if (h.note != null &&
                                        h.note!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Catatan: ${h.note!}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddChecklist() async {
    final text = _checklistCtrl.text.trim();
    if (text.isEmpty || _task == null) return;
    _checklistCtrl.clear();
    await SyncService.instance.addChecklistItem(
      taskId: _task!.id,
      text: text,
    );
    await _loadData();
  }

  Future<void> _handleAddSubtask() async {
    final title = _subtaskCtrl.text.trim();
    if (title.isEmpty || _task == null) return;
    _subtaskCtrl.clear();
    await SyncService.instance.createTask(
      title: title,
      kind: _task!.kind,
      projectId: _task!.projectId,
      parentTaskId: _task!.id,
      priority: 'sedang',
    );
    await _loadData();
  }

  Future<void> _handleAddComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _task == null) return;
    _commentCtrl.clear();
    await SyncService.instance.addComment(
      entityType: 'task',
      entityId: _task!.id,
      body: body,
    );
    await _loadData();
  }
}

class _ResolvedEntityLink {
  final LocalEntityLink link;
  final String peerType;
  final String peerId;
  final String peerTitle;

  const _ResolvedEntityLink({
    required this.link,
    required this.peerType,
    required this.peerId,
    required this.peerTitle,
  });
}
