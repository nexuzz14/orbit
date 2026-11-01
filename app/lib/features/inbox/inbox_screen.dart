import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final memberData = await _supabase
          .from('workspace_members')
          .select('workspace_id')
          .limit(1)
          .single();

      final wsId = memberData['workspace_id'] as String;

      final draftData = await _supabase
          .from('transactions')
          .select('*, accounts!inner(name), categories(name)')
          .eq('workspace_id', wsId)
          .eq('status', 'draft')
          .filter('deleted_at', 'is', null)
          .order('occurred_at', ascending: false);

      final catData = await _supabase
          .from('categories')
          .select('id, name, type')
          .eq('workspace_id', wsId)
          .filter('deleted_at', 'is', null);

      setState(() {
        _drafts = List<Map<String, dynamic>>.from(draftData);
        _categories = List<Map<String, dynamic>>.from(catData);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading inbox drafts: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmDraft(Map<String, dynamic> draft) async {
    final catId = draft['category_id'] as String?;
    final source = draft['source'] as String?;

    if (catId == null || source == null) {
      _showCompleteDialog(draft);
      return;
    }

    try {
      await _supabase.rpc('fn_confirm_draft', params: {
        'p_transaction_id': draft['id'],
        'p_category_id': catId,
        'p_source': source,
      });
      _loadDrafts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal konfirmasi: $e')),
        );
      }
    }
  }

  Future<void> _showCompleteDialog(Map<String, dynamic> draft) async {
    String? selectedCat = draft['category_id'];
    String selectedSource = draft['source'] ?? (draft['type'] == 'expense' ? 'personal' : 'intern');
    final availableCats = _categories.where((c) => c['type'] == draft['type']).toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lengkapi Draft'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCat,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: availableCats.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text(c['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() => selectedCat = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSource,
                decoration: const InputDecoration(labelText: 'Sumber Kegiatan'),
                items: const [
                  DropdownMenuItem(value: 'personal', child: Text('Personal')),
                  DropdownMenuItem(value: 'intern', child: Text('Intern')),
                  DropdownMenuItem(value: 'freelance', child: Text('Freelance')),
                  DropdownMenuItem(value: 'kuliah', child: Text('Kuliah')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedSource = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedCat != null) {
      try {
        await _supabase.rpc('fn_confirm_draft', params: {
          'p_transaction_id': draft['id'],
          'p_category_id': selectedCat,
          'p_source': selectedSource,
        });
        _loadDrafts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal konfirmasi: $e')),
          );
        }
      }
    }
  }

  Future<void> _rejectDraft(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Draft'),
        content: const Text('Tolak dan hapus draft transaksi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.rpc('fn_delete_transaction', params: {'p_transaction_id': id});
      _loadDrafts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox Draft'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrafts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Kotak Masuk Bersih', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Tidak ada draft menunggu konfirmasi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDrafts,
                  child: ListView.separated(
                    itemCount: _drafts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _drafts[index];
                      final isExpense = item['type'] == 'expense';
                      final amount = ((item['amount'] as num?)?.toDouble() ?? 0.0);
                      final draftState = item['draft_state'] as String? ?? 'baru';
                      final accountName = item['accounts']?['name'] as String? ?? 'Akun';

                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['merchant'] ?? item['product_name'] ?? 'Draft Transaksi',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: draftState == 'baru'
                                    ? Colors.blue.withOpacity(0.15)
                                    : draftState == 'perlu_dilengkapi'
                                        ? Colors.orange.withOpacity(0.15)
                                        : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                draftState.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: draftState == 'baru'
                                      ? Colors.blue[800]
                                      : draftState == 'perlu_dilengkapi'
                                          ? Colors.orange[800]
                                          : Colors.red[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '$accountName • ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(item['occurred_at']))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isExpense ? '-' : '+'}${_currencyFormat.format(amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isExpense ? Colors.red : Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              tooltip: 'Konfirmasi',
                              onPressed: () => _confirmDraft(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Tolak',
                              onPressed: () => _rejectDraft(item['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
