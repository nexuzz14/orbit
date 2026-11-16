import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/features/tasks/orbit_task_detail_page.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_add_task_sheet.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_kanban_board.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_revision_dialog.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_task_row.dart';

/// Layar manajemen tugas Orbit v2 dengan switcher Daftar | Papan | Proyek,
/// Saved Views, Kanban D.2 horizontal, template tugas, dan detail gaya Notion/Jira.
class TasksScreen extends StatefulWidget {
  final bool embedded;
  final bool forceLoading;
  final String? forceError;
  final String? initialSavedViewId;
  final String? initialProjectId;
  final String? initialViewMode;

  const TasksScreen({
    super.key,
    this.embedded = false,
    this.forceLoading = false,
    this.forceError,
    this.initialSavedViewId,
    this.initialProjectId,
    this.initialViewMode,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  AppDatabase get _db => AppDatabase.shared;

  bool _loading = true;
  String? _errorMessage;
  String _selectedKind = 'all'; // all | intern | freelance | kuliah | pribadi
  String? _selectedProjectId;
  String _viewMode = 'list'; // list | board | timeline
  String? _activeSavedViewId;

  List<LocalTask> _allTasks = [];
  Map<String, LocalProject> _projectsById = {};
  List<LocalSavedView> _savedViews = [];
  Map<String, _ItemCounts> _checklistCounts = {};
  Map<String, _ItemCounts> _subtaskCounts = {};

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    if (widget.initialViewMode != null) {
      _viewMode = _normalizeViewMode(widget.initialViewMode!);
    }
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadTasks();
      SyncService.instance.pullAllFromSupabase().then((_) {
        if (mounted) _loadTasks();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSavedViewId != oldWidget.initialSavedViewId &&
        widget.initialSavedViewId != null) {
      final matching = _savedViews
          .where((v) => v.id == widget.initialSavedViewId)
          .firstOrNull;
      if (matching != null) {
        _applySavedView(matching);
      } else {
        _activeSavedViewId = widget.initialSavedViewId;
        _loadTasks();
      }
    }
    if (widget.initialProjectId != oldWidget.initialProjectId &&
        widget.initialProjectId != null) {
      setState(() {
        _selectedProjectId = widget.initialProjectId;
        _activeSavedViewId = null;
      });
    }
  }

  String _normalizeViewMode(String raw) {
    switch (raw) {
      case 'board':
      case 'papan':
        return 'board';
      case 'timeline':
      case 'proyek':
        return 'timeline';
      default:
        return 'list';
    }
  }

  Future<void> _loadTasks({bool pull = false}) async {
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
      final tasks = await (_db.select(_db.localTasks)
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.dueAt),
            ]))
          .get();
      final projects = await (_db.select(_db.localProjects)
            ..where((p) => p.deletedAt.isNull()))
          .get();
      final checklists = await _db.select(_db.localTaskChecklistItems).get();
      final savedViews = await (_db.select(_db.localSavedViews)
            ..where(
                (v) => v.deletedAt.isNull() & v.scope.equals('tasks'))
            ..orderBy([
              (v) => OrderingTerm.desc(v.isPinned),
              (v) => OrderingTerm.asc(v.sortOrder),
              (v) => OrderingTerm.desc(v.createdAt),
            ]))
          .get();

      final activeTasks = tasks.where((t) => t.deletedAt == null).toList();
      final projectMap = {for (final p in projects) p.id: p};

      final clCounts = <String, _ItemCounts>{};
      for (final item in checklists) {
        final prev = clCounts[item.taskId] ?? const _ItemCounts(0, 0);
        clCounts[item.taskId] = _ItemCounts(
          prev.total + 1,
          prev.done + (item.done ? 1 : 0),
        );
      }

      final subCounts = <String, _ItemCounts>{};
      for (final t in activeTasks) {
        if (t.parentTaskId != null && t.parentTaskId!.isNotEmpty) {
          final prev = subCounts[t.parentTaskId!] ?? const _ItemCounts(0, 0);
          subCounts[t.parentTaskId!] = _ItemCounts(
            prev.total + 1,
            prev.done + (t.status == 'done' ? 1 : 0),
          );
        }
      }

      if (mounted) {
        setState(() {
          _allTasks = activeTasks;
          _projectsById = projectMap;
          _checklistCounts = clCounts;
          _subtaskCounts = subCounts;
          _savedViews = savedViews;
        });

        if (widget.initialSavedViewId != null &&
            _activeSavedViewId == null) {
          final found = savedViews
              .where((v) => v.id == widget.initialSavedViewId)
              .firstOrNull;
          if (found != null) {
            _applySavedView(found);
          }
        }
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

  void _applySavedView(LocalSavedView? view) {
    if (view == null) {
      setState(() {
        _activeSavedViewId = null;
        _selectedKind = 'all';
        _selectedProjectId = null;
      });
      return;
    }

    String nextKind = 'all';
    String? nextProjectId;
    try {
      final decoded = jsonDecode(view.filterJson);
      if (decoded is Map) {
        if (decoded['kind'] is String && (decoded['kind'] as String).isNotEmpty) {
          nextKind = decoded['kind'] as String;
        }
        if (decoded['projectId'] is String &&
            (decoded['projectId'] as String).isNotEmpty) {
          nextProjectId = decoded['projectId'] as String;
        }
      }
    } catch (_) {}

    setState(() {
      _activeSavedViewId = view.id;
      _viewMode = _normalizeViewMode(view.viewMode);
      _selectedKind = nextKind;
      _selectedProjectId = nextProjectId;
    });
  }

  Future<void> _showSaveCurrentViewDialog() async {
    final nameCtrl = TextEditingController();
    bool isPinned = false;
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Simpan Tampilan Saat Ini'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama tampilan',
                  hintText: 'Contoh: Papan Freelance Aktif',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isPinned,
                onChanged: (v) => setDialogState(() => isPinned = v ?? false),
                title: const Text(
                  'Sematkan ke Workspace Drawer',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final n = nameCtrl.text.trim();
                if (n.isNotEmpty) {
                  Navigator.pop(ctx, {'name': n, 'isPinned': isPinned});
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (res == null) return;

    final newId = await SyncService.instance.saveSavedView(
      name: res['name'] as String,
      scope: 'tasks',
      viewMode: _viewMode,
      filters: {
        if (_selectedKind != 'all') 'kind': _selectedKind,
        if (_selectedProjectId != null) 'projectId': _selectedProjectId,
      },
      isPinned: res['isPinned'] as bool,
    );
    await _loadTasks();
    if (mounted) {
      setState(() => _activeSavedViewId = newId);
    }
  }

  Future<void> _handleChangeStatus(
    LocalTask task,
    String toStatus,
    String? note,
  ) async {
    await SyncService.instance.changeTaskStatus(
      taskId: task.id,
      toStatus: toStatus,
      note: note,
    );
    try {
      await NotificationSchedulerService.rescheduleAll(_db);
    } catch (_) {}
    await _loadTasks();
  }

  Future<void> _toggleDoneCheckbox(LocalTask task) async {
    final nextStatus = task.status == 'done' ? 'todo' : 'done';
    await _handleChangeStatus(task, nextStatus, null);
  }

  Future<void> _openTaskDetail(LocalTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrbitTaskDetailPage(taskId: task.id),
      ),
    );
    if (mounted) {
      await _loadTasks();
    }
  }

  Future<void> _openAddTask() async {
    final createdId = await showOrbitAddTaskSheet(
      context,
      initialProjectId: _selectedProjectId,
    );
    if (createdId != null && mounted) {
      await _loadTasks();
    }
  }

  List<LocalTask> _filteredTopLevelTasks() {
    final allIds = {for (final t in _allTasks) t.id};
    return _allTasks.where((t) {
      // Hanya tampilkan tugas tingkat atas (subtugas terlihat di halaman detail)
      if (t.parentTaskId != null &&
          t.parentTaskId!.isNotEmpty &&
          allIds.contains(t.parentTaskId)) {
        return false;
      }
      if (_selectedKind != 'all' && t.kind != _selectedKind) {
        return false;
      }
      if (_selectedProjectId != null && t.projectId != _selectedProjectId) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTopLevelTasks();
    final selectedProject = _selectedProjectId != null
        ? _projectsById[_selectedProjectId!]
        : null;

    final body = Column(
      children: [
        // Kontrol atas: ViewSwitcher (`Daftar | Papan | Proyek`) + tombol Tambah
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: OrbitViewSwitcher(
                  activeViewMode: _viewMode,
                  onChanged: (m) => setState(() => _viewMode = m),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _openAddTask,
                tooltip: 'Tambah Tugas',
                constraints: const BoxConstraints(
                  minWidth: AppTokens.minTouchTarget,
                  minHeight: AppTokens.minTouchTarget,
                ),
                icon: const Icon(Icons.add_rounded, size: 22),
              ),
            ],
          ),
        ),

        // Bar Saved Views
        OrbitSavedViewsBar(
          views: _savedViews,
          activeViewId: _activeSavedViewId,
          onSelectView: _applySavedView,
          onSaveCurrentView: _showSaveCurrentViewDialog,
          onTogglePin: (view) async {
            await SyncService.instance
                .togglePinSavedView(view.id, !view.isPinned);
            await _loadTasks();
          },
          onDeleteView: (view) async {
            await SyncService.instance.deleteSavedView(view.id);
            if (_activeSavedViewId == view.id) {
              _activeSavedViewId = null;
            }
            await _loadTasks();
          },
        ),

        // Chip Filter Konteks + Indikator Proyek Aktif
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              if (selectedProject != null) ...[
                InputChip(
                  label: Text('Proyek: ${selectedProject.name}'),
                  selected: true,
                  onDeleted: () => setState(() => _selectedProjectId = null),
                ),
                const SizedBox(width: 8),
              ],
              for (final entry in const [
                ('all', 'Semua'),
                ('intern', 'Intern'),
                ('freelance', 'Freelance'),
                ('kuliah', 'Kuliah'),
                ('pribadi', 'Pribadi'),
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(entry.$2),
                    selected: _selectedKind == entry.$1,
                    onSelected: (_) => setState(() => _selectedKind = entry.$1),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Area Konten Utama
        Expanded(
          child: _buildMainContent(filtered),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        leading: OrbitShellScope.maybeOf(context) != null
            ? const OrbitShellMenuButton()
            : null,
        title: const Text(
          'Tugas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (OrbitShellScope.maybeOf(context) != null)
            const OrbitShellSearchButton(),
          IconButton(
            onPressed: _openAddTask,
            tooltip: 'Tambah Tugas',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildMainContent(List<LocalTask> filtered) {
    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OrbitErrorState(
            message: _errorMessage!,
            onRetry: _loadTasks,
          ),
        ],
      );
    }

    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          OrbitSkeleton(height: 84),
          SizedBox(height: 12),
          OrbitSkeleton(height: 84),
          SizedBox(height: 12),
          OrbitSkeleton(height: 84),
        ],
      );
    }

    if (_viewMode == 'board') {
      return OrbitKanbanBoard(
        tasks: filtered,
        projectsById: _projectsById,
        onTapTask: _openTaskDetail,
        onChangeStatus: _handleChangeStatus,
      );
    }

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadTasks(pull: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
          children: [
            OrbitEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Belum ada tugas aktif',
              description:
                  'Catat tugas kuliah, pekerjaan, atau pribadi lengkap dengan tenggat dan prioritas.',
              actionLabel: 'Tambah Tugas',
              onAction: _openAddTask,
            ),
          ],
        ),
      );
    }

    if (_viewMode == 'timeline') {
      return _buildProjectGroupedList(filtered);
    }

    return RefreshIndicator(
      onRefresh: () => _loadTasks(pull: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final task = filtered[idx];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildProjectGroupedList(List<LocalTask> filtered) {
    final grouped = <String, List<LocalTask>>{};
    for (final task in filtered) {
      final key = (task.projectId != null && _projectsById.containsKey(task.projectId))
          ? task.projectId!
          : '__none__';
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '__none__') return 1;
        if (b == '__none__') return -1;
        final nameA = _projectsById[a]?.name ?? '';
        final nameB = _projectsById[b]?.name ?? '';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

    return RefreshIndicator(
      onRefresh: () => _loadTasks(pull: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
        itemCount: keys.length,
        itemBuilder: (context, idx) {
          final key = keys[idx];
          final items = grouped[key]!;
          final project = key == '__none__' ? null : _projectsById[key];
          final doneCount = items.where((t) => t.status == 'done').length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        project != null
                            ? Icons.folder_outlined
                            : Icons.inbox_outlined,
                        size: 18,
                        color: project != null
                            ? AppColors.getKindColor(
                                project.kind,
                                isDark: Theme.of(context).brightness ==
                                    Brightness.dark,
                              )
                            : AppColors.textSecondaryColor(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project?.name ?? 'Tanpa Proyek',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ),
                      Text(
                        '$doneCount/${items.length} selesai',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final task in items) ...[
                  _buildTaskCard(task),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(LocalTask task) {
    final cl = _checklistCounts[task.id] ?? const _ItemCounts(0, 0);
    final sub = _subtaskCounts[task.id] ?? const _ItemCounts(0, 0);
    final projectName =
        task.projectId != null ? _projectsById[task.projectId!]?.name : null;

    return OrbitTaskCard(
      task: task,
      projectName: projectName,
      checklistTotal: cl.total,
      checklistDone: cl.done,
      subtaskTotal: sub.total,
      subtaskDone: sub.done,
      onTap: () => _openTaskDetail(task),
      onToggleDone: () => _toggleDoneCheckbox(task),
      onMoveStatus: () => showOrbitStatusPickerSheet(
        context,
        task: task,
        onSelected: (toStatus, note) =>
            _handleChangeStatus(task, toStatus, note),
      ),
    );
  }
}

class _ItemCounts {
  final int total;
  final int done;

  const _ItemCounts(this.total, this.done);
}
