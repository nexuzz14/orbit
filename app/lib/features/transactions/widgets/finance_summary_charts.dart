import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class FinanceSummaryCharts extends StatelessWidget {
  final List<LocalTransaction> transactions;
  final Map<String, String> categoryNames;

  const FinanceSummaryCharts({
    super.key,
    required this.transactions,
    required this.categoryNames,
  });

  @override
  Widget build(BuildContext context) {
    final active = transactions.where((t) => t.deletedAt == null).toList();
    final monthlyBuckets = _buildMonthlyBuckets(active);
    final categorySlices = _buildTopExpenseCategories(active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrbitCard(
          padding: const EdgeInsets.all(AppTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arus Kas Bulanan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Perbandingan pemasukan dan pengeluaran per bulan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  _LegendPill(
                    color: AppColors.incomeColor(context),
                    label: 'Masuk',
                  ),
                  const SizedBox(width: AppTokens.space2),
                  _LegendPill(
                    color: AppColors.expenseColor(context),
                    label: 'Keluar',
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
              if (monthlyBuckets.every((b) => b.income == 0 && b.expense == 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada histori arus kas untuk ditampilkan.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 168,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _MonthlyCashflowPainter(
                          buckets: monthlyBuckets,
                          incomeColor: AppColors.incomeColor(context),
                          expenseColor: AppColors.expenseColor(context),
                          gridColor: AppColors.borderColor(context),
                          labelColor: AppColors.textMutedColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Row(
                      children: monthlyBuckets.map((bucket) {
                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                bucket.shortLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondaryColor(context),
                                ),
                              ),
                              Text(
                                _compactMoney(bucket.income - bucket.expense),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: (bucket.income - bucket.expense) >= 0
                                      ? AppColors.incomeColor(context)
                                      : AppColors.expenseColor(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space3),
        OrbitCard(
          padding: const EdgeInsets.all(AppTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Kategori Pengeluaran',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Proporsi belanja berdasarkan kategori aktif',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedColor(context),
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              if (categorySlices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Belum ada transaksi pengeluaran.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMutedColor(context),
                    ),
                  ),
                )
              else
                Column(
                  children: categorySlices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final slice = entry.value;
                    final barColors = <Color>[
                      AppColors.primary,
                      AppColors.expenseColor(context),
                      AppColors.warningColor(context),
                      AppColors.accentColor(context),
                      AppColors.textSecondaryColor(context),
                    ];
                    final color = barColors[index % barColors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slice.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimaryColor(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${slice.sharePercent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: AppColors.textMutedColor(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OrbitAmountText(
                                amount: slice.amount,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: slice.ratio.clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: AppColors.subtleColor(context),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_MonthlyCashflowBucket> _buildMonthlyBuckets(
    List<LocalTransaction> active,
  ) {
    DateTime anchor = DateTime.now();
    if (active.isNotEmpty) {
      final sorted = [...active]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final latestWib = sorted.first.occurredAt.toUtc().add(
        const Duration(hours: 7),
      );
      final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
      anchor = latestWib.isAfter(nowWib) ? latestWib : nowWib;
      if (active.every((t) {
        final w = t.occurredAt.toUtc().add(const Duration(hours: 7));
        final monthsApart =
            (nowWib.year - w.year) * 12 + (nowWib.month - w.month);
        return monthsApart.abs() > 5;
      })) {
        anchor = latestWib;
      }
    }

    const monthShort = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final buckets = <_MonthlyCashflowBucket>[];
    for (var offset = 5; offset >= 0; offset--) {
      final dt = DateTime(anchor.year, anchor.month - offset, 1);
      double income = 0;
      double expense = 0;
      for (final tx in active) {
        final wib = tx.occurredAt.toUtc().add(const Duration(hours: 7));
        if (wib.year == dt.year && wib.month == dt.month) {
          if (tx.type == 'income') {
            income += tx.amount;
          } else if (tx.type == 'expense') {
            expense += tx.amount;
          }
        }
      }
      buckets.add(
        _MonthlyCashflowBucket(
          shortLabel: monthShort[(dt.month - 1).clamp(0, 11)],
          income: income,
          expense: expense,
        ),
      );
    }
    return buckets;
  }

  List<_CategoryExpenseSlice> _buildTopExpenseCategories(
    List<LocalTransaction> active,
  ) {
    final totals = <String, double>{};
    double grandTotal = 0;
    for (final tx in active) {
      if (tx.type != 'expense') continue;
      final label = tx.categoryId == null
          ? 'Tanpa Kategori'
          : (categoryNames[tx.categoryId] ?? 'Lainnya');
      totals[label] = (totals[label] ?? 0) + tx.amount;
      grandTotal += tx.amount;
    }
    if (totals.isEmpty || grandTotal <= 0) return const [];
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) {
      final ratio = e.value / grandTotal;
      return _CategoryExpenseSlice(
        label: e.key,
        amount: e.value,
        ratio: ratio,
        sharePercent: ratio * 100,
      );
    }).toList();
  }

  static String _compactMoney(double val) {
    if (val == 0) return '0';
    final prefix = val > 0 ? '+' : '-';
    final abs = val.abs();
    if (abs >= 1000000) {
      return '$prefix${(abs / 1000000).toStringAsFixed(1)}jt';
    }
    if (abs >= 1000) {
      return '$prefix${(abs / 1000).toStringAsFixed(0)}rb';
    }
    return '$prefix${abs.toStringAsFixed(0)}';
  }
}

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}

class _MonthlyCashflowBucket {
  final String shortLabel;
  final double income;
  final double expense;

  const _MonthlyCashflowBucket({
    required this.shortLabel,
    required this.income,
    required this.expense,
  });
}

class _CategoryExpenseSlice {
  final String label;
  final double amount;
  final double ratio;
  final double sharePercent;

  const _CategoryExpenseSlice({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.sharePercent,
  });
}

class _MonthlyCashflowPainter extends CustomPainter {
  final List<_MonthlyCashflowBucket> buckets;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final Color labelColor;

  const _MonthlyCashflowPainter({
    required this.buckets,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty || size.width <= 0 || size.height <= 0) return;

    double maxValue = 0;
    for (final b in buckets) {
      maxValue = math.max(maxValue, math.max(b.income, b.expense));
    }
    if (maxValue <= 0) maxValue = 1;

    const topPad = 12.0;
    const bottomPad = 6.0;
    final chartHeight = math.max(20.0, size.height - topPad - bottomPad);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = topPad + (chartHeight * (i / 3));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slotWidth = size.width / buckets.length;
    final barWidth = math.min(14.0, (slotWidth * 0.34).clamp(6.0, 14.0));
    const pairGap = 4.0;

    final incomePaint = Paint()..color = incomeColor;
    final expensePaint = Paint()..color = expenseColor;

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final baseY = topPad + chartHeight;

      final incomeHeight = b.income > 0
          ? math.max(4.0, (b.income / maxValue) * chartHeight)
          : 0.0;
      final expenseHeight = b.expense > 0
          ? math.max(4.0, (b.expense / maxValue) * chartHeight)
          : 0.0;

      if (incomeHeight > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX - barWidth - (pairGap / 2),
            baseY - incomeHeight,
            barWidth,
            incomeHeight,
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, incomePaint);
      }

      if (expenseHeight > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX + (pairGap / 2),
            baseY - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, expensePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyCashflowPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.incomeColor != incomeColor ||
        oldDelegate.expenseColor != expenseColor ||
        oldDelegate.gridColor != gridColor;
  }
}
