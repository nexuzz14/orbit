import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  bool _showDeleted = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      var filterBuilder = _supabase
          .from('transactions')
          .select('*, accounts!inner(name), categories(name)')
          .eq('status', 'confirmed');

      if (!_showDeleted) {
        filterBuilder = filterBuilder.filter('deleted_at', 'is', null);
      }

      final data = await filterBuilder.order('occurred_at', ascending: false);
      setState(() {
        _transactions = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteTransaction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Hapus transaksi ini? Dapat dipulihkan dalam 30 hari.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.rpc('fn_delete_transaction', params: {'p_transaction_id': id});
      _loadTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  Future<void> _restoreTransaction(String id) async {
    try {
      await _supabase.rpc('fn_restore_transaction', params: {'p_transaction_id': id});
      _loadTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulihkan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: Icon(_showDeleted ? Icons.delete : Icons.delete_outline),
            tooltip: _showDeleted ? 'Sembunyikan Terhapus' : 'Tampilkan Terhapus',
            onPressed: () {
              setState(() {
                _showDeleted = !_showDeleted;
              });
              _loadTransactions();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(
                  child: Text('Tidak ada transaksi.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadTransactions,
                  child: ListView.separated(
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _transactions[index];
                      final isExpense = item['type'] == 'expense' ||
                          (item['type'] == 'transfer' && item['transfer_direction'] == 'out');
                      final isDeleted = item['deleted_at'] != null;
                      final amount = (item['amount'] as num).toDouble();
                      final source = item['source'] as String?;
                      final categoryName = item['categories']?['name'] as String?;
                      final accountName = item['accounts']?['name'] as String? ?? 'Akun';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item['type'] == 'transfer'
                              ? Colors.grey.withOpacity(0.2)
                              : isExpense
                                  ? AppColors.expense.withOpacity(0.1)
                                  : AppColors.income.withOpacity(0.1),
                          child: Icon(
                            item['type'] == 'transfer'
                                ? Icons.swap_horiz
                                : isExpense
                                    ? Icons.arrow_outward
                                    : Icons.arrow_downward,
                            color: item['type'] == 'transfer'
                                ? Colors.grey[800]
                                : isExpense
                                    ? AppColors.expense
                                    : AppColors.income,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['type'] == 'transfer'
                                    ? 'Transfer (${item['transfer_direction'] == 'out' ? 'Keluar' : 'Masuk'})'
                                    : item['merchant'] ?? categoryName ?? 'Transaksi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (source != null)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.getKindColor(source).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppColors.getKindLabel(source),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getKindColor(source),
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
                                color: isExpense ? AppColors.expense : AppColors.income,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (isDeleted)
                              IconButton(
                                icon: const Icon(Icons.restore, size: 20),
                                tooltip: 'Pulihkan',
                                onPressed: () => _restoreTransaction(item['id']),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                tooltip: 'Hapus',
                                onPressed: () => _deleteTransaction(item['id']),
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
