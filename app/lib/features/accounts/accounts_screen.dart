import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class AccountsScreen extends StatefulWidget {
  final bool forceLoading;
  final String? forceError;

  const AccountsScreen({
    super.key,
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  AppDatabase get _db => AppDatabase.shared;
  final _uuid = const Uuid();

  bool _loading = true;
  String? _errorMessage;

  List<LocalAccount> _accounts = [];
  Map<String, double> _balances = {};

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadAccounts();
      SyncService.instance.pullAllFromSupabase().then((_) {
        if (mounted) _loadAccounts();
      });
    }
  }

  Future<void> _loadAccounts({bool pull = false}) async {
    if (widget.forceLoading) return;
    setState(() {
      _loading = true;
      _errorMessage = widget.forceError;
    });

    if (widget.forceError != null) {
      setState(() => _loading = false);
      return;
    }

    if (pull) {
      await SyncService.instance.pullAllFromSupabase();
    }

    try {
      final accs = await _db.select(_db.localAccounts).get();
      final txs = await _db.select(_db.localTransactions).get();

      final balMap = <String, double>{};
      for (final a in accs) {
        if (!a.archived) {
          balMap[a.id] = a.currentBalance != 0
              ? a.currentBalance
              : a.initialBalance;
        }
      }

      for (final tx in txs) {
        if (tx.deletedAt != null || tx.status == 'draft') continue;
        final current = balMap[tx.accountId] ?? 0;
        if (tx.type == 'income' ||
            (tx.type == 'transfer' && tx.transferDirection == 'in')) {
          balMap[tx.accountId] = current + tx.amount;
        } else if (tx.type == 'expense' ||
            (tx.type == 'transfer' && tx.transferDirection == 'out')) {
          balMap[tx.accountId] = current - tx.amount;
        }
      }

      if (mounted) {
        setState(() {
          _accounts = accs.where((a) => !a.archived).toList();
          _balances = balMap;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat daftar akun: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ewallet':
        return 'E-Wallet';
      case 'cash':
        return 'Tunai';
      case 'bank':
      default:
        return 'Rekening Bank';
    }
  }

  void _showAddAccountSheet() {
    final nameCtrl = TextEditingController();
    final initialCtrl = TextEditingController();
    String selectedType = 'bank';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: AppTokens.space4,
            right: AppTokens.space4,
            top: AppTokens.space4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tambah Akun Keuangan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Akun (mis. BCA Utama, GoPay)',
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'bank', label: Text('Bank')),
                  ButtonSegment(value: 'ewallet', label: Text('E-Wallet')),
                  ButtonSegment(value: 'cash', label: Text('Tunai')),
                ],
                selected: {selectedType},
                onSelectionChanged: (s) =>
                    setModalState(() => selectedType = s.first),
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: initialCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Saldo Awal (IDR)',
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              SizedBox(
                height: AppTokens.minTouchTarget,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final wsId =
                        await SyncService.instance.getWorkspaceId() ??
                            'ws-local';
                    final accId = _uuid.v4();
                    final name = nameCtrl.text.trim();
                    final initAmount = double.tryParse(
                          initialCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                        ) ??
                        0;

                    await _db.into(_db.localAccounts).insert(
                          LocalAccountsCompanion.insert(
                            id: accId,
                            workspaceId: wsId,
                            name: name,
                            type: selectedType,
                            currency: 'IDR',
                            initialBalance: Value(initAmount),
                            currentBalance: Value(initAmount),
                          ),
                        );

                    SyncService.instance.pushRecord(
                      tableName: 'accounts',
                      recordId: accId,
                      action: 'insert',
                      payload: {
                        'id': accId,
                        'workspace_id': wsId,
                        'name': name,
                        'type': selectedType,
                        'currency': 'IDR',
                        'initial_balance': initAmount,
                        'current_balance': initAmount,
                        'is_liquid': true,
                        'visibility': 'shared',
                      },
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadAccounts();
                  },
                  child: const Text('Simpan Akun'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    double totalBalance = 0;
    for (final val in _balances.values) {
      totalBalance += val;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akun & Dompet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showAddAccountSheet,
            tooltip: 'Tambah Akun',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAccounts(pull: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space3,
            AppTokens.space4,
            96,
          ),
          children: [
            OrbitCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Saldo Likuid',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRupiah(totalBalance),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: totalBalance >= 0
                                ? AppColors.incomeColor(context)
                                : AppColors.expenseColor(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  OrbitStatusBadge(
                    label: '${_accounts.length} Akun',
                    variant: OrbitBadgeVariant.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),

            if (_errorMessage != null) ...[
              OrbitErrorState(
                message: _errorMessage!,
                onRetry: _loadAccounts,
              ),
              const SizedBox(height: AppTokens.space4),
            ],

            if (_loading) ...[
              const OrbitSkeleton(height: 76),
              const SizedBox(height: AppTokens.space3),
              const OrbitSkeleton(height: 76),
            ] else if (_accounts.isEmpty) ...[
              OrbitEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Belum ada akun terdaftar',
                description:
                    'Tambahkan rekening bank, dompet digital, atau kas tunai untuk memantau saldo Anda.',
                actionLabel: 'Tambah Akun',
                onAction: _showAddAccountSheet,
              ),
            ] else ...[
              for (final acc in _accounts) ...[
                OrbitCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            OrbitStatusBadge(
                              label: _typeLabel(acc.type),
                              variant: OrbitBadgeVariant.neutral,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatRupiah(
                          _balances[acc.id] ?? 0,
                          currency: acc.currency,
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
