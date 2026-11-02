import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class TasksScreen extends StatefulWidget {
  final bool embedded;
  final bool forceLoading;
  final String? forceError;

  const TasksScreen({
    super.key,
    this.embedded = false,
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  AppDatabase get _db => AppDatabase.shared;
  final _uuid = const Uuid();

  bool _loading = true;
  String? _errorMessage;
  String _selectedKind = 'all'; // all | intern | freelance | kuliah | pribadi
  String _viewMode = 'daftar'; // daftar | papan

  List<LocalTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    if (widget.forceLoading) return;
    setState(() {
      _loading = true;
      _errorMessage = widget.forceError;
    });

    if (widget.forceError != null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final tasks = await (_db.select(_db.localTasks)
            ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
          .get();

      if (mounted) {
        setState(() {
          _tasks = tasks.where((t) => t.deletedAt == null).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat tugas: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleStatus(LocalTask task) async {
    final nextStatus = task.status == 'done' ? 'todo' : 'done';
    await (_db.update(_db.localTasks)..where((t) => t.id.equals(task.id)))
        .write(
      LocalTasksCompanion(
        status: Value(nextStatus),
        completedAt: Value(nextStatus == 'done' ? DateTime.now() : null),
      ),
    );
    await _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await (_db.update(_db.localTasks)..where((t) => t.id.equals(id)))
        .write(LocalTasksCompanion(deletedAt: Value(DateTime.now())));
    await _loadTasks();
  }

  void _showAddTaskSheet() {
    final titleCtrl = TextEditingController();
    String priority = 'sedang'; // tinggi | sedang | rendah
    String selectedKind = 'kuliah';

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
                    'Tambah Tugas Baru',
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
                  labelText: 'Judul Tugas',
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'tinggi', label: Text('Tinggi')),
                  ButtonSegment(value: 'sedang', label: Text('Sedang')),
                  ButtonSegment(value: 'rendah', label: Text('Rendah')),
                ],
                selected: {priority},
                onSelectionChanged: (s) =>
                    setModalState(() => priority = s.first),
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
                    if (titleCtrl.text.trim().isEmpty) return;
                    await _db.into(_db.localTasks).insert(
                          LocalTasksCompanion.insert(
                            id: _uuid.v4(),
                            workspaceId: 'ws-local',
                            kind: selectedKind,
                            title: titleCtrl.text.trim(),
                            priority: Value(priority),
                            status: const Value('todo'),
                            dueAt: Value(
                              DateTime.now().add(const Duration(days: 1)),
                            ),
                          ),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadTasks();
                  },
                  child: const Text('Simpan Tugas'),
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

    final filtered = _tasks.where((t) {
      if (_selectedKind == 'all') return true;
      return t.kind == _selectedKind;
    }).toList();

    final content = RefreshIndicator(
      onRefresh: _loadTasks,
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
                    ButtonSegment(value: 'daftar', label: Text('Daftar')),
                    ButtonSegment(value: 'papan', label: Text('Papan')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) =>
                      setState(() => _viewMode = s.first),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              IconButton(
                onPressed: _showAddTaskSheet,
                tooltip: 'Tambah Tugas',
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

          if (_errorMessage != null) ...[
            OrbitErrorState(
              message: _errorMessage!,
              onRetry: _loadTasks,
            ),
            const SizedBox(height: AppTokens.space4),
          ],

          if (_loading) ...[
            const OrbitSkeleton(height: 80),
            const SizedBox(height: AppTokens.space3),
            const OrbitSkeleton(height: 80),
            const SizedBox(height: AppTokens.space3),
            const OrbitSkeleton(height: 80),
          ] else if (filtered.isEmpty) ...[
            OrbitEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Belum ada tugas aktif',
              description:
                  'Catat tugas kuliah, pekerjaan, atau pribadi lengkap dengan tenggat dan prioritas.',
              actionLabel: 'Tambah Tugas',
              onAction: _showAddTaskSheet,
            ),
          ] else ...[
            for (final task in filtered) ...[
              _buildTaskCard(context, task, secondaryColor),
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
          'Tugas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showAddTaskSheet,
            tooltip: 'Tambah Tugas',
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

  Widget _buildTaskCard(
    BuildContext context,
    LocalTask task,
    Color secondaryColor,
  ) {
    final isDone = task.status == 'done' || task.status == 'selesai';
    final pNorm = task.priority.toLowerCase();
    final priorityLabel = (pNorm == 'tinggi' || pNorm == '1')
        ? 'Prioritas Tinggi'
        : (pNorm == 'sedang' || pNorm == '2')
            ? 'Prioritas Sedang'
            : 'Prioritas Rendah';
    final priorityVariant = (pNorm == 'tinggi' || pNorm == '1')
        ? OrbitBadgeVariant.expense
        : (pNorm == 'sedang' || pNorm == '2')
            ? OrbitBadgeVariant.warning
            : OrbitBadgeVariant.neutral;

    return OrbitCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space3,
        vertical: AppTokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _toggleStatus(task),
            tooltip: isDone ? 'Tandai belum selesai' : 'Tandai selesai',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color:
                  isDone ? AppColors.incomeColor(context) : secondaryColor,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OrbitKindBadge(kind: task.kind),
                    OrbitStatusBadge(
                      label: priorityLabel,
                      variant: priorityVariant,
                    ),
                    if (task.dueAt != null)
                      Text(
                        'Tenggat: ${formatDateIndoShort(task.dueAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteTask(task.id),
            tooltip: 'Hapus Tugas',
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
