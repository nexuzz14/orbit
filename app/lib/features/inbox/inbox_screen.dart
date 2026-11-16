import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/android_auto_capture_bridge.dart';
import 'package:orbit_app/core/services/bank_notification_parser.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/receipt_ocr_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class InboxScreen extends StatefulWidget {
  final bool forceLoading;
  final String? forceError;
  final bool initialOpenReceiptScanner;

  const InboxScreen({
    super.key,
    this.forceLoading = false,
    this.forceError,
    this.initialOpenReceiptScanner = false,
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
      if (widget.initialOpenReceiptScanner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openReceiptImportDialog();
          }
        });
      }
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

  Future<void> _confirmSingleDraft(LocalTransaction tx) async {
    await (_db.update(_db.localTransactions)..where((t) => t.id.equals(tx.id)))
        .write(const LocalTransactionsCompanion(
      status: Value('confirmed'),
      draftState: Value(null),
    ));

    if (tx.categoryId != null) {
      await SyncService.instance.pushRecord(
        tableName: 'fn_confirm_draft',
        recordId: tx.id,
        action: 'rpc',
        payload: {
          'p_transaction_id': tx.id,
          'p_account_id': tx.accountId,
          'p_category_id': tx.categoryId,
          if (tx.source != null) 'p_source': tx.source,
        },
      );
    } else {
      await SyncService.instance.pushRecord(
        tableName: 'transactions',
        recordId: tx.id,
        action: 'update',
        payload: {
          'status': 'confirmed',
          'draft_state': null,
          if (tx.source != null) 'source': tx.source,
        },
      );
    }
  }

  Future<void> _confirmDraft(String id) async {
    final tx = _drafts.where((d) => d.id == id).firstOrNull;
    if (tx != null) {
      await _confirmSingleDraft(tx);
    } else {
      await (_db.update(_db.localTransactions)..where((t) => t.id.equals(id)))
          .write(const LocalTransactionsCompanion(
        status: Value('confirmed'),
        draftState: Value(null),
      ));
      await SyncService.instance.pushRecord(
        tableName: 'transactions',
        recordId: id,
        action: 'update',
        payload: {'status': 'confirmed', 'draft_state': null},
      );
    }
    await _loadDrafts();
    await HomeWidgetBridge.syncFromDatabase(_db);
  }

  Future<void> _rejectDraft(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.localTransactions)..where((t) => t.id.equals(id)))
        .write(LocalTransactionsCompanion(deletedAt: Value(now)));
    await SyncService.instance.pushRecord(
      tableName: 'transactions',
      recordId: id,
      action: 'delete',
      payload: {'deleted_at': now.toUtc().toIso8601String()},
    );
    await _loadDrafts();
    await HomeWidgetBridge.syncFromDatabase(_db);
  }

  Future<void> _confirmAll() async {
    for (final d in List<LocalTransaction>.from(_drafts)) {
      await _confirmSingleDraft(d);
    }
    await _loadDrafts();
    await HomeWidgetBridge.syncFromDatabase(_db);
  }

  Future<void> _openReceiptImportDialog() async {
    final textController = TextEditingController();
    String? errorMsg;
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pindai / Impor Teks Struk',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pilih foto struk untuk OCR lokal atau tempel teks struk POS. Gambar sementara otomatis dihapus setelah ekstraksi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  setSheetState(() {
                                    busy = true;
                                    errorMsg = null;
                                  });
                                  final path = await AndroidAutoCaptureBridge
                                      .instance
                                      .pickReceiptImageTempPath();
                                  if (path == null) {
                                    setSheetState(() {
                                      busy = false;
                                      errorMsg =
                                          'Pemilih gambar dibatalkan atau OCR gambar belum tersedia di perangkat ini.';
                                    });
                                    return;
                                  }
                                  final outcome = await ReceiptOcrService
                                      .extractAndParseFromImageFile(
                                        path,
                                        deleteTempFile: true,
                                      );
                                  if (!outcome.result.accepted ||
                                      outcome.result.amount <= 0) {
                                    setSheetState(() {
                                      busy = false;
                                      errorMsg =
                                          outcome.result.rejectionReason ??
                                          'Nominal total tidak ditemukan pada gambar struk.';
                                    });
                                    return;
                                  }
                                  await ReceiptOcrService
                                      .saveReceiptDraftToInbox(
                                        db: _db,
                                        parsed: outcome.result,
                                      );
                                  await _loadDrafts();
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                          icon: const Icon(
                            Icons.document_scanner_outlined,
                            size: 18,
                          ),
                          label: const Text('Pilih Foto Struk (OCR)'),
                        ),
                      ),
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: TextButton(
                          onPressed: () {
                            textController.text =
                                'ALFAMART JL SUDIRMAN\n15/11/2026 14:20\nKOPI LATTE 18.000\nROTI COKLAT 12.500\nTOTAL BAYAR Rp 30.500';
                            setSheetState(() => errorMsg = null);
                          },
                          child: const Text('Isi Contoh Struk'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('inbox_receipt_text_field'),
                    controller: textController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Teks struk (Alfamart / Indomaret / POS)',
                      hintText: 'Contoh:\nINDOMARET\nTOTAL Rp 45.000',
                      errorText: errorMsg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: AppTokens.minTouchTarget,
                    child: FilledButton(
                      key: const Key('inbox_receipt_save_btn'),
                      onPressed: busy
                          ? null
                          : () async {
                              final parsed = ReceiptOcrService.parseReceiptText(
                                textController.text,
                              );
                              if (!parsed.accepted || parsed.amount <= 0) {
                                setSheetState(
                                  () => errorMsg =
                                      parsed.rejectionReason ??
                                      'Nominal total struk tidak valid.',
                                );
                                return;
                              }
                              await ReceiptOcrService.saveReceiptDraftToInbox(
                                db: _db,
                                parsed: parsed,
                              );
                              await _loadDrafts();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                      child: const Text('Simpan ke Draft Inbox'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openBankSimulationDialog() async {
    final titleController = TextEditingController(text: 'BCA mobile');
    final bodyController = TextEditingController(
      text: 'Pembayaran QRIS di Kopi Kenangan sebesar Rp 32.000 berhasil.',
    );
    String selectedPackage = 'com.bca';
    String? errorMsg;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Simulasi Notifikasi Bank & E-Wallet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Menguji parser notifikasi lokal ke antrean Draft Inbox tanpa mengirim teks mentah ke server.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('BCA QRIS'),
                        selected: selectedPackage == 'com.bca',
                        onSelected: (_) {
                          setSheetState(() {
                            selectedPackage = 'com.bca';
                            titleController.text = 'BCA mobile';
                            bodyController.text =
                                'Pembayaran QRIS di Kopi Kenangan sebesar Rp 32.000 berhasil.';
                            errorMsg = null;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Mandiri Livin'"),
                        selected: selectedPackage == 'id.bmri.livin',
                        onSelected: (_) {
                          setSheetState(() {
                            selectedPackage = 'id.bmri.livin';
                            titleController.text = "Livin' by Mandiri";
                            bodyController.text =
                                'Dana masuk Rp 750.000 diterima dari PT Proyek Klien.';
                            errorMsg = null;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('GoPay'),
                        selected: selectedPackage == 'com.gojek.app',
                        onSelected: (_) {
                          setSheetState(() {
                            selectedPackage = 'com.gojek.app';
                            titleController.text = 'GoPay';
                            bodyController.text =
                                'Pembayaran GoPay di Superindo Rp 148.500 berhasil.';
                            errorMsg = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('inbox_sim_title_field'),
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Notifikasi',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('inbox_sim_body_field'),
                    controller: bodyController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Isi Notifikasi Simulasi',
                      errorText: errorMsg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: AppTokens.minTouchTarget,
                    child: FilledButton(
                      key: const Key('inbox_sim_submit_btn'),
                      onPressed: () async {
                        final parsed = BankNotificationParser.parse(
                          title: titleController.text,
                          body: bodyController.text,
                          packageName: selectedPackage,
                        );
                        if (!parsed.accepted || parsed.amount <= 0) {
                          setSheetState(
                            () => errorMsg =
                                parsed.rejectionReason ??
                                'Notifikasi tidak valid atau nominal <= 0.',
                          );
                          return;
                        }
                        await ReceiptOcrService
                            .saveBankNotificationDraftToInbox(
                              db: _db,
                              parsed: parsed,
                            );
                        await _loadDrafts();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Parse & Masuk ke Draft'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inbox',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          const OrbitPrivacyToggleButton(),
          if (_drafts.isNotEmpty)
            Semantics(
              button: true,
              label: 'Konfirmasi semua draft transaksi',
              child: TextButton(
                onPressed: _confirmAll,
                child: const Text('Konfirmasi Semua'),
              ),
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
                          'Tinjau transaksi otomatis dari notifikasi, share target, dan struk sebelum masuk saldo utama.',
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
            const SizedBox(height: AppTokens.space3),
            OrbitCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Impor & Uji Sumber Otomatis',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Wrap(
                    spacing: AppTokens.space2,
                    runSpacing: AppTokens.space2,
                    children: [
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: OutlinedButton.icon(
                          key: const Key('inbox_scan_receipt_btn'),
                          onPressed: _openReceiptImportDialog,
                          icon: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          label: const Text('Pindai / Impor Teks Struk'),
                        ),
                      ),
                      SizedBox(
                        height: AppTokens.minTouchTarget,
                        child: OutlinedButton.icon(
                          key: const Key('inbox_simulate_bank_btn'),
                          onPressed: _openBankSimulationDialog,
                          icon: const Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                          ),
                          label: const Text('Simulasi Notifikasi Bank'),
                        ),
                      ),
                    ],
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
                          OrbitAmountText(
                            amount: tx.amount,
                            currency: tx.currency,
                            prefix: tx.type == 'expense' ? '-' : '+',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tx.type == 'expense'
                                  ? AppColors.expenseColor(context)
                                  : AppColors.incomeColor(context),
                            ),
                          ),
                        ],
                      ),
                      if (tx.note != null && tx.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tx.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryColor,
                          ),
                        ),
                      ],
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
                          if (tx.draftState == 'needs_review' ||
                              tx.draftState == 'perlu_dicek')
                            const OrbitStatusBadge(
                              label: 'Perlu dicek',
                              variant: OrbitBadgeVariant.expense,
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
