import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _goals = [];

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }





      // Ambil data anggaran dari view
      final budgetData = await _supabase
          .from('v_budget_progress')
          .select('*')
          .order('category_name');

      // Ambil tagihan rutin
      final billsData = await _supabase
          .from('recurring_bills')
          .select('*, categories(name), accounts(name)')
          .filter('deleted_at', 'is', null)
          .order('schedule_value');

      // Ambil target tabungan
      final goalsData = await _supabase
          .from('savings_goals')
          .select('*')
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      setState(() {
        _budgets = List<Map<String, dynamic>>.from(budgetData);
        _bills = List<Map<String, dynamic>>.from(billsData);
        _goals = List<Map<String, dynamic>>.from(goalsData);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading planning data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _generateDueBillDrafts() async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await _supabase.rpc('fn_generate_due_bill_drafts', params: {
        'p_target_date': todayStr,
      });

      final count = res is int ? res : 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '$count draft tagihan berhasil dikirim ke Inbox.'
                  : 'Tidak ada tagihan yang jatuh tempo hari ini.',
            ),
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses tagihan: $e')),
        );
      }
    }
  }

  Future<void> _showManualDepositDialog(Map<String, dynamic> goal) async {
    final amountController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Setor ke ${goal['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terkumpul: ${_currencyFormat.format(goal['current_amount'])} / ${_currencyFormat.format(goal['target_amount'])}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nominal Setoran (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Setor'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final addAmount = double.tryParse(amountController.text.trim()) ?? 0;
      if (addAmount > 0) {
        try {
          final current = (goal['current_amount'] as num?)?.toDouble() ?? 0;
          final target = (goal['target_amount'] as num?)?.toDouble() ?? 0;
          final newTotal = current + addAmount;
          final isCompleted = newTotal >= target;

          await _supabase
              .from('savings_goals')
              .update({
                'current_amount': newTotal,
                'is_completed': isCompleted,
              })
              .eq('id', goal['id']);

          _loadAllData();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal menambah setoran: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perencanaan Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.pie_chart_outline),
              text: 'Anggaran (${_budgets.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_outlined),
              text: 'Tagihan (${_bills.length})',
            ),
            Tab(
              icon: const Icon(Icons.savings_outlined),
              text: 'Tabungan (${_goals.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBudgetsTab(),
                _buildBillsTab(),
                _buildGoalsTab(),
              ],
            ),
    );
  }

  // Tab 1: Anggaran
  Widget _buildBudgetsTab() {
    if (_budgets.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada anggaran bulanan yang ditentukan.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _budgets.length,
      itemBuilder: (context, index) {
        final b = _budgets[index];
        final spent = (b['spent_amount'] as num?)?.toDouble() ?? 0;
        final effective = (b['effective_budget_amount'] as num?)?.toDouble() ?? 0;
        final remaining = (b['remaining_amount'] as num?)?.toDouble() ?? 0;
        final pct = (b['percentage_spent'] as num?)?.toDouble() ?? 0;
        final isOver = b['is_over_budget'] == true;
        final isWarn = b['is_warning'] == true && !isOver;
        final hasRollover = b['rollover'] == true;

        Color barColor = AppColors.primary;
        String statusLabel = 'Aman';
        Color statusColor = Colors.green;

        if (isOver) {
          barColor = AppColors.expense;
          statusLabel = 'Melebihi Anggaran';
          statusColor = AppColors.expense;
        } else if (isWarn) {
          barColor = Colors.amber;
          statusLabel = 'Waspada 80%';
          statusColor = Colors.amber.shade700;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      b['category_name'] ?? 'Kategori',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        if (hasRollover)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.withAlpha(70)),
                            ),
                            child: const Text(
                              'Rollover',
                              style: TextStyle(fontSize: 10, color: Colors.blue),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withAlpha(70)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terpakai: ${_currencyFormat.format(spent)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOver ? AppColors.expense : null,
                      ),
                    ),
                    Text(
                      'Batas: ${_currencyFormat.format(effective)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(1)}% terpakai',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      'Sisa: ${_currencyFormat.format(remaining)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: remaining < 0 ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tab 2: Tagihan Rutin
  Widget _buildBillsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pengeluaran Terjadwal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                onPressed: _generateDueBillDrafts,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Proses Hari Ini'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _bills.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada tagihan rutin terdaftar.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final amount = (bill['amount'] as num?)?.toDouble() ?? 0;
                    final scheduleType = bill['schedule_type'] as String? ?? 'monthly';
                    final scheduleVal = bill['schedule_value'] ?? 1;
                    final catName = bill['categories']?['name'] ?? 'Kategori';
                    final accName = bill['accounts']?['name'] ?? 'Rekening';
                    final active = bill['active'] == true;

                    String freqText = scheduleType == 'monthly'
                        ? 'Tgl $scheduleVal setiap bulan'
                        : scheduleType == 'weekly'
                            ? 'Hari ke-$scheduleVal mingguan'
                            : 'Tahunan';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          bill['name'] ?? 'Tagihan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: active ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '$freqText · $catName ($accName)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          _currencyFormat.format(amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.expense,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Tab 3: Target Tabungan
  Widget _buildGoalsTab() {
    if (_goals.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada target tabungan yang dibuat.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final g = _goals[index];
        final current = (g['current_amount'] as num?)?.toDouble() ?? 0;
        final target = (g['target_amount'] as num?)?.toDouble() ?? 0;
        final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
        final isCompleted = g['is_completed'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      g['name'] ?? 'Target Tabungan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.income.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.income.withAlpha(70),
                          ),
                        ),
                        child: const Text(
                          'Tercapai',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.income,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currencyFormat.format(current)} / ${_currencyFormat.format(target)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? AppColors.income : AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _showManualDepositDialog(g),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Setor Manual'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
