import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

void main() {
  group('Sapaan Waktu Asia/Jakarta (UTC+7)', () {
    test('Pagi 04.00 - 10.59', () {
      // 04:00 WIB = 21:00 UTC (previous day)
      final dt0400 = DateTime.utc(2026, 10, 31, 21, 0);
      expect(getGreeting(dt: dt0400), equals('Selamat Pagi'));

      // 08:30 WIB = 01:30 UTC
      final dt0830 = DateTime.utc(2026, 11, 1, 1, 30);
      expect(getGreeting(dt: dt0830), equals('Selamat Pagi'));

      // 10:59 WIB = 03:59 UTC
      final dt1059 = DateTime.utc(2026, 11, 1, 3, 59);
      expect(getGreeting(dt: dt1059), equals('Selamat Pagi'));
    });

    test('Siang 11.00 - 14.59', () {
      // 11:00 WIB = 04:00 UTC
      final dt1100 = DateTime.utc(2026, 11, 1, 4, 0);
      expect(getGreeting(dt: dt1100), equals('Selamat Siang'));

      // 14:59 WIB = 07:59 UTC
      final dt1459 = DateTime.utc(2026, 11, 1, 7, 59);
      expect(getGreeting(dt: dt1459), equals('Selamat Siang'));
    });

    test('Sore 15.00 - 17.59', () {
      // 15:00 WIB = 08:00 UTC
      final dt1500 = DateTime.utc(2026, 11, 1, 8, 0);
      expect(getGreeting(dt: dt1500), equals('Selamat Sore'));

      // 17:59 WIB = 10:59 UTC
      final dt1759 = DateTime.utc(2026, 11, 1, 10, 59);
      expect(getGreeting(dt: dt1759), equals('Selamat Sore'));
    });

    test('Malam 18.00 - 03.59', () {
      // 18:00 WIB = 11:00 UTC
      final dt1800 = DateTime.utc(2026, 11, 1, 11, 0);
      expect(getGreeting(dt: dt1800), equals('Selamat Malam'));

      // 23:30 WIB (batas hari) = 16:30 UTC
      final dt2330 = DateTime.utc(2026, 11, 1, 16, 30);
      expect(getGreeting(dt: dt2330), equals('Selamat Malam'));

      // 02:00 WIB = 19:00 UTC (previous day)
      final dt0200 = DateTime.utc(2026, 11, 1, 19, 0);
      expect(getGreeting(dt: dt0200), equals('Selamat Malam'));

      // 03:59 WIB = 20:59 UTC (previous day)
      final dt0359 = DateTime.utc(2026, 11, 1, 20, 59);
      expect(getGreeting(dt: dt0359), equals('Selamat Malam'));
    });
  });

  group('Format Header Grup Transaksi (Tanpa Jam & Batas Hari WIB)', () {
    test('Batas Hari 23.30 WIB vs 00.30 WIB', () {
      // Waktu acuan "sekarang" = 2026-10-31 23:45 WIB (16:45 UTC)
      final nowWib = DateTime.utc(2026, 10, 31, 16, 45);

      // Transaksi 23:30 WIB pada hari yang sama (16:30 UTC) -> Hari ini
      final tx2330 = DateTime.utc(2026, 10, 31, 16, 30);
      final res2330 = formatTransactionGroupDate(tx2330, now: nowWib);
      expect(res2330, equals('Hari ini'));
      expect(res2330.contains(':'), isFalse, reason: 'Header tidak boleh memuat jam');

      // Transaksi kemarin 22:00 WIB (2026-10-30 15:00 UTC) -> Kemarin
      final txKemarin = DateTime.utc(2026, 10, 30, 15, 0);
      final resKemarin = formatTransactionGroupDate(txKemarin, now: nowWib);
      expect(resKemarin, equals('Kemarin'));
      expect(resKemarin.contains(':'), isFalse);
    });

    test('Header tanggal lampau berformat singkatan tanpa jam (contoh: Sab, 31 Okt)', () {
      // Waktu acuan "sekarang" = 2026-11-10 10:00 WIB
      final nowWib = DateTime.utc(2026, 11, 10, 3, 0);

      // Transaksi Sabtu, 31 Oktober 2026 pukul 23:30 WIB
      final txOld = DateTime.utc(2026, 10, 31, 16, 30);
      final resOld = formatTransactionGroupDate(txOld, now: nowWib);
      expect(resOld, equals('Sab, 31 Okt'));
      expect(resOld.contains(':'), isFalse);
    });
  });
}
