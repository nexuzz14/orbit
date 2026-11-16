import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';
import 'package:orbit_app/core/widgets/orbit_status_badge.dart';

/// Membuka modal Global Command Search ala Notion/Linear.
Future<void> showOrbitCommandSearch(
  BuildContext context, {
  VoidCallback? onGoToToday,
  VoidCallback? onCreateTask,
  VoidCallback? onCreateTransaction,
  void Function(GlobalSearchHit hit)? onSelectHit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.88,
      child: OrbitCommandSearchSheet(
        onGoToToday: onGoToToday,
        onCreateTask: onCreateTask,
        onCreateTransaction: onCreateTransaction,
        onSelectHit: onSelectHit,
      ),
    ),
  );
}

/// Konten Command Search dengan Quick Actions + hasil pencarian real-time (RPC + Drift offline).
class OrbitCommandSearchSheet extends StatefulWidget {
  final VoidCallback? onGoToToday;
  final VoidCallback? onCreateTask;
  final VoidCallback? onCreateTransaction;
  final void Function(GlobalSearchHit hit)? onSelectHit;

  const OrbitCommandSearchSheet({
    super.key,
    this.onGoToToday,
    this.onCreateTask,
    this.onCreateTransaction,
    this.onSelectHit,
  });

  @override
  State<OrbitCommandSearchSheet> createState() =>
      _OrbitCommandSearchSheetState();
}

class _OrbitCommandSearchSheetState extends State<OrbitCommandSearchSheet> {
  final _controller = TextEditingController();
  List<GlobalSearchHit> _hits = const [];
  bool _loading = false;
  int _searchGen = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged(String value) async {
    final q = value.trim();
    final gen = ++_searchGen;
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final res = await SyncService.instance.globalSearch(q, limit: 25);
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _hits = res;
      _loading = false;
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task':
        return Icons.check_box_outlined;
      case 'project':
        return Icons.folder_outlined;
      case 'event':
        return Icons.calendar_today_outlined;
      case 'transaction':
        return Icons.receipt_long_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'task':
        return 'Tugas';
      case 'project':
        return 'Proyek';
      case 'event':
        return 'Acara';
      case 'transaction':
        return 'Transaksi';
      default:
        return 'Item';
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderCol = AppColors.borderColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);
    final query = _controller.text.trim();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Cari tugas, proyek, acara, atau transaksi...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: TextStyle(fontSize: 15, color: textPrimary),
                    onChanged: _onQueryChanged,
                  ),
                ),
                if (query.isNotEmpty)
                  IconButton(
                    tooltip: 'Bersihkan pencarian',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Icon(Icons.close_rounded,
                        size: 19, color: textSecondary),
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  )
                else
                  IconButton(
                    tooltip: 'Tutup',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderCol),

          Expanded(
            child: query.isEmpty
                ? _buildQuickActions(context)
                : _loading && _hits.isEmpty
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _hits.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Tidak ada hasil untuk "$query".',
                                style: TextStyle(
                                    fontSize: 13.5, color: textSecondary),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _hits.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: borderCol,
                              indent: 52,
                            ),
                            itemBuilder: (context, index) {
                              final hit = _hits[index];
                              return _SearchResultTile(
                                hit: hit,
                                icon: _iconForType(hit.entityType),
                                typeLabel: _labelForType(hit.entityType),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  widget.onSelectHit?.call(hit);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final textMuted = AppColors.textMutedColor(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'AKSI CEPAT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: textMuted,
            ),
          ),
        ),
        if (widget.onGoToToday != null)
          _QuickActionRow(
            icon: Icons.wb_sunny_outlined,
            label: 'Ke Hari Ini',
            subtitle: 'Lihat fokus jadwal, tugas, dan perhatian hari ini',
            onTap: () {
              Navigator.of(context).pop();
              widget.onGoToToday!();
            },
          ),
        if (widget.onCreateTask != null)
          _QuickActionRow(
            icon: Icons.add_task_rounded,
            label: 'Buat Tugas Baru',
            subtitle: 'Tambah tugas, subtugas, atau jadwal berulang',
            onTap: () {
              Navigator.of(context).pop();
              widget.onCreateTask!();
            },
          ),
        if (widget.onCreateTransaction != null)
          _QuickActionRow(
            icon: Icons.add_card_outlined,
            label: 'Buat Transaksi Baru',
            subtitle: 'Catat pemasukan atau pengeluaran cepat',
            onTap: () {
              Navigator.of(context).pop();
              widget.onCreateTransaction!();
            },
          ),
      ],
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accentColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 18, color: AppColors.accentColor(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMutedColor(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final GlobalSearchHit hit;
  final IconData icon;
  final String typeLabel;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.hit,
    required this.icon,
    required this.typeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon,
                    size: 18, color: AppColors.textSecondaryColor(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OrbitStatusBadge(label: typeLabel),
                        if (hit.entityType == 'task' &&
                            hit.statusLabel != null)
                          OrbitTaskStatusBadge(
                            status: hit.statusLabel!,
                            compact: true,
                          )
                        else if (hit.statusLabel != null &&
                            hit.statusLabel!.isNotEmpty)
                          OrbitStatusBadge(label: hit.statusLabel!),
                        if (hit.dueAt != null)
                          Text(
                            formatDateIndoShort(hit.dueAt!),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMutedColor(context),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (hit.subtitle != null &&
                        hit.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        hit.subtitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMutedColor(context)),
            ],
          ),
        ),
      ),
    );
  }
}
