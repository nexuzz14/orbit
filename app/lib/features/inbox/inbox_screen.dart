import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class InboxScreen extends StatefulWidget {
  final bool forceLoading;
  final String? forceError;

  const InboxScreen({
    super.key,
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  AppDatabase get _db => AppDatabase.shared;

  bool _loading = true;
  String? _errorMessage;
  List<LocalTransaction> _drafts = [];

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadDrafts();
    }
  }

  Future<void> _loadDrafts() async {
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
      final rows = await (_db.select(_db.localTransactions)
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .get();

      if (mounted) {
        setState(() {
          _drafts = rows
              .where((t) => t.deletedAt == null && t.status == 'draft')
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memuat antrean draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmDraft(String id) async {
    await (_db.update(_db.localTransactions)..where((t) => t.id.equals(id)))
        .write(const LocalTransactionsCompanion(status: Value('confirmed')));
    await _loadDrafts();
  }

  Future<void> _rejectDraft(String id) async {
    await (_db.update(_db.localTransactions)..where((t) => t.id.equals(id)))
        .write(LocalTransactionsCompanion(deletedAt: Value(DateTime.now())));
    await _loadDrafts();
  }

  Future<void> _confirmAll() async {
    for (final d in _drafts) {
      await (_db.update(_db.localTransactions)..where((t) => t.id.equals(d.id)))
          .write(const LocalTransactionsCompanion(status: Value('confirmed')));
    }
    await _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inbox & Sumber Otomatis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_drafts.isNotEmpty)
            TextButton(
              onPressed: _confirmAll,
              child: const Text('Konfirmasi Semua'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDrafts,
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
                        const Text(
                          'Antrean Verifikasi Transaksi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tinjau transaksi otomatis dari notifikasi dan email sebelum masuk ke saldo utama.',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space3),
                  OrbitStatusBadge(
                    label: '${_drafts.length} Draft',
                    variant: _drafts.isNotEmpty
                        ? OrbitBadgeVariant.warning
                        : OrbitBadgeVariant.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),

            if (_errorMessage != null) ...[
              OrbitErrorState(
                message: _errorMessage!,
                onRetry: _loadDrafts,
              ),
              const SizedBox(height: AppTokens.space4),
            ],

            if (_loading) ...[
              const OrbitSkeleton(height: 92),
              const SizedBox(height: AppTokens.space3),
              const OrbitSkeleton(height: 92),
            ] else if (_drafts.isEmpty) ...[
              OrbitEmptyState(
                icon: Icons.inbox_outlined,
                title: 'Tidak ada draft menunggu konfirmasi',
                description:
                    'Semua transaksi dari notifikasi dan email telah diverifikasi.',
                actionLabel: 'Segarkan Inbox',
                onAction: _loadDrafts,
              ),
            ] else ...[
              for (final tx in _drafts) ...[
                OrbitCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              tx.merchant ?? 'Transaksi Otomatis',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${tx.type == 'expense' ? '-' : '+'}${formatRupiah(tx.amount, currency: tx.currency)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tx.type == 'expense'
                                  ? AppColors.expenseColor(context)
                                  : AppColors.incomeColor(context),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Wrap(
                        spacing: AppTokens.space2,
                        runSpacing: AppTokens.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const OrbitStatusBadge(
                            label: 'Draft',
                            variant: OrbitBadgeVariant.warning,
                          ),
                          if (tx.source != null && tx.source!.isNotEmpty)
                            OrbitKindBadge(kind: tx.source!),
                          Text(
                            formatDateIndoShort(tx.occurredAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _rejectDraft(tx.id),
                            child: const Text('Tolak'),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          FilledButton(
                            onPressed: () => _confirmDraft(tx.id),
                            child: const Text('Konfirmasi'),
                          ),
                        ],
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
