import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:intl/intl.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _supabase = Supabase.instance.client;
  final _db = AppDatabase.shared;

  bool _loading = true;
  String _selectedKind = 'all'; // all, intern, freelance, kuliah, pribadi

  List<Map<String, dynamic>> _agendaItems = [];
  List<Map<String, dynamic>> _conflicts = [];
  bool _isHeavyDay = false;
  double _liquidBalance = 0.0;
  int _draftCount = 0;
  List<Map<String, dynamic>> _accounts = [];

  final _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _today = DateTime.now();
  late final String _todayStr = DateFormat('yyyy-MM-dd').format(_today);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // Ambil workspace aktif
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

      // Ambil daftar akun
      final accRes = await _supabase
          .from('accounts')
          .select('id, name')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null)
          .order('sort_order');
      _accounts = List<Map<String, dynamic>>.from(accRes);

      // Panggil fn_agenda
      final kindFilter = _selectedKind == 'all' ? null : _selectedKind;
      final agendaRes = await _supabase.rpc('fn_agenda', params: {
        'p_workspace_id': wsId,
        'p_start_date': _todayStr,
        'p_end_date': _todayStr,
        'p_kind': kindFilter,
      });

      if (agendaRes != null) {
        _agendaItems = List<Map<String, dynamic>>.from(agendaRes);

        // Cache lokal di Drift untuk ketersediaan offline (PRD M10c)
        try {
          for (final item in _agendaItems) {
            await _db.into(_db.localAgendaCache).insertOnConflictUpdate(
              LocalAgendaCacheCompanion.insert(
                id: item['id'] as String,
                workspaceId: wsId,
                itemType: item['item_type'] as String,
                kind: item['kind'] as String,
                title: item['title'] as String,
                status: item['status'] as String,
                cachedDate: _todayStr,
              ),
            );
          }
        } catch (_) {}
      }

      // Panggil fn_detect_conflicts
      final conflictRes = await _supabase.rpc('fn_detect_conflicts', params: {
        'p_workspace_id': wsId,
        'p_start_date': _todayStr,
        'p_end_date': _todayStr,
      });

      if (conflictRes != null) {
        final rawList = List<Map<String, dynamic>>.from(conflictRes);
        _conflicts = rawList.where((c) => c['event1_id'] != null).toList();
        _isHeavyDay = rawList.any((c) => c['is_heavy_day'] == true);
      }

      // Ambil saldo likuid
      final balRes = await _supabase
          .from('v_account_balances')
          .select('balance, is_liquid')
          .eq('workspace_id', wsId);

      double total = 0.0;
      for (final b in balRes) {
        if (b['is_liquid'] == true) {
          total += (b['balance'] as num?)?.toDouble() ?? 0.0;
        }
      }
      _liquidBalance = total;

      // Hitung draft di Inbox
      final draftRes = await _supabase
          .from('transactions')
          .select('id')
          .eq('workspace_id', wsId)
          .eq('status', 'draft')
          .filter('deleted_at', 'is', null);

      _draftCount = (draftRes as List).length;
    } catch (_) {
      // Jika offline, baca dari Drift LocalAgendaCache
      try {
        final cached = await (_db.select(_db.localAgendaCache)
              ..where((tbl) => tbl.cachedDate.equals(_todayStr)))
            .get();

        _agendaItems = cached.map((c) => {
          'id': c.id,
          'item_type': c.itemType,
          'kind': c.kind,
          'title': c.title,
          'status': c.status,
          'is_overdue': c.isOverdue,
          'starts_at': c.startsAt?.toIso8601String(),
          'ends_at': c.endsAt?.toIso8601String(),
          'all_day': c.allDay,
          'location': c.location,
          'checklist_total': c.checklistTotal,
          'checklist_done': c.checklistDone,
          'project_name': c.projectName,
        }).toList();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Toggle status tugas selesai via fn_complete_task
  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final taskId = task['id'] as String;
    final wasDone = task['status'] == 'done';

    // Optimistic UI update
    setState(() {
      task['status'] = wasDone ? 'todo' : 'done';
    });

    try {
      final res = await _supabase.rpc('fn_complete_task', params: {
        'p_task_id': taskId,
      });

      // Jika tugas selesai memiliki milestone payment, tawarkan pelunasan
      if (!wasDone && res != null && res['milestone_payment_id'] != null) {
        final milestoneId = res['milestone_payment_id'] as String;
        _showMilestoneConfirmDialog(milestoneId, task['title'] as String);
      }
    } catch (_) {
      _loadData();
    }
  }

  // Dialog konfirmasi pelunasan termin
  void _showMilestoneConfirmDialog(String milestoneId, String taskTitle) {
    String? selectedAccount = _accounts.isNotEmpty ? _accounts.first['id'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pelunasan Milestone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tugas "$taskTitle" terhubung dengan pembayaran termin freelance. Tandai lunas sekarang?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text('Akun Penerima:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedAccount,
                items: _accounts
                    .map((acc) => DropdownMenuItem(
                          value: acc['id'] as String,
                          child: Text(acc['name'] as String, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedAccount = val),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedAccount == null) return;
                Navigator.pop(ctx);
                try {
                  await _supabase.rpc('fn_mark_payment_paid', params: {
                    'p_payment_id': milestoneId,
                    'p_account_id': selectedAccount,
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

  Color _getKindColor(String kind) {
    switch (kind) {
      case 'intern':
        return Colors.blue;
      case 'freelance':
        return Colors.purple;
      case 'kuliah':
        return Colors.amber;
      default:
        return Colors.teal;
    }
  }

  String _getKindLabel(String kind) {
    switch (kind) {
      case 'intern':
        return 'Magang';
      case 'freelance':
        return 'Freelance';
      case 'kuliah':
        return 'Kuliah';
      default:
        return 'Pribadi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdueTasks = _agendaItems.where((i) => i['item_type'] == 'task' && i['is_overdue'] == true).toList();
    final events = _agendaItems.where((i) => i['item_type'] == 'event').toList();
    final todayTasks = _agendaItems.where((i) => i['item_type'] == 'task' && i['is_overdue'] != true).toList();

    final dateFormatted = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_today);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(dateFormatted, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Semua'),
                          selected: _selectedKind == 'all',
                          onSelected: (_) {
                            setState(() => _selectedKind = 'all');
                            _loadData();
                          },
                        ),
                        const SizedBox(width: 6),
                        ...['intern', 'freelance', 'kuliah', 'pribadi'].map((k) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(_getKindLabel(k)),
                                selected: _selectedKind == k,
                                onSelected: (_) {
                                  setState(() => _selectedKind = k);
                                  _loadData();
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Peringatan Benturan & Hari Padat
                  if (_conflicts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Benturan Jadwal: ${_conflicts.first['event1_title']} tumpang tindih waktu.',
                              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_isHeavyDay)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hari Padat: Durasi jadwal kegiatan mencapai >= 8 jam.',
                              style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Ringkasan Uang
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saldo Kas & Bank', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                _currencyFormatter.format(_liquidBalance),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Draft Inbox', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                '$_draftCount transaksi',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tugas Terlambat (Overdue) - Di Atas
                  if (overdueTasks.isNotEmpty) ...[
                    const Text('Tugas Terlambat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 6),
                    ...overdueTasks.map((t) => _buildTaskTile(t, isOverdue: true)),
                    const SizedBox(height: 16),
                  ],

                  // Jadwal Hari Ini
                  const Text('Jadwal Kegiatan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (events.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Tidak ada jadwal untuk hari ini.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    )
                  else
                    ...events.map(_buildEventTile),
                  const SizedBox(height: 16),

                  // Tugas Hari Ini
                  const Text('Tugas Hari Ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (todayTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Semua tugas hari ini telah rampung.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    )
                  else
                    ...todayTasks.map((t) => _buildTaskTile(t, isOverdue: false)),
                ],
              ),
            ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> evt) {
    final startsAtStr = evt['starts_at'] as String?;
    final timeStr = startsAtStr != null
        ? DateFormat('HH:mm').format(DateTime.parse(startsAtStr).toLocal())
        : '-';

    final kind = evt['kind'] as String? ?? 'pribadi';
    final color = _getKindColor(kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getKindLabel(kind),
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evt['title'] as String? ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      evt['all_day'] == true ? 'Seharian' : timeStr,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                    ),
                    if (evt['location'] != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on_outlined, size: 12, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          evt['location'] as String,
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task, {required bool isOverdue}) {
    final isDone = task['status'] == 'done';
    final kind = task['kind'] as String? ?? 'pribadi';
    final color = _getKindColor(kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.05) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isDone ? Icons.check_circle : Icons.circle_outlined,
              color: isDone ? Colors.green : (isOverdue ? Colors.red : Colors.grey),
              size: 20,
            ),
            onPressed: () => _toggleTask(task),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getKindLabel(kind),
                        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (task['project_name'] != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        task['project_name'] as String,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
