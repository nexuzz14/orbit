import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _workspaceId;
  final DateTime _currentDate = DateTime.now();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _conflicts = [];
  List<Map<String, dynamic>> _projects = [];

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

      final startStr = DateFormat('yyyy-MM-dd').format(_currentDate.subtract(const Duration(days: 1)));
      final endStr = DateFormat('yyyy-MM-dd').format(_currentDate.add(const Duration(days: 14)));

      final projRes = await _supabase
          .from('projects')
          .select('id, name')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null);
      _projects = List<Map<String, dynamic>>.from(projRes);

      final res = await _supabase.rpc('fn_agenda', params: {
        'p_workspace_id': wsId,
        'p_start_date': startStr,
        'p_end_date': endStr,
      });

      if (res != null) {
        final allItems = List<Map<String, dynamic>>.from(res);
        _events = allItems.where((i) => i['item_type'] == 'event').toList();
      }

      final confRes = await _supabase.rpc('fn_detect_conflicts', params: {
        'p_workspace_id': wsId,
        'p_start_date': startStr,
        'p_end_date': endStr,
      });

      if (confRes != null) {
        final raw = List<Map<String, dynamic>>.from(confRes);
        _conflicts = raw.where((c) => c['event1_id'] != null).toList();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddEventDialog() {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedKind = 'kuliah';
    String? selectedProject;
    DateTime eventDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Jadwal Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Jadwal *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedKind,
                  decoration: const InputDecoration(labelText: 'Jenis Kegiatan', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'kuliah', child: Text('Kuliah')),
                    DropdownMenuItem(value: 'intern', child: Text('Magang')),
                    DropdownMenuItem(value: 'freelance', child: Text('Freelance')),
                    DropdownMenuItem(value: 'pribadi', child: Text('Pribadi')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedKind = val ?? 'kuliah'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Lokasi / Ruang', border: OutlineInputBorder()),
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
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Tanggal: ${DateFormat('d MMMM yyyy').format(eventDate)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: eventDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => eventDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty || _workspaceId == null) return;
                Navigator.pop(ctx);

                final dateStr = DateFormat('yyyy-MM-dd').format(eventDate);
                final startsAt = DateTime.parse('${dateStr}T08:00:00+07:00').toUtc().toIso8601String();
                final endsAt = DateTime.parse('${dateStr}T10:00:00+07:00').toUtc().toIso8601String();

                try {
                  await _supabase.from('events').insert({
                    'workspace_id': _workspaceId,
                    'title': title,
                    'kind': selectedKind,
                    'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                    'starts_at': startsAt,
                    'ends_at': endsAt,
                    'project_id': selectedProject,
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

  // Pengecualian jadwal berulang (skip)
  Future<void> _skipRecurringEvent(Map<String, dynamic> evt) async {
    final eventId = evt['event_id'] as String?;
    final startsAtStr = evt['starts_at'] as String?;
    if (eventId == null || startsAtStr == null) return;

    final origDate = startsAtStr.split('T')[0];

    try {
      await _supabase.from('event_exceptions').insert({
        'event_id': eventId,
        'original_date': origDate,
        'action': 'skip',
      });
      _loadData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Kegiatan', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  if (_conflicts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_conflicts.length} benturan waktu terdeteksi pada jadwal Anda.',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),

                  if (_events.isEmpty)
                    const Center(child: Text('Tidak ada jadwal kegiatan.'))
                  else
                    ..._events.map((evt) {
                      final startsAtStr = evt['starts_at'] as String?;
                      final timeStr = startsAtStr != null
                          ? DateFormat('EEEE, d MMM • HH:mm', 'id_ID').format(DateTime.parse(startsAtStr).toLocal())
                          : '-';

                      final isRecurring = evt['is_recurring'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            evt['title'] as String? ?? '',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              timeStr,
                              if (evt['location'] != null) evt['location'] as String,
                              if (isRecurring) 'Berulang',
                            ].join(' • '),
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                          ),
                          trailing: isRecurring
                              ? IconButton(
                                  icon: const Icon(Icons.event_busy, size: 18),
                                  tooltip: 'Lewati kejadian ini',
                                  onPressed: () => _skipRecurringEvent(evt),
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
