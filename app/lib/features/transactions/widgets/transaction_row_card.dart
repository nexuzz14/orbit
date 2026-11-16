import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class TransactionShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback? onTap;

  const TransactionShortcutButton({
    super.key,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}

class TransactionRowTile extends StatelessWidget {
  final LocalTransaction transaction;
  final String accountName;
  final VoidCallback onDelete;

  const TransactionRowTile({
    super.key,
    required this.transaction,
    required this.accountName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final isExpense = transaction.type == 'expense' ||
        (transaction.type == 'transfer' &&
            transaction.transferDirection == 'out');
    final isDraft = transaction.status == 'draft';
    final title = transaction.type == 'transfer'
        ? 'Transfer Antar Akun'
        : (transaction.merchant ?? transaction.categoryId ?? 'Transaksi');

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
              transaction.type == 'transfer'
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
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                    if (transaction.source != null &&
                        transaction.source!.isNotEmpty)
                      OrbitKindBadge(kind: transaction.source!),
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
          OrbitAmountText(
            amount: transaction.amount,
            currency: transaction.currency,
            prefix: isExpense ? '-' : '+',
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
            onPressed: onDelete,
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
}

class TransactionSummaryCard extends StatelessWidget {
  final List<LocalTransaction> transactions;

  const TransactionSummaryCard({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    double totalIn = 0;
    double totalOut = 0;
    for (final tx in transactions) {
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
              const Expanded(
                child: Text(
                  'Total Pemasukan',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Flexible(
                child: OrbitAmountText(
                  amount: totalIn,
                  prefix: '+',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.incomeColor(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Pengeluaran',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Flexible(
                child: OrbitAmountText(
                  amount: totalOut,
                  prefix: '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.expenseColor(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppTokens.space6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Selisih Bersih',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Flexible(
                child: OrbitAmountText(
                  amount: (totalIn - totalOut).abs(),
                  prefix: (totalIn - totalOut) >= 0 ? '+' : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
