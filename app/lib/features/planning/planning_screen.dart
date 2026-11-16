import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class PlanningScreen extends StatefulWidget {
  final String initialTab;
  final bool forceLoading;
  final bool forceEmpty;
  final bool forceError;

  const PlanningScreen({
    super.key,
    this.initialTab = 'anggaran',
    this.forceLoading = false,
    this.forceEmpty = false,
    this.forceError = false,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  late String _tab;
  bool _loading = true;
  String? _errorMessage;

  List<LocalBudget> _budgets = const [];
  List<LocalRecurringBill> _bills = const [];
  List<LocalSavingsGoal> _goals = const [];
  List<LocalCategory> _categories = const [];
  List<LocalAccount> _accounts = const [];
  Map<String, double> _spentByCategory = const {};
  Map<String, String> _categoryNames = const {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError) {
      _loading = false;
      _errorMessage = 'Gagal memuat data perencanaan.';
    } else if (widget.forceEmpty) {
      _loading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final db = AppDatabase.shared;
      final budgets = await (db.select(
        db.localBudgets,
      )..where((b) => b.deletedAt.isNull())).get();
      final bills = await (db.select(
        db.localRecurringBills,
      )..where((b) => b.deletedAt.isNull())).get();
      final goals = await (db.select(
        db.localSavingsGoals,
      )..where((g) => g.deletedAt.isNull())).get();
      final categories = await (db.select(
        db.localCategories,
      )..where((c) => c.archived.equals(false))).get();
      final accounts = await (db.select(
        db.localAccounts,
      )..where((a) => a.archived.equals(false))).get();
      final txs =
          await (db.select(db.localTransactions)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.type.equals('expense') &
                    t.status.equals('confirmed'),
              ))
              .get();

      final spent = <String, double>{};
      final now = DateTime.now();
      for (final tx in txs) {
        if (tx.categoryId == null) continue;
        final wib = tx.occurredAt.toUtc().add(const Duration(hours: 7));
        if (wib.year == now.year && wib.month == now.month) {
          spent[tx.categoryId!] = (spent[tx.categoryId!] ?? 0) + tx.amount;
        }
      }

      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _bills = bills;
        _goals = goals;
        _categories = categories;
        _accounts = accounts;
        _spentByCategory = spent;
        _categoryNames = {for (final c in categories) c.id: c.name};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat perencanaan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasColor(context),
      appBar: AppBar(
        title: const Text('Perencanaan Keuangan'),
        actions: [
          const OrbitPrivacyToggleButton(),
          IconButton(
            tooltip: 'Tambah Rencana',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            onPressed: _handleQuickAddForTab,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space4,
              AppTokens.space3,
              AppTokens.space4,
              AppTokens.space3,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor(context),
              border: Border(
                bottom: BorderSide(color: AppColors.borderColor(context)),
              ),
            ),
            child: OrbitViewSwitcher(
              activeViewMode: _tab,
              onChanged: (mode) => setState(() => _tab = mode),
              options: const [
                OrbitViewOption(
                  id: 'anggaran',
                  label: 'Anggaran',
                  icon: Icons.pie_chart_outline,
                ),
                OrbitViewOption(
                  id: 'tagihan',
                  label: 'Tagihan',
                  icon: Icons.receipt_outlined,
                ),
                OrbitViewOption(
                  id: 'target',
                  label: 'Target',
                  icon: Icons.savings_outlined,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: const [
          OrbitSkeleton(height: 86),
          SizedBox(height: AppTokens.space3),
          OrbitSkeleton(height: 86),
        ],
      );
    }

    if (_errorMessage != null) {
      return OrbitErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    switch (_tab) {
      case 'tagihan':
        return _buildBillsTab(context);
      case 'target':
        return _buildGoalsTab(context);
      default:
        return _buildBudgetsTab(context);
    }
  }

  Widget _buildBudgetsTab(BuildContext context) {
    if (_budgets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Belum ada anggaran bulanan',
              description:
                  'Tetapkan batas belanja per kategori agar pengeluaran tetap terkendali.',
              actionLabel: 'Buat Anggaran',
              onAction: _showAddBudgetSheet,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space4),
        itemCount: _budgets.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final b = _budgets[index];
          final spent = _spentByCategory[b.categoryId] ?? 0.0;
          final ratio = b.amount > 0 ? spent / b.amount : 0.0;
          final overBudget = ratio >= 1.0;
          final warning = !overBudget && (ratio * 100) >= b.notifyAtPercent;
          final barColor = overBudget
              ? AppColors.expenseColor(context)
              : (warning ? AppColors.warningColor(context) : AppColors.primary);

          return OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _categoryNames[b.categoryId] ?? 'Kategori',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    OrbitStatusBadge(
                      label: '${(ratio * 100).toStringAsFixed(0)}%',
                      variant: overBudget
                          ? OrbitBadgeVariant.expense
                          : (warning
                              ? OrbitBadgeVariant.warning
                              : OrbitBadgeVariant.neutral),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.subtleColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                OrbitPrivacyBuilder(
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Terpakai ${PrivacyModeController.formatAmount(spent)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      Text(
                        'Batas ${PrivacyModeController.formatAmount(b.amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillsTab(BuildContext context) {
    if (_bills.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.receipt_outlined,
              title: 'Belum ada tagihan rutin',
              description:
                  'Catat langganan, cicilan, atau kos bulanan untuk pengingat jatuh tempo.',
              actionLabel: 'Tambah Tagihan',
              onAction: _showAddBillSheet,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space4),
        itemCount: _bills.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bill.scheduleType == 'monthly'
                            ? 'Setiap tanggal ${bill.scheduleValue}'
                            : 'Jadwal ${bill.scheduleType}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OrbitAmountText(
                      amount: bill.amount,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    OrbitStatusBadge(
                      label: bill.active ? 'Aktif' : 'Nonaktif',
                      variant: bill.active
                          ? OrbitBadgeVariant.income
                          : OrbitBadgeVariant.neutral,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalsTab(BuildContext context) {
    if (_goals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.savings_outlined,
              title: 'Belum ada target tabungan',
              description:
                  'Tetapkan target dana darurat, perangkat kerja, atau rencana masa depan.',
              actionLabel: 'Buat Target',
              onAction: _showAddGoalSheet,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space4),
        itemCount: _goals.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final goal = _goals[index];
          final ratio = goal.targetAmount > 0
              ? (goal.currentAmount / goal.targetAmount)
              : 0.0;
          return OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    OrbitStatusBadge(
                      label: goal.isCompleted
                          ? 'Tercapai'
                          : '${(ratio * 100).toStringAsFixed(0)}%',
                      variant: goal.isCompleted
                          ? OrbitBadgeVariant.income
                          : OrbitBadgeVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.subtleColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isCompleted
                          ? AppColors.incomeColor(context)
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OrbitPrivacyBuilder(
                      builder: (context, _) => Text(
                        '${PrivacyModeController.formatAmount(goal.currentAmount)} / ${PrivacyModeController.formatAmount(goal.targetAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ),
                    if (!goal.isCompleted)
                      TextButton(
                        onPressed: () => _showDepositGoalSheet(goal),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, AppTokens.minTouchTarget),
                        ),
                        child: const Text('+ Setor'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleQuickAddForTab() {
    if (_tab == 'tagihan') {
      _showAddBillSheet();
    } else if (_tab == 'target') {
      _showAddGoalSheet();
    } else {
      _showAddBudgetSheet();
    }
  }

  Future<void> _showAddBudgetSheet() async {
    final amountCtrl = TextEditingController();
    String? categoryId = _categories.isNotEmpty ? _categories.first.id : null;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Buat Anggaran Bulanan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(() => categoryId = v),
                    ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Batas Anggaran (IDR)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: categoryId == null
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(
                                  amountCtrl.text.replaceAll(
                                    RegExp(r'[^0-9.]'),
                                    '',
                                  ),
                                ) ??
                                0;
                            if (amount <= 0) return;
                            final wsId =
                                (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                            final id = const Uuid().v4();
                            await AppDatabase.shared
                                .into(AppDatabase.shared.localBudgets)
                                .insertOnConflictUpdate(
                                  LocalBudgetsCompanion.insert(
                                    id: id,
                                    workspaceId: wsId,
                                    categoryId: categoryId!,
                                    amount: amount,
                                  ),
                                );
                            await SyncService.instance.pushRecord(
                              tableName: 'budgets',
                              recordId: id,
                              action: 'insert',
                              payload: {
                                'id': id,
                                'workspace_id': wsId,
                                'category_id': categoryId!,
                                'amount': amount,
                                'period': 'monthly',
                              },
                            );
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            _loadData();
                          },
                    child: const Text('Simpan Anggaran'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddBillSheet() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '25');
    final catId = _categories.isNotEmpty ? _categories.first.id : 'cat-default';
    final accId = _accounts.isNotEmpty ? _accounts.first.id : 'acc-default';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space4,
            AppTokens.space4,
            MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tambah Tagihan Rutin',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Tagihan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal (IDR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              TextField(
                controller: dayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Jatuh Tempo (1-28)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.minTouchTarget),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final amount =
                      double.tryParse(
                        amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                      ) ??
                      0;
                  final day = (int.tryParse(dayCtrl.text) ?? 25).clamp(1, 28);
                  if (name.isEmpty || amount <= 0) return;

                  final wsId =
                      (await SyncService.instance.getWorkspaceId()) ??
                      'personal-ws';
                  final id = const Uuid().v4();
                  await AppDatabase.shared
                      .into(AppDatabase.shared.localRecurringBills)
                      .insertOnConflictUpdate(
                        LocalRecurringBillsCompanion.insert(
                          id: id,
                          workspaceId: wsId,
                          name: name,
                          amount: amount,
                          categoryId: catId,
                          accountId: accId,
                          scheduleType: const drift.Value('monthly'),
                          scheduleValue: drift.Value(day),
                        ),
                      );
                  await SyncService.instance.pushRecord(
                    tableName: 'recurring_bills',
                    recordId: id,
                    action: 'insert',
                    payload: {
                      'id': id,
                      'workspace_id': wsId,
                      'name': name,
                      'amount': amount,
                      'category_id': catId,
                      'account_id': accId,
                      'schedule_type': 'monthly',
                      'schedule_value': day,
                      'active': true,
                    },
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _loadData();
                },
                child: const Text('Simpan Tagihan'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddGoalSheet() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space4,
            AppTokens.space4,
            MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Buat Target Tabungan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Target',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Target (IDR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.minTouchTarget),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final target =
                      double.tryParse(
                        targetCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                      ) ??
                      0;
                  if (name.isEmpty || target <= 0) return;

                  final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                  final id = const Uuid().v4();
                  await AppDatabase.shared
                      .into(AppDatabase.shared.localSavingsGoals)
                      .insertOnConflictUpdate(
                        LocalSavingsGoalsCompanion.insert(
                          id: id,
                          workspaceId: wsId,
                          name: name,
                          targetAmount: target,
                        ),
                      );
                  await SyncService.instance.pushRecord(
                    tableName: 'savings_goals',
                    recordId: id,
                    action: 'insert',
                    payload: {
                      'id': id,
                      'workspace_id': wsId,
                      'name': name,
                      'target_amount': target,
                      'current_amount': 0,
                      'is_completed': false,
                    },
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _loadData();
                },
                child: const Text('Simpan Target'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDepositGoalSheet(LocalSavingsGoal goal) async {
    final addCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space4,
            AppTokens.space4,
            MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Setor ke ${goal.name}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: addCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Tambahan (IDR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.minTouchTarget),
                ),
                onPressed: () async {
                  final delta =
                      double.tryParse(
                        addCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                      ) ??
                      0;
                  if (delta <= 0) return;
                  final nextAmount = goal.currentAmount + delta;
                  final completed = nextAmount >= goal.targetAmount;
                  await (AppDatabase.shared.update(
                    AppDatabase.shared.localSavingsGoals,
                  )..where((g) => g.id.equals(goal.id))).write(
                    LocalSavingsGoalsCompanion(
                      currentAmount: drift.Value(nextAmount),
                      isCompleted: drift.Value(completed),
                    ),
                  );
                  await SyncService.instance.pushRecord(
                    tableName: 'savings_goals',
                    recordId: goal.id,
                    action: 'update',
                    payload: {
                      'id': goal.id,
                      'workspace_id': goal.workspaceId,
                      'name': goal.name,
                      'target_amount': goal.targetAmount,
                      'current_amount': nextAmount,
                      'is_completed': completed,
                    },
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _loadData();
                },
                child: const Text('Simpan Setoran'),
              ),
            ],
          ),
        );
      },
    );
  }
}
