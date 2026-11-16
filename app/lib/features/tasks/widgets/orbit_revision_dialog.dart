import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_status_badge.dart';

/// Menampilkan bottom sheet wajib isi catatan alasan sebelum memindahkan tugas ke status Revisi.
/// Mengembalikan string alasan (non-kosong) atau null jika dibatalkan.
Future<String?> showOrbitRevisionNoteSheet(
  BuildContext context, {
  required String taskTitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => _RevisionNoteSheetContent(taskTitle: taskTitle),
  );
}

class _RevisionNoteSheetContent extends StatefulWidget {
  final String taskTitle;

  const _RevisionNoteSheetContent({required this.taskTitle});

  @override
  State<_RevisionNoteSheetContent> createState() =>
      _RevisionNoteSheetContentState();
}

class _RevisionNoteSheetContentState extends State<_RevisionNoteSheetContent> {
  final _noteCtrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _noteCtrl.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'Catatan alasan revisi wajib diisi sebelum melanjutkan.';
      });
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const OrbitTaskStatusBadge(status: 'revisi'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Alasan Pemindahan ke Revisi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.taskTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteCtrl,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Catatan revisi (wajib)',
                  hintText: 'Jelaskan apa yang perlu diperbaiki atau direvisi...',
                  errorText: _errorText,
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: _submit,
                      child: const Text('Kirim Revisi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menampilkan sheet pilih status D.2 untuk mobile (`Pindah status`).
/// Memilih `revisi` akan otomatis memaksa dialog alasan revisi wajib isi terlebih dahulu.
Future<void> showOrbitStatusPickerSheet(
  BuildContext context, {
  required LocalTask task,
  required Future<void> Function(String toStatus, String? note) onSelected,
}) async {
  const statuses = ['todo', 'doing', 'revisi', 'done'];
  final chosen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pindah Status Tugas',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondaryColor(ctx),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderColor(ctx)),
            ...statuses.map((st) {
              final isCurrent = task.status == st;
              return InkWell(
                onTap: isCurrent ? null : () => Navigator.of(ctx).pop(st),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        OrbitTaskStatusBadge(status: st),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            st == 'revisi'
                                ? 'Memerlukan catatan alasan revisi'
                                : st == 'done'
                                    ? 'Tandai selesai (100%)'
                                    : st == 'doing'
                                        ? 'Sedang dikerjakan saat ini'
                                        : 'Belum dimulai / antre',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondaryColor(ctx),
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Text(
                            'Aktif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentColor(ctx),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );

  if (chosen == null || !context.mounted) return;

  if (chosen == 'revisi') {
    final reason = await showOrbitRevisionNoteSheet(
      context,
      taskTitle: task.title,
    );
    if (reason == null || reason.trim().isEmpty) return;
    await onSelected('revisi', reason);
  } else {
    await onSelected(chosen, null);
  }
}
