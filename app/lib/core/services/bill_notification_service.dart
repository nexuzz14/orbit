import 'package:intl/intl.dart';
import 'package:orbit_app/core/services/notification_service.dart';

class BillNotificationService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Pengingat tagihan jatuh tempo (H-3 atau Hari-H).
  /// Sesuai PRD M13/9.9: secara default isi notifikasi tidak memuat nominal di layar kunci.
  static Future<void> showBillDueNotification({
    required int id,
    required String billName,
    required double amount,
    required int daysLeft,
    bool showDetails = false,
    String? billId,
  }) async {
    final title = daysLeft == 0
        ? 'Tagihan Jatuh Tempo Hari Ini'
        : 'Pengingat Tagihan (H-$daysLeft)';

    final String body;
    if (showDetails) {
      final formattedAmount = _currencyFormat.format(amount);
      body = daysLeft == 0
          ? 'Tagihan $billName sebesar $formattedAmount jatuh tempo hari ini.'
          : 'Tagihan $billName sebesar $formattedAmount jatuh tempo dalam $daysLeft hari.';
    } else {
      body = daysLeft == 0
          ? 'Ada tagihan rutin yang jatuh tempo hari ini. Ketuk untuk meninjau.'
          : 'Ada tagihan rutin yang akan jatuh tempo dalam $daysLeft hari.';
    }

    await NotificationService.showNotification(
      id: id,
      title: title,
      body: body,
      channelId: NotificationService.channelBillId,
      channelName: NotificationService.channelBillName,
      channelDescription: NotificationService.channelBillDesc,
      payload: NotificationPayload(
        type: 'bill',
        targetTab: 2,
        uangSection: 'tagihan',
        itemId: billId,
      ),
    );
  }

  /// Peringatan anggaran 80%
  static Future<void> showBudgetWarningNotification({
    required int id,
    required String categoryName,
    required double percentSpent,
    bool showDetails = false,
    String? budgetId,
  }) async {
    final title = showDetails
        ? 'Peringatan Anggaran: $categoryName'
        : 'Peringatan Batas Anggaran';
    final body = showDetails
        ? 'Pengeluaran kategori $categoryName mencapai ${percentSpent.toStringAsFixed(0)}% dari batas bulanan.'
        : 'Salah satu kategori anggaran telah mencapai ${percentSpent.toStringAsFixed(0)}% batas bulanan.';

    await NotificationService.showNotification(
      id: id,
      title: title,
      body: body,
      channelId: NotificationService.channelBillId,
      channelName: NotificationService.channelBillName,
      channelDescription: NotificationService.channelBillDesc,
      payload: NotificationPayload(
        type: 'budget',
        targetTab: 2,
        uangSection: 'anggaran',
        itemId: budgetId,
      ),
    );
  }

  /// Peringatan anggaran 100% (Over-budget)
  static Future<void> showBudgetExceededNotification({
    required int id,
    required String categoryName,
    required double percentSpent,
    bool showDetails = false,
    String? budgetId,
  }) async {
    final title = showDetails
        ? 'Anggaran Terlampaui: $categoryName'
        : 'Batas Anggaran Terlampaui';
    final body = showDetails
        ? 'Pengeluaran kategori $categoryName (${percentSpent.toStringAsFixed(0)}%) melebihi batas bulanan.'
        : 'Pengeluaran pada salah satu kategori anggaran telah melebihi batas bulanan.';

    await NotificationService.showNotification(
      id: id,
      title: title,
      body: body,
      channelId: NotificationService.channelBillId,
      channelName: NotificationService.channelBillName,
      channelDescription: NotificationService.channelBillDesc,
      payload: NotificationPayload(
        type: 'budget',
        targetTab: 2,
        uangSection: 'anggaran',
        itemId: budgetId,
      ),
    );
  }
}
