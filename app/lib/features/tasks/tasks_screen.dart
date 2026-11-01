import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _workspaceId;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _accounts = [];

  String _filterKind = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final member = await _supabase
          .from('workspace_members')
          .select('workspace_id')
          .limit(1)
          .maybeSingle();

      if (member == null) {
        setState(() => _loading = false);
        return;
      }

      final wsId = member['workspace_id'] as String;
      _workspaceId = wsId;

      final accRes = await _supabase
          .from('accounts')
          .select('id, name')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null)
          .order('sort_order');
      _accounts = List<Map<String, dynamic>>.from(accRes);

      final projRes = await _supabase
          .from('projects')
          .select('id, name, kind')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null);
      _projects = List<Map<String, dynamic>>.from(projRes);

      final taskRes = await _supabase
          .from('tasks')
          .select('*, projects(name), task_checklist_items(*)')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      _tasks = List<Map<String, dynamic>>.from(taskRes);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final taskId = task['id'] as String;
    final wasDone = task['status'] == 'done';

    setState(() {
      task['status'] = wasDone ? 'todo' : 'done';
    });

    try {
      final res = await _supabase.rpc('fn_complete_task', params: {
        'p_task_id': taskId,
      });

      if (!wasDone && res != null && res['milestone_payment_id'] != null) {
        final milestoneId = res['milestone_payment_id'] as String;
        _showMilestoneConfirmDialog(milestoneId, task['title'] as String);
      }
    } catch (_) {
      _loadData();
    }
  }

  void _showMilestoneConfirmDialog(String milestoneId, String taskTitle) {
    String? selectedAcc = _accounts.isNotEmpty ? _accounts.first['id'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Milestone Selesai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tugas "$taskTitle" terhubung dengan pembayaran termin. Tandai sebagai lunas sekarang?'),
              const SizedBox(height: 12),
              const Text('Akun Penerima:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedAcc,
                items: _accounts
                    .map((a) => DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedAcc = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nanti')),
            FilledButton(
              onPressed: () async {
                if (selectedAcc == null) return;
                Navigator.pop(ctx);
                try {
                  await _supabase.rpc('fn_mark_payment_paid', params: {
                    'p_payment_id': milestoneId,
                    'p_account_id': selectedAcc,
                  });
                  _loadData();
                } catch (_) {}
              },
              child: const Text('Tandai Lunas'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    String selectedKind = 'pribadi';
    String selectedPriority = 'sedang';
    String? selectedProject;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Tugas Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul Tugas *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedKind,
                decoration: const InputDecoration(labelText: 'Jenis Kegiatan', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'pribadi', child: Text('Pribadi')),
                  DropdownMenuItem(value: 'intern', child: Text('Magang')),
                  DropdownMenuItem(value: 'freelance', child: Text('Freelance')),
                  DropdownMenuItem(value: 'kuliah', child: Text('Kuliah')),
                ],
                onChanged: (val) => setDialogState(() => selectedKind = val ?? 'pribadi'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                decoration: const InputDecoration(labelText: 'Prioritas', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'tinggi', child: Text('Tinggi')),
                  DropdownMenuItem(value: 'sedang', child: Text('Sedang')),
                  DropdownMenuItem(value: 'rendah', child: Text('Rendah')),
                ],
                onChanged: (val) => setDialogState(() => selectedPriority = val ?? 'sedang'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedProject,
                decoration: const InputDecoration(labelText: 'Proyek Terkait (Opsional)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('(Tanpa Proyek)')),
                  ..._projects.map((p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(p['name'] as String),
                      )),
                ],
                onChanged: (val) => setDialogState(() => selectedProject = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty || _workspaceId == null) return;
                Navigator.pop(ctx);
                try {
                  await _supabase.from('tasks').insert({
                    'workspace_id': _workspaceId,
                    'title': title,
                    'kind': selectedKind,
                    'priority': selectedPriority,
                    'project_id': selectedProject,
                    'status': 'todo',
                  });
                  _loadData();
                } catch (_) {}
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tasks.where((t) {
      if (_filterKind != 'all' && t['kind'] != _filterKind) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Semua'),
                          selected: _filterKind == 'all',
                          onSelected: (_) => setState(() => _filterKind = 'all'),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Magang'),
                          selected: _filterKind == 'intern',
                          onSelected: (_) => setState(() => _filterKind = 'intern'),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Freelance'),
                          selected: _filterKind == 'freelance',
                          onSelected: (_) => setState(() => _filterKind = 'freelance'),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Kuliah'),
                          selected: _filterKind == 'kuliah',
                          onSelected: (_) => setState(() => _filterKind = 'kuliah'),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Pribadi'),
                          selected: _filterKind == 'pribadi',
                          onSelected: (_) => setState(() => _filterKind = 'pribadi'),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: filtered.isEmpty
                        ? const Center(child: Text('Belum ada tugas yang cocok.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final task = filtered[index];
                              final isDone = task['status'] == 'done';
                              final projName = (task['projects'] as Map<String, dynamic>?)?['name'] as String?;
                              final checklistItems = task['task_checklist_items'] as List?;
                              final checklistCount = checklistItems?.length ?? 0;
                              final doneCount = checklistItems?.where((c) => c['done'] == true).length ?? 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: IconButton(
                                    icon: Icon(
                                      isDone ? Icons.check_circle : Icons.circle_outlined,
                                      color: isDone ? Colors.green : Colors.grey,
                                    ),
                                    onPressed: () => _toggleTask(task),
                                  ),
                                  title: Text(
                                    task['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (projName != null) projName,
                                      if (checklistCount > 0) 'Checklist: $doneCount/$checklistCount',
                                    ].join(' • '),
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
