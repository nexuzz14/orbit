import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _loading = true;
  String? _workspaceId;

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _profitData = [];
  List<Map<String, dynamic>> _receivables = [];
  List<Map<String, dynamic>> _accounts = [];

  final _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      // Akun
      final accRes = await _supabase
          .from('accounts')
          .select('id, name')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null)
          .order('sort_order');
      _accounts = List<Map<String, dynamic>>.from(accRes);

      // Proyek
      final projRes = await _supabase
          .from('projects')
          .select('*')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);
      _projects = List<Map<String, dynamic>>.from(projRes);

      // Profit per proyek
      final profitRes = await _supabase
          .from('v_project_profit')
          .select('*')
          .eq('workspace_id', wsId);
      _profitData = List<Map<String, dynamic>>.from(profitRes);

      // Piutang
      final recRes = await _supabase
          .from('v_receivables')
          .select('*')
          .eq('workspace_id', wsId)
          .order('due_date', ascending: true);
      _receivables = List<Map<String, dynamic>>.from(recRes);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Dialog Tambah Proyek Baru
  void _showAddProjectDialog() {
    final nameCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final contractCtrl = TextEditingController();
    final feePercentCtrl = TextEditingController(text: '10');
    final stipendAmountCtrl = TextEditingController();
    final stipendDayCtrl = TextEditingController(text: '25');
    final semesterCtrl = TextEditingController(text: '1');
    final courseCodeCtrl = TextEditingController();
    final creditsCtrl = TextEditingController(text: '3');

    String selectedKind = 'freelance';
    String feeMode = 'expense_transaction';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Kegiatan Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Kegiatan *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedKind,
                  decoration: const InputDecoration(labelText: 'Jenis Kegiatan', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'freelance', child: Text('Freelance')),
                    DropdownMenuItem(value: 'intern', child: Text('Magang')),
                    DropdownMenuItem(value: 'kuliah', child: Text('Kuliah')),
                    DropdownMenuItem(value: 'pribadi', child: Text('Pribadi')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedKind = val ?? 'freelance'),
                ),
                const SizedBox(height: 10),

                // Form freelance
                if (selectedKind == 'freelance') ...[
                  TextField(
                    controller: clientCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Klien', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contractCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nilai Kontrak (Rp) *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: feePercentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Potongan Platform (%)', border: OutlineInputBorder()),
                  ),
                ],

                // Form magang
                if (selectedKind == 'intern') ...[
                  TextField(
                    controller: clientCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Instansi', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stipendAmountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Uang Saku per Bulan (Rp)', border: OutlineInputBorder()),
                  ),
                ],

                // Form kuliah
                if (selectedKind == 'kuliah') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: semesterCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: creditsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'SKS', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courseCodeCtrl,
                    decoration: const InputDecoration(labelText: 'Kode MK', border: OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || _workspaceId == null) return;

                final payload = <String, dynamic>{
                  'workspace_id': _workspaceId,
                  'name': name,
                  'kind': selectedKind,
                  'status': 'berjalan',
                };

                if (selectedKind == 'freelance') {
                  final val = double.tryParse(contractCtrl.text);
                  if (val == null || val < 0) return;
                  payload['client_name'] = clientCtrl.text.trim().isEmpty ? null : clientCtrl.text.trim();
                  payload['contract_value'] = val;
                  payload['currency'] = 'IDR';
                  payload['platform_fee_percent'] = double.tryParse(feePercentCtrl.text) ?? 0.0;
                  payload['fee_mode'] = feeMode;
                } else if (selectedKind == 'intern') {
                  payload['client_name'] = clientCtrl.text.trim().isEmpty ? null : clientCtrl.text.trim();
                  if (stipendAmountCtrl.text.isNotEmpty) {
                    payload['stipend_amount'] = double.tryParse(stipendAmountCtrl.text);
                    payload['stipend_day'] = int.tryParse(stipendDayCtrl.text) ?? 25;
                  }
                } else if (selectedKind == 'kuliah') {
                  payload['semester'] = int.tryParse(semesterCtrl.text) ?? 1;
                  payload['course_code'] = courseCodeCtrl.text.trim().isEmpty ? null : courseCodeCtrl.text.trim();
                  payload['credits'] = int.tryParse(creditsCtrl.text) ?? 3;
                }

                Navigator.pop(ctx);
                try {
                  await _supabase.from('projects').insert(payload);
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

  // Dialog Pelunasan Cepat
  void _showMarkPaidDialog(String paymentId, String label, double amount) {
    String? selectedAcc = _accounts.isNotEmpty ? _accounts.first['id'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tandai Lunas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tandai pelunasan termin "$label" sebesar ${_currencyFormatter.format(amount)}?'),
              const SizedBox(height: 12),
              const Text('Akun Penerima:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: selectedAcc,
                items: _accounts
                    .map((acc) => DropdownMenuItem(
                          value: acc['id'] as String,
                          child: Text(acc['name'] as String, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedAcc = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (selectedAcc == null) return;
                Navigator.pop(ctx);
                try {
                  await _supabase.rpc('fn_mark_payment_paid', params: {
                    'p_payment_id': paymentId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyek & Kegiatan', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daftar Kegiatan'),
            Tab(text: 'Piutang & Profit'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Daftar Proyek
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _projects.isEmpty
                      ? const Center(child: Text('Belum ada kegiatan yang terdaftar.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final p = _projects[index];
                            final kind = p['kind'] as String? ?? 'pribadi';
                            final profit = _profitData.firstWhere(
                              (pr) => pr['project_id'] == p['id'],
                              orElse: () => {},
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          p['name'] as String? ?? '',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        Chip(
                                          label: Text(kind.toUpperCase(), style: const TextStyle(fontSize: 9)),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    if (p['client_name'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Pihak: ${p['client_name']}',
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                                      ),
                                    ],
                                    const SizedBox(height: 8),

                                    // Metric ringkas freelance
                                    if (kind == 'freelance' && profit.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Dibayar: ${_currencyFormatter.format((profit['total_paid'] as num?)?.toDouble() ?? 0.0)}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                                            ),
                                            Text(
                                              'Profit: ${_currencyFormatter.format((profit['net_profit'] as num?)?.toDouble() ?? 0.0)}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Tab 2: Piutang & Profit
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Daftar Piutang Jatuh Tempo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_receivables.isEmpty)
                        const Text('Tidak ada piutang aktif yang tertunda.', style: TextStyle(fontSize: 12, color: Colors.grey))
                      else
                        ..._receivables.map((r) {
                          final isOverdue = r['is_overdue'] == true;
                          final amount = (r['remaining_amount'] as num?)?.toDouble() ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isOverdue ? Colors.red.withOpacity(0.05) : null,
                            child: ListTile(
                              title: Text(r['label'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${r['project_name']} • ${_currencyFormatter.format(amount)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () => _showMarkPaidDialog(
                                  r['payment_id'] as String,
                                  r['label'] as String,
                                  amount,
                                ),
                                child: const Text('Lunas', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProjectDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
