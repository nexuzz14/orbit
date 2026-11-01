import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('v_account_balances')
          .select('*')
          .order('sort_order');

      setState(() {
        _accounts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddAccountDialog() async {
    final nameController = TextEditingController();
    final initBalanceController = TextEditingController(text: '0');
    String accountType = 'bank';
    bool isLiquid = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Akun'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Akun'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: accountType,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash / Tunai')),
                    DropdownMenuItem(value: 'e_wallet', child: Text('E-Wallet')),
                    DropdownMenuItem(value: 'savings', child: Text('Tabungan')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => accountType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: initBalanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Saldo Awal (Rp)'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Akun Likuid (Siap Pakai)', style: TextStyle(fontSize: 13)),
                  value: isLiquid,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => isLiquid = val ?? true);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final memberData = await _supabase
            .from('workspace_members')
            .select('workspace_id')
            .limit(1)
            .single();

        await _supabase.from('accounts').insert({
          'workspace_id': memberData['workspace_id'],
          'name': nameController.text.trim(),
          'type': accountType,
          'currency': 'IDR',
          'initial_balance': double.tryParse(initBalanceController.text) ?? 0,
          'is_liquid': isLiquid,
        });

        _loadAccounts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menambah akun: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLiquid = _accounts
        .where((a) => (a['is_liquid'] as bool? ?? true) && a['currency'] == 'IDR')
        .fold<double>(0.0, (sum, a) => sum + ((a['balance'] as num?)?.toDouble() ?? 0.0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun & Dompet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Akun',
            onPressed: _showAddAccountDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadAccounts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAccounts,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL SALDO LIKUID (IDR)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(totalLiquid),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Daftar Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._accounts.map((a) {
                    final balance = ((a['balance'] as num?)?.toDouble() ?? 0.0);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          child: Icon(
                            a['type'] == 'cash'
                                ? Icons.payments_outlined
                                : a['type'] == 'savings'
                                    ? Icons.savings_outlined
                                    : Icons.account_balance_outlined,
                            color: Colors.grey[800],
                            size: 20,
                          ),
                        ),
                        title: Text(a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${(a['type'] as String).toUpperCase()} • ${a['currency']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          _currencyFormat.format(balance),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
