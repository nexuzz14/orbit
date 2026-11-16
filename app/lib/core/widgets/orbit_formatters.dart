String formatRupiah(double value, {String currency = 'IDR'}) {
  final intVal = value.round().abs();
  final digits = intVal.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    buffer.write(digits[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buffer.write('.');
    }
  }
  final prefix = currency == 'IDR' ? 'Rp' : '$currency ';
  return '$prefix$buffer';
}

String getGreeting({DateTime? dt, int offsetHours = 7}) {
  final localDt = (dt ?? DateTime.now()).toUtc().add(Duration(hours: offsetHours));
  final hour = localDt.hour;
  if (hour >= 4 && hour < 11) return 'Selamat Pagi';
  if (hour >= 11 && hour < 15) return 'Selamat Siang';
  if (hour >= 15 && hour < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}

String formatTransactionGroupDateKey(String dateKey,
    {DateTime? now, int offsetHours = 7}) {
  const months = [
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
    'Des'
  ];
  const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  final parts = dateKey.split('-');
  if (parts.length != 3) return dateKey;
  final year = int.tryParse(parts[0]) ?? 1970;
  final month = int.tryParse(parts[1]) ?? 1;
  final day = int.tryParse(parts[2]) ?? 1;

  final ref = (now ?? DateTime.now()).toUtc().add(Duration(hours: offsetHours));
  final todayKey =
      '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-${ref.day.toString().padLeft(2, '0')}';
  final yesterday = ref.subtract(const Duration(days: 1));
  final yesterdayKey =
      '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

  if (dateKey == todayKey) return 'Hari ini';
  if (dateKey == yesterdayKey) return 'Kemarin';

  final targetDt = DateTime.utc(year, month, day);
  final dayName = days[targetDt.weekday % 7];
  final monthName = months[(month - 1).clamp(0, 11)];

  if (year != ref.year) {
    return '$dayName, $day $monthName $year';
  }
  return '$dayName, $day $monthName';
}

String formatTransactionGroupDate(DateTime date,
    {DateTime? now, int offsetHours = 7}) {
  final target = date.toUtc().add(Duration(hours: offsetHours));
  final key =
      '${target.year.toString().padLeft(4, '0')}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
  return formatTransactionGroupDateKey(key, now: now, offsetHours: offsetHours);
}

String formatDateIndoShort(DateTime date) {
  const months = [
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
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  final dayName = days[(date.weekday - 1).clamp(0, 6)];
  final monthName = months[(date.month - 1).clamp(0, 11)];
  return '$dayName, ${date.day} $monthName ${date.year}';
}
