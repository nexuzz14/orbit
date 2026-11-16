import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class AccountsScreen extends StatefulWidget {
  final bool forceLoading;
  final bool forceError;

  const AccountsScreen({
    super.key,
    this.forceLoading = false,
    this.forceError = false,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<LocalAccount> _accounts = const [];
  Map<String, double> _effectiveBalances = const {};

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError) {
      _loading = false;
      _errorMessage = 'Gagal memuat daftar akun lokal.';
    } else {
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final db = AppDatabase.shared;
      final accounts =
          await (db.select(db.localAccounts)
                ..where((a) => a.archived.equals(false))
                ..orderBy([(a) => drift.OrderingTerm.asc(a.sortOrder)]))
              .get();

      final txs = await (db.select(
        db.localTransactions,
      )..where((t) => t.deletedAt.isNull() & t.status.equals('confirmed'))).get();

      final balMap = <String, double>{};
      for (final a in accounts) {
        if (a.currentBalance != 0) {
          balMap[a.id] = a.currentBalance;
        } else {
          var total = a.initialBalance;
          for (final t in txs.where((t) => t.accountId == a.id)) {
            if (t.type == 'income') {
              total += t.amount;
            } else if (t.type == 'expense') {
              total -= t.amount;
            } else if (t.type == 'transfer') {
              total += t.transferDirection == 'in' ? t.amount : -t.amount;
            }
          }
          balMap[a.id] = total;
        }
      }

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _effectiveBalances = balMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat akun: $e';
      });
    }
  }

  double get _liquidTotal {
    var total = 0.0;
    for (final a in _accounts.where((a) => a.isLiquid)) {
      total += _effectiveBalances[a.id] ?? 0;
    }
    return total;
  }

  double get _overallTotal {
    var total = 0.0;
    for (final a in _accounts) {
      total += _effectiveBalances[a.id] ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasColor(context),
      appBar: AppBar(
        title: const Text('Akun & Dompet'),
        actions: [
          const OrbitPrivacyToggleButton(),
          IconButton(
            tooltip: 'Tambah Akun',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            onPressed: _showAddAccountSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: const [
          OrbitSkeleton(height: 92),
          SizedBox(height: AppTokens.space3),
          OrbitSkeleton(height: 76),
          SizedBox(height: AppTokens.space2),
          OrbitSkeleton(height: 76),
        ],
      );
    }

    if (_errorMessage != null) {
      return OrbitErrorState(message: _errorMessage!, onRetry: _loadAccounts);
    }

    if (_accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView(
          children: [
            const SizedBox(height: 40),
            OrbitEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada akun terdaftar',
              description:
                  'Tambahkan rekening bank, dompet digital, atau kas tunai untuk mulai mencatat arus kas.',
              actionLabel: 'Tambah Akun',
              onAction: _showAddAccountSheet,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
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
                  amount: _liquidTotal,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                OrbitPrivacyBuilder(
                  builder: (context, _) => Text(
                    'Total semua aset akun: ${PrivacyModeController.formatAmount(_overallTotal)} (${_accounts.length} akun)',
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          for (final acc in _accounts) ...[
            OrbitCard(
              onTap: () => _showAccountDetailSheet(acc),
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.subtleColor(context),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(color: AppColors.borderColor(context)),
                    ),
                    child: Icon(
                      _iconForType(acc.type),
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            OrbitStatusBadge(
                              label: _labelForType(acc.type),
                              variant: OrbitBadgeVariant.neutral,
                            ),
                            if (!acc.isLiquid) ...[
                              const SizedBox(width: 6),
                              const OrbitStatusBadge(
                                label: 'Non-Likuid',
                                variant: OrbitBadgeVariant.warning,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  OrbitAmountText(
                    amount: _effectiveBalances[acc.id] ?? acc.currentBalance,
                    currency: acc.currency,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space2),
          ],
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;
      case 'ewallet':
        return Icons.smartphone_outlined;
      case 'investment':
        return Icons.trending_up_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'cash':
        return 'Tunai';
      case 'ewallet':
        return 'E-Wallet';
      case 'investment':
        return 'Investasi';
      default:
        return 'Bank';
    }
  }

  Future<void> _showAddAccountSheet() async {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    var type = 'bank';
    var isLiquid = true;

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
                    'Tambah Akun Keuangan',
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
                      labelText: 'Nama Akun',
                      hintText: 'Contoh: BCA Utama / GoPay',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Akun',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                      DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
                      DropdownMenuItem(
                        value: 'investment',
                        child: Text('Investasi'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() {
                          type = v;
                          isLiquid = v != 'investment';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Saldo Awal (IDR)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hitung sebagai saldo likuid'),
                    value: isLiquid,
                    onChanged: (v) => setSheetState(() => isLiquid = v),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final initAmount =
                          double.tryParse(
                            balanceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                          ) ??
                          0.0;
                      final wsId =
                          (await SyncService.instance.getWorkspaceId()) ??
                          'personal-ws';
                      final id = const Uuid().v4();

                      await AppDatabase.shared
                          .into(AppDatabase.shared.localAccounts)
                          .insertOnConflictUpdate(
                            LocalAccountsCompanion.insert(
                              id: id,
                              workspaceId: wsId,
                              name: name,
                              type: type,
                              currency: 'IDR',
                              initialBalance: drift.Value(initAmount),
                              currentBalance: drift.Value(initAmount),
                              isLiquid: drift.Value(isLiquid),
                              sortOrder: drift.Value(_accounts.length),
                            ),
                          );
                      await SyncService.instance.pushRecord(
                        tableName: 'accounts',
                        recordId: id,
                        action: 'insert',
                        payload: {
                          'id': id,
                          'workspace_id': wsId,
                          'name': name,
                          'type': type,
                          'currency': 'IDR',
                          'initial_balance': initAmount,
                          'current_balance': initAmount,
                          'is_liquid': isLiquid,
                          'sort_order': _accounts.length,
                        },
                      );

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      _loadAccounts();
                    },
                    child: const Text('Simpan Akun'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAccountDetailSheet(LocalAccount acc) async {
    final balCtrl = TextEditingController(
      text: (_effectiveBalances[acc.id] ?? acc.currentBalance).toStringAsFixed(0),
    );
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
                acc.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextField(
                controller: balCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Penyesuaian Saldo (IDR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.minTouchTarget),
                ),
                onPressed: () async {
                  final nextBal =
                      double.tryParse(
                        balCtrl.text.replaceAll(RegExp(r'[^0-9.-]'), ''),
                      ) ??
                      acc.currentBalance;
                  await (AppDatabase.shared.update(
                    AppDatabase.shared.localAccounts,
                  )..where((a) => a.id.equals(acc.id))).write(
                    LocalAccountsCompanion(
                      currentBalance: drift.Value(nextBal),
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
                      'current_balance': nextBal,
                    },
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _loadAccounts();
                },
                child: const Text('Perbarui Saldo'),
              ),
            ],
          ),
        );
      },
    );
  }
}
