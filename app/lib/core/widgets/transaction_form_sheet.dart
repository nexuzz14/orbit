import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class TransactionFormSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  final String? initialType;
  final String? initialMerchant;
  final String? initialNote;
  final String? initialSource;
  final String? initialProjectId;
  final String? linkTargetType;
  final String? linkTargetId;

  const TransactionFormSheet({
    super.key,
    this.onSaved,
    this.initialType,
    this.initialMerchant,
    this.initialNote,
    this.initialSource,
    this.initialProjectId,
    this.linkTargetType,
    this.linkTargetId,
  });

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onSaved,
    String? initialType,
    String? initialMerchant,
    String? initialNote,
    String? initialSource,
    String? initialProjectId,
    String? linkTargetType,
    String? linkTargetId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      builder: (ctx) => TransactionFormSheet(
        onSaved: onSaved,
        initialType: initialType,
        initialMerchant: initialMerchant,
        initialNote: initialNote,
        initialSource: initialSource,
        initialProjectId: initialProjectId,
        linkTargetType: linkTargetType,
        linkTargetId: linkTargetId,
      ),
    );
  }

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  final _db = AppDatabase.shared;
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();

  String _type = 'expense'; // expense | income | transfer
  String _selectedAccountId = 'acc-default';
  String _selectedToAccountId = 'acc-2';
  String _selectedCategoryId = 'Makan & Minum';
  String _selectedSource = 'pribadi';
  final DateTime _selectedDate = DateTime.now();
  bool _showDetails = false;
  bool _saving = false;

  List<Map<String, String>> _accounts = [
    {'id': 'acc-default', 'name': 'BCA Utama', 'currency': 'IDR'},
    {'id': 'acc-2', 'name': 'GoPay', 'currency': 'IDR'},
    {'id': 'acc-3', 'name': 'Tunai', 'currency': 'IDR'},
  ];

  final List<Map<String, String>> _expenseCategories = const [
    {'id': 'Makan & Minum', 'name': 'Makan & Minum'},
    {'id': 'Transportasi', 'name': 'Transportasi'},
    {'id': 'Kebutuhan Kuliah', 'name': 'Kebutuhan Kuliah'},
    {'id': 'Langganan & Cloud', 'name': 'Langganan & Cloud'},
    {'id': 'Lainnya', 'name': 'Lainnya'},
  ];

  final List<Map<String, String>> _incomeCategories = const [
    {'id': 'Freelance & Proyek', 'name': 'Freelance & Proyek'},
    {'id': 'Uang Saku / Magang', 'name': 'Uang Saku / Magang'},
    {'id': 'Lainnya', 'name': 'Lainnya'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null &&
        (widget.initialType == 'expense' ||
            widget.initialType == 'income' ||
            widget.initialType == 'transfer')) {
      _type = widget.initialType!;
    }
    if (widget.initialSource != null && widget.initialSource!.isNotEmpty) {
      _selectedSource = widget.initialSource!;
    }
    if (widget.initialMerchant != null && widget.initialMerchant!.isNotEmpty) {
      _merchantController.text = widget.initialMerchant!;
      _showDetails = true;
    } else if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _merchantController.text = widget.initialNote!;
      _showDetails = true;
    }
    _loadLocalAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalAccounts() async {
    try {
      final localAccs = await _db.select(_db.localAccounts).get();
      if (localAccs.isNotEmpty && mounted) {
        setState(() {
          _accounts = localAccs
              .map((a) => {
                    'id': a.id,
                    'name': a.name,
                    'currency': a.currency,
                  })
              .toList();
          _selectedAccountId = _accounts.first['id']!;
          if (_accounts.length > 1) {
            _selectedToAccountId = _accounts[1]['id']!;
          }
        });
      }
    } catch (_) {}
  }

  List<Map<String, String>> get _activeCategories =>
      _type == 'income' ? _incomeCategories : _expenseCategories;

  Future<void> _handleSave() async {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal lebih dari Rp0.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final wsId =
          await SyncService.instance.getWorkspaceId() ?? 'ws-local';
      final id = const Uuid().v4();
      final merchant = _merchantController.text.trim().isEmpty
          ? (_type == 'transfer' ? 'Transfer Antar Akun' : _selectedCategoryId)
          : _merchantController.text.trim();
      final catId = _type == 'transfer' ? null : _selectedCategoryId;

      await _db.into(_db.localTransactions).insert(
            LocalTransactionsCompanion.insert(
              id: id,
              workspaceId: wsId,
              accountId: _selectedAccountId,
              categoryId: Value(catId),
              projectId: Value(widget.initialProjectId),
              type: _type,
              status: 'confirmed',
              amount: amount,
              currency: 'IDR',
              source: Value(_selectedSource),
              merchant: Value(merchant),
              note: Value(widget.initialNote),
              occurredAt: _selectedDate,
            ),
          );

      // Update saldo akun lokal secara reaktif agar dashboard langsung sinkron
      final acc = await (_db.select(_db.localAccounts)
            ..where((a) => a.id.equals(_selectedAccountId)))
          .getSingleOrNull();
      if (acc != null) {
        final delta = _type == 'income' ? amount : (_type == 'expense' ? -amount : -amount);
        await (_db.update(_db.localAccounts)..where((a) => a.id.equals(acc.id))).write(
          LocalAccountsCompanion(currentBalance: Value(acc.currentBalance + delta)),
        );
      }

      if (widget.linkTargetType != null && widget.linkTargetId != null) {
        try {
          await SyncService.instance.addEntityLink(
            sourceType: 'transaction',
            sourceId: id,
            targetType: widget.linkTargetType!,
            targetId: widget.linkTargetId!,
            relationType: 'related',
          );
        } catch (_) {}
      }

      // Sinkronkan ke Supabase (langsung jika online, atau outbox jika offline)
      SyncService.instance.pushRecord(
        tableName: 'transactions',
        recordId: id,
        action: 'insert',
        payload: {
          'id': id,
          'workspace_id': wsId,
          'account_id': _selectedAccountId,
          if (catId != null) 'category_id': catId,
          if (widget.initialProjectId != null) 'project_id': widget.initialProjectId,
          'type': _type,
          'status': 'confirmed',
          'amount': amount,
          'currency': 'IDR',
          'source': _selectedSource,
          'merchant': merchant,
          if (widget.initialNote != null) 'note': widget.initialNote,
          'occurred_at': _selectedDate.toIso8601String(),
          'origin': 'manual',
        },
      );

      await HomeWidgetBridge.syncFromDatabase(_db);
      widget.onSaved?.call();
      await NotificationSchedulerService.rescheduleAll(_db);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bottom Sheet
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tambah Transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: 'Tutup form transaksi',
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.minTouchTarget,
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space2),

            // Interaksi 1: Nominal Besar di Atas
            Container(
              padding: const EdgeInsets.all(AppTokens.space4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSubtle : AppColors.lightSubtle,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nominal (IDR)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space1),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '0',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),

            // Interaksi 2: Jenis Transaksi (SegmentedButton)
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                ButtonSegment(value: 'income', label: Text('Pemasukan')),
                ButtonSegment(value: 'transfer', label: Text('Transfer')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                  if (_type != 'transfer') {
                    _selectedCategoryId = _activeCategories.first['id']!;
                  }
                });
              },
            ),
            const SizedBox(height: AppTokens.space4),

            // Interaksi 3: Chip Akun yang Bisa Di-scroll
            Text(
              _type == 'transfer' ? 'Dari Akun' : 'Pilih Akun',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppTokens.space2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _accounts.map((acc) {
                  final id = acc['id']!;
                  final selected = _selectedAccountId == id;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppTokens.space2),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppTokens.minTouchTarget,
                      ),
                      child: ChoiceChip(
                        label: Text(acc['name']!),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedAccountId = id),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppTokens.space3),

            // Interaksi 4: Chip Kategori (atau Akun Tujuan) yang Bisa Di-scroll
            if (_type == 'transfer') ...[
              Text(
                'Ke Akun Tujuan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _accounts
                      .where((a) => a['id'] != _selectedAccountId)
                      .map((acc) {
                    final id = acc['id']!;
                    final selected = _selectedToAccountId == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTokens.space2),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.minTouchTarget,
                        ),
                        child: ChoiceChip(
                          label: Text(acc['name']!),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedToAccountId = id),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              Text(
                'Pilih Kategori',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _activeCategories.map((cat) {
                    final id = cat['id']!;
                    final selected = _selectedCategoryId == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTokens.space2),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.minTouchTarget,
                        ),
                        child: ChoiceChip(
                          label: Text(cat['name']!),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = id),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: AppTokens.space3),

            // Baris Tanggal Default Hari Ini & Rincian Opsional
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tanggal: ${formatDateIndoShort(_selectedDate)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _showDetails = !_showDetails),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppTokens.minTouchTarget,
                      AppTokens.minTouchTarget,
                    ),
                  ),
                  child: Text(
                    _showDetails ? 'Tutup Rincian' : 'Catatan',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            if (_showDetails) ...[
              const SizedBox(height: AppTokens.space2),
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Catatan Singkat',
                  hintText: 'Contoh: Kopi Kenangan',
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const ['pribadi', 'intern', 'freelance', 'kuliah']
                      .map((kind) {
                    final selected = _selectedSource == kind;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTokens.space2),
                      child: ChoiceChip(
                        label: Text(AppColors.getKindLabel(kind)),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedSource = kind),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: AppTokens.space4),

            // Tombol Simpan Selalu Terlihat
            FilledButton(
              onPressed: _saving ? null : _handleSave,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan Transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}
