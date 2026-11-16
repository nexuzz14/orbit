import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/finance_csv_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/accounts/accounts_screen.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/planning/planning_screen.dart';
import 'package:orbit_app/features/transactions/widgets/finance_summary_charts.dart';
import 'package:orbit_app/features/transactions/widgets/transaction_row_card.dart';
import 'package:uuid/uuid.dart';

class TransactionsScreen extends StatefulWidget {
  final bool embedded;
  final bool forceLoading;
  final bool forceError;
  final String initialSubTab;

  const TransactionsScreen({
    super.key,
    this.embedded = false,
    this.forceLoading = false,
    this.forceError = false,
    this.initialSubTab = 'transaksi',
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late String _subTab;
  bool _loading = true;
  String? _errorMessage;

  List<LocalTransaction> _transactions = const [];
  List<LocalAccount> _accounts = const [];
  List<LocalProject> _projects = const [];
  Map<String, String> _accountNames = const {};
  Map<String, String> _categoryNames = const {};
  Map<String, String> _projectNames = const {};

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialSubTab;
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError) {
      _loading = false;
      _errorMessage = 'Gagal memuat data transaksi lokal.';
    } else {
      _loadData();
    }
  }

  Future<void> _loadData({bool pull = false}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    if (pull) {
      await SyncService.instance.pullAllFromSupabase();
    }

    try {
      final db = AppDatabase.shared;
      final txs =
          await (db.select(db.localTransactions)
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => drift.OrderingTerm.desc(t.occurredAt)]))
              .get();

      final accounts = await (db.select(
        db.localAccounts,
      )..where((a) => a.archived.equals(false))).get();
      final categories = await (db.select(
        db.localCategories,
      )..where((c) => c.archived.equals(false))).get();
      final projects = await (db.select(
        db.localProjects,
      )..where((p) => p.deletedAt.isNull())).get();

      if (!mounted) return;
      setState(() {
        _transactions = txs;
        _accounts = accounts;
        _projects = projects;
        _accountNames = {for (final a in accounts) a.id: a.name};
        _categoryNames = {for (final c in categories) c.id: c.name};
        _projectNames = {for (final p in projects) p.id: p.name};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat transaksi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasShell = OrbitShellScope.maybeOf(context) != null;

    final content = Column(
      children: [
        _buildSubHeader(context),
        Expanded(child: _buildBody(context)),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.canvasColor(context),
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvasColor(context),
      appBar: AppBar(
        leading: hasShell ? const OrbitShellMenuButton() : null,
        title: const Text('Keuangan'),
        actions: [
          const OrbitPrivacyToggleButton(),
          if (hasShell) const OrbitShellSearchButton(),
          IconButton(
            tooltip: 'Catat Transaksi',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            onPressed: _openAddTransactionSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildSubHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space4,
        AppTokens.space3,
        AppTokens.space4,
        AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrbitViewSwitcher(
            activeViewMode: _subTab,
            onChanged: (mode) => setState(() => _subTab = mode),
            options: const [
              OrbitViewOption(
                id: 'transaksi',
                label: 'Transaksi',
                icon: Icons.receipt_long_outlined,
              ),
              OrbitViewOption(
                id: 'akun',
                label: 'Akun',
                icon: Icons.account_balance_wallet_outlined,
              ),
              OrbitViewOption(
                id: 'ringkasan',
                label: 'Ringkasan',
                icon: Icons.bar_chart_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FinanceActionChip(
                  icon: Icons.upload_file_outlined,
                  label: 'Impor CSV Mutasi',
                  onTap: _showImportCsvSheet,
                ),
                const SizedBox(width: AppTokens.space2),
                _FinanceActionChip(
                  icon: Icons.download_outlined,
                  label: 'Ekspor CSV / PDF',
                  onTap: _showExportOptionsSheet,
                ),
                const SizedBox(width: AppTokens.space2),
                TransactionShortcutButton(
                  icon: Icons.inbox_outlined,
                  label: 'Inbox',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InboxScreen()),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                TransactionShortcutButton(
                  icon: Icons.pie_chart_outline,
                  label: 'Anggaran',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanningScreen(initialTab: 'anggaran'),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                TransactionShortcutButton(
                  icon: Icons.receipt_outlined,
                  label: 'Tagihan',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanningScreen(initialTab: 'tagihan'),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                TransactionShortcutButton(
                  icon: Icons.savings_outlined,
                  label: 'Target',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanningScreen(initialTab: 'target'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: const [
          OrbitSkeleton(height: 84),
          SizedBox(height: AppTokens.space3),
          OrbitSkeleton(height: 70),
          SizedBox(height: AppTokens.space2),
          OrbitSkeleton(height: 70),
        ],
      );
    }

    if (_errorMessage != null) {
      return OrbitErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    if (_subTab == 'akun') {
      return _buildInlineAccountsTab(context);
    }

    if (_subTab == 'ringkasan') {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space4),
          children: [
            TransactionSummaryCard(transactions: _transactions),
            const SizedBox(height: AppTokens.space3),
            FinanceSummaryCharts(
              transactions: _transactions,
              categoryNames: _categoryNames,
            ),
            const SizedBox(height: AppTokens.space3),
            OrbitCard(
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ekspor & Pelaporan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ekspor buku kas ke CSV atau salin ringkasan siap cetak untuk dokumentasi PDF.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportTransactionsToCsv,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          icon: const Icon(Icons.table_chart_outlined, size: 18),
                          label: const Text('Ekspor CSV'),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyPdfReadySummary,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          icon: const Icon(Icons.copy_all_outlined, size: 18),
                          label: const Text('Salin Laporan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space8),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi tercatat',
              description:
                  'Catat transaksi manual atau impor mutasi bank melalui file CSV.',
              actionLabel: 'Catat Transaksi',
              onAction: _openAddTransactionSheet,
            ),
          ],
        ),
      );
    }

    // Kelompokkan transaksi per tanggal WIB (+7)
    final grouped = <String, List<LocalTransaction>>{};
    for (final tx in _transactions) {
      final wib = tx.occurredAt.toUtc().add(const Duration(hours: 7));
      final key =
          '${wib.year.toString().padLeft(4, '0')}-'
          '${wib.month.toString().padLeft(2, '0')}-'
          '${wib.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    final keys = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTokens.space4),
        itemCount: keys.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space3),
              child: TransactionSummaryCard(transactions: _transactions),
            );
          }
          final key = keys[index - 1];
          final items = grouped[key]!;
          final sampleDate = items.first.occurredAt;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    formatTransactionGroupDate(sampleDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedColor(context),
                    ),
                  ),
                ),
                ...items.map((tx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.space2),
                    child: InkWell(
                      onTap: () => _showTransactionDetailSheet(tx),
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      child: TransactionRowTile(
                        transaction: tx,
                        accountName: _accountNames[tx.accountId] ?? 'Akun',
                        onDelete: () => _deleteTransaction(tx),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteTransaction(LocalTransaction tx) async {
    final now = DateTime.now().toUtc();
    await (AppDatabase.shared.update(AppDatabase.shared.localTransactions)
          ..where((t) => t.id.equals(tx.id)))
        .write(LocalTransactionsCompanion(deletedAt: drift.Value(now)));
    await SyncService.instance.pushRecord(
      tableName: 'transactions',
      recordId: tx.id,
      action: 'delete',
      payload: {'deleted_at': now.toIso8601String()},
    );
    await _loadData();
  }

  Widget _buildInlineAccountsTab(BuildContext context) {
    final totalBalance = _accounts
        .where((a) => a.isLiquid && !a.archived)
        .fold<double>(0, (sum, a) => sum + a.currentBalance);
    return RefreshIndicator(
      onRefresh: () => _loadData(pull: true),
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Saldo Likuid',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      OrbitAmountText(
                        amount: totalBalance,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsScreen()),
                    );
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, AppTokens.minTouchTarget),
                  ),
                  child: const Text('Kelola Akun'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          if (_accounts.isEmpty)
            OrbitEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada akun keuangan',
              description: 'Buat akun kas, rekening bank, atau dompet digital.',
              actionLabel: 'Kelola Akun',
              onAction: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                );
                _loadData();
              },
            )
          else
            ..._accounts.map((acc) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space2),
                child: OrbitCard(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountsScreen()),
                    );
                    _loadData();
                  },
                  padding: const EdgeInsets.all(AppTokens.space3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            Text(
                              acc.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OrbitAmountText(
                        amount: acc.currentBalance,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _openAddTransactionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TransactionFormSheet(onSaved: _loadData),
    );
  }

  Future<void> _showTransactionDetailSheet(LocalTransaction tx) async {
    String? selectedProjectId = tx.projectId;
    final accountName = _accountNames[tx.accountId] ?? tx.accountId;
    final categoryName = tx.categoryId == null
        ? 'Tanpa Kategori'
        : (_categoryNames[tx.categoryId] ?? tx.categoryId!);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      OrbitStatusBadge(
                        label: tx.type == 'income'
                            ? 'Pemasukan'
                            : (tx.type == 'expense'
                                ? 'Pengeluaran'
                                : 'Transfer'),
                        variant: tx.type == 'income'
                            ? OrbitBadgeVariant.income
                            : (tx.type == 'expense'
                                ? OrbitBadgeVariant.expense
                                : OrbitBadgeVariant.neutral),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Text(
                        tx.origin,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(ctx),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    tx.merchant ?? tx.note ?? 'Transaksi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OrbitAmountText(
                    amount: tx.amount,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: tx.type == 'income'
                          ? AppColors.incomeColor(ctx)
                          : (tx.type == 'expense'
                              ? AppColors.expenseColor(ctx)
                              : AppColors.textPrimaryColor(ctx)),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  Text(
                    'Akun: $accountName   Kategori: $categoryName',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(ctx),
                    ),
                  ),
                  if (_projects.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space3),
                    DropdownButtonFormField<String?>(
                      initialValue: _projects.any(
                        (p) => p.id == selectedProjectId,
                      )
                          ? selectedProjectId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Tautkan ke Proyek (Margin Proyek)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tidak terhubung proyek'),
                        ),
                        ..._projects.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (val) async {
                        setSheetState(() => selectedProjectId = val);
                        await (AppDatabase.shared.update(
                          AppDatabase.shared.localTransactions,
                        )..where((t) => t.id.equals(tx.id))).write(
                          LocalTransactionsCompanion(
                            projectId: drift.Value(val),
                          ),
                        );
                        await SyncService.instance.pushRecord(
                          tableName: 'transactions',
                          recordId: tx.id,
                          action: 'update',
                          payload: {
                            'id': tx.id,
                            'workspace_id': tx.workspaceId,
                            'account_id': tx.accountId,
                            'category_id': tx.categoryId,
                            'project_id': val,
                            'type': tx.type,
                            'status': tx.status,
                            'amount': tx.amount,
                            'currency': tx.currency,
                            'source': tx.source,
                            'merchant': tx.merchant,
                            'note': tx.note,
                            'occurred_at': tx.occurredAt
                                .toUtc()
                                .toIso8601String(),
                            'origin': tx.origin,
                          },
                        );
                        _loadData();
                      },
                    ),
                  ],
                  const SizedBox(height: AppTokens.space3),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showImportCsvSheet() async {
    final csvController = TextEditingController();
    String? selectedAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    List<ParsedBankMutationItem> preview = const [];
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Impor CSV Mutasi Bank',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mendukung pemisah koma (,) atau titik koma (;), kolom Tanggal, Keterangan, Nominal, Debit, dan Kredit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Wrap(
                      spacing: AppTokens.space2,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              csvController.text =
                                  FinanceCsvService.sampleBankMutationCsv;
                              preview =
                                  FinanceCsvService.parseBankMutationCsv(
                                    csvController.text,
                                  );
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                          ),
                          label: const Text('Muat Contoh Mutasi'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            final text = data?.text ?? '';
                            setSheetState(() {
                              csvController.text = text;
                              preview =
                                  FinanceCsvService.parseBankMutationCsv(text);
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          icon: const Icon(
                            Icons.content_paste_outlined,
                            size: 16,
                          ),
                          label: const Text('Tempel Clipboard'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    if (_accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space3),
                        decoration: BoxDecoration(
                          color: AppColors.warningColor(ctx).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                        ),
                        child: const Text(
                          'Buat minimal 1 akun terlebih dahulu di tab Akun sebelum mengimpor mutasi.',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Simpan ke Akun',
                          border: OutlineInputBorder(),
                        ),
                        items: _accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedAccountId = v),
                      ),
                    const SizedBox(height: AppTokens.space2),
                    TextField(
                      controller: csvController,
                      minLines: 4,
                      maxLines: 6,
                      onChanged: (value) {
                        setSheetState(() {
                          preview =
                              FinanceCsvService.parseBankMutationCsv(value);
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Konten CSV Mutasi',
                        hintText: 'Tanggal;Keterangan;Debit;Kredit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space3),
                      Text(
                        'Pratinjau (${preview.length} baris siap disimpan)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(ctx),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space1),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderColor(ctx)),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: preview.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: AppColors.borderColor(ctx),
                          ),
                          itemBuilder: (_, idx) {
                            final item = preview[idx];
                            final isIncome = item.type == 'income';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.merchant,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(item.date),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMutedColor(
                                              ctx,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '-'}${formatRupiah(item.amount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: isIncome
                                          ? AppColors.incomeColor(ctx)
                                          : AppColors.expenseColor(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space3),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, AppTokens.minTouchTarget),
                      ),
                      onPressed:
                          (saving ||
                              preview.isEmpty ||
                              selectedAccountId == null)
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              final db = AppDatabase.shared;
                              final wsId =
                                  (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                              double balanceDelta = 0;

                              for (final item in preview) {
                                final txId = const Uuid().v4();
                                final occurredAtUtc = item.date.toUtc();
                                await db
                                    .into(db.localTransactions)
                                    .insertOnConflictUpdate(
                                      LocalTransactionsCompanion.insert(
                                        id: txId,
                                        workspaceId: wsId,
                                        accountId: selectedAccountId!,
                                        type: item.type,
                                        status: 'confirmed',
                                        amount: item.amount,
                                        currency: 'IDR',
                                        source: const drift.Value('personal'),
                                        merchant: drift.Value(item.merchant),
                                        note: drift.Value(item.note),
                                        occurredAt: occurredAtUtc,
                                        origin: const drift.Value('csv_import'),
                                      ),
                                    );
                                await SyncService.instance.pushRecord(
                                  tableName: 'transactions',
                                  recordId: txId,
                                  action: 'insert',
                                  payload: {
                                    'id': txId,
                                    'workspace_id': wsId,
                                    'account_id': selectedAccountId!,
                                    'type': item.type,
                                    'status': 'confirmed',
                                    'amount': item.amount,
                                    'currency': 'IDR',
                                    'source': 'personal',
                                    'merchant': item.merchant,
                                    'note': item.note,
                                    'occurred_at': occurredAtUtc
                                        .toIso8601String(),
                                    'origin': 'csv_import',
                                  },
                                );
                                balanceDelta += item.type == 'income'
                                    ? item.amount
                                    : -item.amount;
                              }

                              final acc =
                                  await (db.select(db.localAccounts)..where(
                                        (a) => a.id.equals(selectedAccountId!),
                                      ))
                                      .getSingleOrNull();
                              if (acc != null) {
                                final nextBalance =
                                    acc.currentBalance + balanceDelta;
                                await (db.update(db.localAccounts)..where(
                                      (a) => a.id.equals(selectedAccountId!),
                                    ))
                                    .write(
                                      LocalAccountsCompanion(
                                        currentBalance: drift.Value(nextBalance),
                                      ),
                                    );
                                await SyncService.instance.pushRecord(
                                  tableName: 'accounts',
                                  recordId: acc.id,
                                  action: 'update',
                                  payload: {
                                    'id': acc.id,
                                    'workspace_id': acc.workspaceId,
                                    'name': acc.name,
                                    'type': acc.type,
                                    'currency': acc.currency,
                                    'current_balance': nextBalance,
                                  },
                                );
                              }

                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${preview.length} mutasi CSV berhasil diimpor.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(
                        saving
                            ? 'Menyimpan...'
                            : 'Simpan Batch (${preview.length})',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showExportOptionsSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ekspor Data Keuangan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              ListTile(
                minVerticalPadding: 12,
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Ekspor CSV Transaksi'),
                subtitle: const Text(
                  'Salin CSV aman (anti-formula injection) & simpan file sementara.',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _exportTransactionsToCsv();
                },
              ),
              ListTile(
                minVerticalPadding: 12,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Salin Laporan PDF-Ready'),
                subtitle: const Text(
                  'Ringkasan pemasukan, pengeluaran, arus kas, dan top kategori.',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _copyPdfReadySummary();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportTransactionsToCsv() async {
    final csv = FinanceCsvService.exportTransactionsCsv(
      _transactions,
      _accountNames,
      _categoryNames,
      projectNames: _projectNames,
    );
    await Clipboard.setData(ClipboardData(text: csv));
    String? tempPath;
    try {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'orbit_transaksi_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      tempPath = file.path;
    } catch (_) {
      tempPath = null;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tempPath != null
              ? 'CSV disalin ke clipboard dan ditulis ke $tempPath'
              : 'CSV transaksi berhasil disalin ke clipboard.',
        ),
      ),
    );
  }

  Future<void> _copyPdfReadySummary() async {
    final report = FinanceCsvService.buildTextSummaryReport(
      transactions: _transactions,
      accountNames: _accountNames,
      categoryNames: _categoryNames,
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Laporan Keuangan Disalin'),
        content: SingleChildScrollView(
          child: Text(
            report,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _FinanceActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FinanceActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppTokens.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.subtleColor(context),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
