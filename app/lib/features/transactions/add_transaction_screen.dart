import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _supabase = Supabase.instance.client;

  String _type = 'expense'; // expense, income, transfer
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedCategoryId;
  String _selectedSource = 'personal';
  String? _workspaceId;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final memberData = await _supabase
          .from('workspace_members')
          .select('workspace_id')
          .limit(1)
          .single();

      _workspaceId = memberData['workspace_id'] as String;

      final accs = await _supabase
          .from('accounts')
          .select('id, name, currency')
          .eq('workspace_id', _workspaceId!)
          .filter('deleted_at', 'is', null)
          .order('sort_order');

      final cats = await _supabase
          .from('categories')
          .select('id, name, type')
          .eq('workspace_id', _workspaceId!)
          .filter('deleted_at', 'is', null)
          .order('sort_order');

      setState(() {
        _accounts = List<Map<String, dynamic>>.from(accs);
        _categories = List<Map<String, dynamic>>.from(cats);
        if (_accounts.isNotEmpty) {
          _selectedAccountId = _accounts.first['id'];
          if (_accounts.length > 1) {
            _selectedToAccountId = _accounts[1]['id'];
          }
        }
        final defaultCat = _categories.where((c) => c['type'] == _type).firstOrNull;
        if (defaultCat != null) {
          _selectedCategoryId = defaultCat['id'];
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading metadata: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0.')),
      );
      return;
    }

    if (_selectedAccountId == null || _workspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih akun terlebih dahulu.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_type == 'transfer') {
        if (_selectedAccountId == _selectedToAccountId) {
          throw 'Akun tujuan harus berbeda dari akun asal.';
        }

        await _supabase.rpc('fn_create_transfer', params: {
          'p_workspace_id': _workspaceId,
          'p_from_account_id': _selectedAccountId,
          'p_to_account_id': _selectedToAccountId,
          'p_amount_out': amount,
          'p_note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        });
      } else {
        if (_selectedCategoryId == null) {
          throw 'Pilih kategori transaksi.';
        }

        final acc = _accounts.firstWhere((a) => a['id'] == _selectedAccountId);
        final currency = acc['currency'] as String;

        await _supabase.from('transactions').insert({
          'workspace_id': _workspaceId,
          'account_id': _selectedAccountId,
          'category_id': _selectedCategoryId,
          'type': _type,
          'status': 'confirmed',
          'amount': amount,
          'currency': currency,
          'source': _selectedSource,
          'merchant': _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
          'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          'occurred_at': DateTime.now().toIso8601String(),
          'origin': 'manual',
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((c) => c['type'] == _type).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tipe Selector
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                      ButtonSegment(value: 'income', label: Text('Pemasukan')),
                      ButtonSegment(value: 'transfer', label: Text('Transfer')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (val) {
                      setState(() {
                        _type = val.first;
                        final defaultCat = _categories.where((c) => c['type'] == _type).firstOrNull;
                        _selectedCategoryId = defaultCat?['id'];
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Nominal
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Akun Asal
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    decoration: InputDecoration(
                      labelText: _type == 'transfer' ? 'Akun Asal' : 'Akun',
                      border: const OutlineInputBorder(),
                    ),
                    items: _accounts.map((a) {
                      return DropdownMenuItem<String>(
                        value: a['id'],
                        child: Text('${a['name']} (${a['currency']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedAccountId = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_type == 'transfer') ...[
                    // Akun Tujuan
                    DropdownButtonFormField<String>(
                      value: _selectedToAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Akun Tujuan',
                        border: OutlineInputBorder(),
                      ),
                      items: _accounts.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id'],
                          child: Text('${a['name']} (${a['currency']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedToAccountId = val);
                      },
                    ),
                  ] else ...[
                    // Kategori
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: filteredCategories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'],
                          child: Text(c['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sumber Kegiatan
                    DropdownButtonFormField<String>(
                      value: _selectedSource,
                      decoration: const InputDecoration(
                        labelText: 'Sumber Kegiatan',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'personal', child: Text('Personal')),
                        DropdownMenuItem(value: 'intern', child: Text('Intern')),
                        DropdownMenuItem(value: 'freelance', child: Text('Freelance')),
                        DropdownMenuItem(value: 'kuliah', child: Text('Kuliah')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSource = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Merchant
                    TextField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Merchant / Pihak Kedua',
                        hintText: 'Contoh: Indomaret, Warung',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  // Catatan
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitting ? null : _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_submitting ? 'Menyimpan...' : 'Simpan Transaksi'),
                  ),
                ],
              ),
            ),
    );
  }
}
