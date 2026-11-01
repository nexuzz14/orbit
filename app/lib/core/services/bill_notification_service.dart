import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class BillNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static const _billChannel = AndroidNotificationDetails(
    'orbit_bill_channel',
    'Orbit Pengingat Tagihan & Anggaran',
    channelDescription: 'Pengingat tagihan jatuh tempo dan peringatan batas anggaran',
    importance: Importance.high,
    priority: Priority.high,
  );

  // Pengingat tagihan jatuh tempo (H-3 atau Hari-H)
  static Future<void> showBillDueNotification({
    required int id,
    required String billName,
    required double amount,
    required int daysLeft,
  }) async {
    final formattedAmount = _currencyFormat.format(amount);
    final title = daysLeft == 0
        ? 'Tagihan Jatuh Tempo Hari Ini'
        : 'Pengingat Tagihan (H-$daysLeft)';

    final body = daysLeft == 0
        ? 'Tagihan $billName sebesar $formattedAmount jatuh tempo hari ini.'
        : 'Tagihan $billName sebesar $formattedAmount akan jatuh tempo dalam $daysLeft hari.';

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _billChannel),
    );
  }

  // Peringatan anggaran 80%
  static Future<void> showBudgetWarningNotification({
    required int id,
    required String categoryName,
    required double percentSpent,
  }) async {
    final title = 'Peringatan Anggaran: $categoryName';
    final body =
        'Pengeluaran kategori $categoryName telah mencapai ${percentSpent.toStringAsFixed(1)}% dari batas anggaran bulanan.';

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _billChannel),
    );
  }

  // Peringatan anggaran 100% (Over-budget)
  static Future<void> showBudgetExceededNotification({
    required int id,
    required String categoryName,
    required double percentSpent,
  }) async {
    final title = 'Anggaran Terlampaui: $categoryName';
    final body =
        'Pengeluaran kategori $categoryName (${percentSpent.toStringAsFixed(1)}%) telah melebihi batas anggaran yang ditentukan.';

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _billChannel),
    );
  }
}
