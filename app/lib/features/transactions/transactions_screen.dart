import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/accounts/accounts_screen.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/planning/planning_screen.dart';

class _DailyGroup {
  final DateTime date;
  final String dateKey;
  double subtotalNet = 0;
  final List<LocalTransaction> items;

  _DailyGroup({
    required this.date,
    required this.dateKey,
    required this.items,
  });
}

class TransactionsScreen extends StatefulWidget {
  final bool forceLoading;
  final String? forceError;

  const TransactionsScreen({
    super.key,
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  AppDatabase get _db => AppDatabase.shared;

  String _activeSubTab = 'transaksi'; // transaksi | akun | ringkasan
  bool _loading = true;
  String? _errorMessage;

  List<LocalTransaction> _transactions = [];
  Map<String, String> _accountNames = {};
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    if (widget.forceLoading) return;
    setState(() {
      _loading = true;
      _errorMessage = widget.forceError;
    });

    if (widget.forceError != null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final accs = await _db.select(_db.localAccounts).get();
      final txs = await (_db.select(_db.localTransactions)
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.occurredAt,
                    mode: OrderingMode.desc,
                  ),
            ]))
          .get();

      final accMap = <String, String>{};
      for (final a in accs) {
        accMap[a.id] = a.name;
      }

      final activeTxs = txs.where((t) => t.deletedAt == null).toList();
      final drafts = activeTxs.where((t) => t.status == 'draft').length;

      if (mounted) {
        setState(() {
          _accountNames = accMap;
          _transactions = activeTxs;
          _draftCount = drafts;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat daftar transaksi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteTransaction(String id) async {
    await (_db.update(_db.localTransactions)..where((t) => t.id.equals(id)))
        .write(LocalTransactionsCompanion(deletedAt: Value(DateTime.now())));
    await _loadTransactions();
  }

  List<_DailyGroup> _groupTransactionsByDay() {
    final map = <String, _DailyGroup>{};
    for (final tx in _transactions) {
      final d = tx.occurredAt;
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final group = map.putIfAbsent(
        key,
        () => _DailyGroup(
          date: DateTime(d.year, d.month, d.day),
          dateKey: key,
          items: [],
        ),
      );
      group.items.add(tx);
      if (tx.type == 'income') {
        group.subtotalNet += tx.amount;
      } else if (tx.type == 'expense') {
        group.subtotalNet -= tx.amount;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _groupTransactionsByDay();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Uang',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {
              TransactionFormSheet.show(context, onSaved: _loadTransactions);
            },
            tooltip: 'Tambah Transaksi',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _loadTransactions,
            tooltip: 'Segarkan daftar transaksi',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space3,
            AppTokens.space4,
            96,
          ),
          children: [
            // SegmentedButton Atas: Transaksi | Akun | Ringkasan
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'transaksi', label: Text('Transaksi')),
                ButtonSegment(value: 'akun', label: Text('Akun')),
                ButtonSegment(value: 'ringkasan', label: Text('Ringkasan')),
              ],
              selected: {_activeSubTab},
              onSelectionChanged: (sel) {
                final next = sel.first;
                if (next == 'akun') {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(builder: (_) => const AccountsScreen()),
                      )
                      .then((_) => _loadTransactions());
                } else {
                  setState(() => _activeSubTab = next);
                }
              },
            ),
            const SizedBox(height: AppTokens.space3),

            // Baris Pintasan di Bawahnya: Inbox (Lencana Draft), Anggaran, Tagihan, Target
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildShortcutButton(
                    context,
                    icon: Icons.inbox_outlined,
                    label: 'Inbox',
                    badgeCount: _draftCount,
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const InboxScreen(),
                            ),
                          )
                          .then((_) => _loadTransactions());
                    },
                  ),
                  const SizedBox(width: AppTokens.space2),
                  _buildShortcutButton(
                    context,
                    icon: Icons.pie_chart_outline,
                    label: 'Anggaran',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlanningScreen(
                            initialTab: 'anggaran',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppTokens.space2),
                  _buildShortcutButton(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Tagihan',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlanningScreen(
                            initialTab: 'tagihan',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppTokens.space2),
                  _buildShortcutButton(
                    context,
                    icon: Icons.flag_outlined,
                    label: 'Target',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlanningScreen(
                            initialTab: 'target',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),

            if (_errorMessage != null) ...[
              OrbitErrorState(
                message: _errorMessage!,
                onRetry: _loadTransactions,
              ),
              const SizedBox(height: AppTokens.space4),
            ],

            if (_loading) ...[
              const OrbitSkeleton(height: 88),
              const SizedBox(height: AppTokens.space3),
              const OrbitSkeleton(height: 88),
              const SizedBox(height: AppTokens.space3),
              const OrbitSkeleton(height: 88),
            ] else if (_activeSubTab == 'ringkasan') ...[
              _buildSummaryView(context),
            ] else if (groups.isEmpty) ...[
              OrbitEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada transaksi tercatat',
                description:
                    'Catat pemasukan atau pengeluaran pertama Anda dengan cepat.',
                actionLabel: 'Tambah Transaksi',
                onAction: () {
                  TransactionFormSheet.show(context, onSaved: _loadTransactions);
                },
              ),
            ] else ...[
              for (final group in groups) ...[
                OrbitCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Tanggal & Subtotal Harian
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space4,
                          vertical: AppTokens.space2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSubtle
                              : AppColors.lightSubtle,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTokens.radiusLg),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                formatDateIndoShort(group.date),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTokens.space2),
                            Flexible(
                              child: Text(
                                'Subtotal: ${group.subtotalNet >= 0 ? '+' : '-'}${formatRupiah(group.subtotalNet.abs())}',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: group.subtotalNet >= 0
                                      ? AppColors.incomeColor(context)
                                      : AppColors.expenseColor(context),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (int i = 0; i < group.items.length; i++) ...[
                        const Divider(height: 1),
                        _buildTransactionRow(context, group.items[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space3,
          vertical: AppTokens.space2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AppTokens.space2),
          Text(label, style: const TextStyle(fontSize: 12)),
          if (badgeCount > 0) ...[
            const SizedBox(width: AppTokens.space2),
            OrbitStatusBadge(
              label: '$badgeCount',
              variant: OrbitBadgeVariant.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, LocalTransaction tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = tx.type == 'expense' ||
        (tx.type == 'transfer' && tx.transferDirection == 'out');
    final isDraft = tx.status == 'draft';
    final accountName = _accountNames[tx.accountId] ?? 'BCA Utama';
    final title = tx.type == 'transfer'
        ? 'Transfer Antar Akun'
        : (tx.merchant ?? tx.categoryId ?? 'Transaksi');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space4,
        vertical: AppTokens.space3,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isExpense
                  ? (isDark
                      ? AppColors.expenseSubtleDark
                      : AppColors.expenseSubtleLight)
                  : (isDark
                      ? AppColors.incomeSubtleDark
                      : AppColors.incomeSubtleLight),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              tx.type == 'transfer'
                  ? Icons.swap_horiz
                  : isExpense
                      ? Icons.arrow_outward
                      : Icons.arrow_downward,
              size: 18,
              color: isExpense
                  ? AppColors.expenseColor(context)
                  : AppColors.incomeColor(context),
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.space1),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      accountName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (tx.source != null && tx.source!.isNotEmpty)
                      OrbitKindBadge(kind: tx.source!),
                    if (isDraft)
                      const OrbitStatusBadge(
                        label: 'Draft',
                        variant: OrbitBadgeVariant.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          // Nominal Rata Kanan dengan Angka Tabular
          Text(
            '${isExpense ? '-' : '+'}${formatRupiah(tx.amount, currency: tx.currency)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isExpense
                  ? AppColors.expenseColor(context)
                  : AppColors.incomeColor(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            onPressed: () => _deleteTransaction(tx.id),
            tooltip: 'Hapus transaksi',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView(BuildContext context) {
    double totalIn = 0;
    double totalOut = 0;
    for (final tx in _transactions) {
      if (tx.status == 'draft') continue;
      if (tx.type == 'income') totalIn += tx.amount;
      if (tx.type == 'expense') totalOut += tx.amount;
    }

    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ringkasan Arus Kas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pemasukan'),
              Text(
                '+${formatRupiah(totalIn)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.incomeColor(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pengeluaran'),
              Text(
                '-${formatRupiah(totalOut)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.expenseColor(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Divider(height: AppTokens.space6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selisih Bersih',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${(totalIn - totalOut) >= 0 ? '+' : '-'}${formatRupiah((totalIn - totalOut).abs())}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
