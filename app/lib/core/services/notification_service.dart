import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Navigasi atau respon saat notifikasi ditekan
      },
    );
  }

  // Tampilkan notifikasi instan
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'orbit_general_channel',
      'Orbit Notifikasi Umum',
      channelDescription: 'Pengingat jadwal, tugas, dan ringkasan harian Orbit',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // Ringkasan pagi (PRD M10c: berisi jumlah jadwal, tugas, dan tenggat hari itu)
  static Future<void> showMorningSummary({
    required int eventCount,
    required int taskCount,
  }) async {
    final body = 'Hari ini Anda memiliki $eventCount jadwal kegiatan dan $taskCount tugas aktif.';
    await showNotification(
      id: 9999,
      title: 'Orbit: Ringkasan Hari Ini',
      body: body,
    );
  }
}
