import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class PlanningScreen extends StatefulWidget {
  final String initialTab; // 'anggaran' | 'tagihan' | 'target'
  final bool forceLoading;
  final bool forceEmpty;
  final String? forceError;

  const PlanningScreen({
    super.key,
    this.initialTab = 'anggaran',
    this.forceLoading = false,
    this.forceEmpty = false,
    this.forceError,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  late String _activeTab;
  late bool _loading;
  String? _errorMessage;

  late List<Map<String, dynamic>> _budgets;
  late List<Map<String, dynamic>> _subscriptions;
  late List<Map<String, dynamic>> _goals;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loading = widget.forceLoading;
    _errorMessage = widget.forceError;
    _seedDefaultItems();
  }

  void _seedDefaultItems() {
    if (widget.forceEmpty) {
      _budgets = [];
      _subscriptions = [];
      _goals = [];
      return;
    }

    _budgets = [
      {
        'category': 'Makanan & Minuman',
        'kind': 'pribadi',
        'limit': 1500000.0,
        'spent': 1250000.0,
      },
      {
        'category': 'Transportasi & BBM',
        'kind': 'intern',
        'limit': 600000.0,
        'spent': 320000.0,
      },
      {
        'category': 'Kebutuhan Kuliah & Buku',
        'kind': 'kuliah',
        'limit': 500000.0,
        'spent': 540000.0,
      },
    ];

    _subscriptions = [
      {
        'name': 'Spotify Premium Student',
        'amount': 27500.0,
        'cycle': 'Bulanan',
        'nextDue': '14 Nov 2026',
        'kind': 'pribadi',
      },
      {
        'name': 'GitHub Copilot Pro',
        'amount': 160000.0,
        'cycle': 'Bulanan',
        'nextDue': '20 Nov 2026',
        'kind': 'freelance',
      },
      {
        'name': 'Internet Kos Fiber',
        'amount': 250000.0,
        'cycle': 'Bulanan',
        'nextDue': '01 Des 2026',
        'kind': 'kuliah',
      },
    ];

    _goals = [
      {
        'name': 'Dana Darurat Mahasiswa',
        'target': 10000000.0,
        'current': 6500000.0,
        'deadline': 'Des 2026',
        'kind': 'pribadi',
      },
      {
        'name': 'Upgrade Laptop Kerja',
        'target': 18000000.0,
        'current': 9200000.0,
        'deadline': 'Mar 2027',
        'kind': 'freelance',
      },
    ];
  }

  void _reload() {
    setState(() {
      _loading = false;
      _errorMessage = null;
      _seedDefaultItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perencanaan Keuangan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space4,
          AppTokens.space3,
          AppTokens.space4,
          96,
        ),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'anggaran', label: Text('Anggaran')),
              ButtonSegment(value: 'tagihan', label: Text('Tagihan')),
              ButtonSegment(value: 'target', label: Text('Target')),
            ],
            selected: {_activeTab},
            onSelectionChanged: (s) => setState(() => _activeTab = s.first),
          ),
          const SizedBox(height: AppTokens.space4),

          if (_errorMessage != null) ...[
            OrbitErrorState(
              message: _errorMessage!,
              onRetry: _reload,
            ),
            const SizedBox(height: AppTokens.space4),
          ],

          if (_loading) ...[
            const OrbitSkeleton(height: 92),
            const SizedBox(height: AppTokens.space3),
            const OrbitSkeleton(height: 92),
          ] else if (_activeTab == 'anggaran') ...[
            if (_budgets.isEmpty)
              OrbitEmptyState(
                icon: Icons.pie_chart_outline,
                title: 'Belum ada anggaran bulanan',
                description:
                    'Tetapkan batas pengeluaran per kategori agar arus kas tetap terkendali.',
                actionLabel: 'Muat Contoh Anggaran',
                onAction: _reload,
              )
            else
              for (final b in _budgets) ...[
                _buildBudgetCard(context, b, secondaryColor),
                const SizedBox(height: AppTokens.space3),
              ],
          ] else if (_activeTab == 'tagihan') ...[
            if (_subscriptions.isEmpty)
              OrbitEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Belum ada tagihan berulang',
                description:
                    'Pantau jadwal jatuh tempo langganan bulanan dan tagihan rutin Anda.',
                actionLabel: 'Muat Tagihan',
                onAction: _reload,
              )
            else
              for (final s in _subscriptions) ...[
                _buildSubscriptionCard(context, s, secondaryColor),
                const SizedBox(height: AppTokens.space3),
              ],
          ] else ...[
            if (_goals.isEmpty)
              OrbitEmptyState(
                icon: Icons.flag_outlined,
                title: 'Belum ada target tabungan',
                description:
                    'Buat target dana darurat atau pembelian perangkat dengan progres terukur.',
                actionLabel: 'Muat Target',
                onAction: _reload,
              )
            else
              for (final g in _goals) ...[
                _buildGoalCard(context, g, secondaryColor),
                const SizedBox(height: AppTokens.space3),
              ],
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    Map<String, dynamic> b,
    Color secondaryColor,
  ) {
    final limit = b['limit'] as double;
    final spent = b['spent'] as double;
    final ratio = (spent / limit).clamp(0.0, 1.0);
    final isOver = spent > limit;
    final isWarn = ratio >= 0.8 && !isOver;

    final barColor = isOver
        ? AppColors.expenseColor(context)
        : isWarn
            ? AppColors.warningColor(context)
            : AppColors.incomeColor(context);

    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  b['category'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OrbitKindBadge(kind: b['kind'] as String),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatRupiah(spent)} / ${formatRupiah(limit)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              OrbitStatusBadge(
                label: isOver
                    ? 'Melebihi Batas'
                    : '${(ratio * 100).round()}% Terpakai',
                variant: isOver
                    ? OrbitBadgeVariant.expense
                    : isWarn
                        ? OrbitBadgeVariant.warning
                        : OrbitBadgeVariant.income,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: barColor,
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Map<String, dynamic> s,
    Color secondaryColor,
  ) {
    return OrbitCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['name'] as String,
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
                    OrbitKindBadge(kind: s['kind'] as String),
                    Text(
                      '${s['cycle']} - Jatuh tempo ${s['nextDue']}',
                      style: TextStyle(fontSize: 11, color: secondaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(s['amount'] as double),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.expenseColor(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    Map<String, dynamic> g,
    Color secondaryColor,
  ) {
    final target = g['target'] as double;
    final current = g['current'] as double;
    final ratio = (current / target).clamp(0.0, 1.0);

    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  g['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OrbitKindBadge(kind: g['kind'] as String),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatRupiah(current)} dari ${formatRupiah(target)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              OrbitStatusBadge(
                label: '${(ratio * 100).round()}% (${g['deadline']})',
                variant: OrbitBadgeVariant.income,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: AppColors.accentColor(context),
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}
