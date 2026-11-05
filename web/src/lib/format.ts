// Format angka dan tanggal sesuai Panduan Gaya Orbit (PRD Bagian 5)

export function formatCurrency(amount: number, currency = 'IDR'): string {
  if (currency === 'IDR') {
    const rounded = Math.round(amount);
    const formatted = new Intl.NumberFormat('id-ID').format(Math.abs(rounded));
    const prefix = amount < 0 ? '-Rp ' : 'Rp ';
    return `${prefix}${formatted}`;
  }

  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

/**
 * Mendapatkan sapaan berdasarkan waktu lokal profil (default: Asia/Jakarta).
 * Aturan jam lokal:
 * - Pagi: 04.00 - 10.59
 * - Siang: 11.00 - 14.59
 * - Sore: 15.00 - 17.59
 * - Malam: 18.00 - 03.59
 */
export function getGreeting(date: Date = new Date(), timeZone = 'Asia/Jakarta'): string {
  const formatter = new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    hour12: false,
    timeZone,
  });
  const hour = parseInt(formatter.format(date), 10);

  if (hour >= 4 && hour < 11) return 'Selamat Pagi';
  if (hour >= 11 && hour < 15) return 'Selamat Siang';
  if (hour >= 15 && hour < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}

/**
 * Mendapatkan kunci tanggal (YYYY-MM-DD) berdasarkan zona waktu lokal profil (Asia/Jakarta).
 * Memastikan transaksi malam hari (misal 23:30 WIB) tidak meleset ke tanggal berikutnya/sebelumnya karena UTC.
 */
export function getDateKeyInTimezone(dateInput: string | Date, timeZone = 'Asia/Jakarta'): string {
  const d = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
  if (isNaN(d.getTime())) return '';
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(d);
}

/**
 * Header grup transaksi: HANYA tanggal (Hari ini, Kemarin, atau "Sab, 31 Okt"), tanpa jam.
 * Memakai zona waktu profil (Asia/Jakarta) dan mendukung uji batas hari.
 */
export function formatTransactionGroupDate(
  dateInput: string | Date,
  timeZoneOrNow?: string | Date,
  referenceNow?: Date
): string {
  let timeZone = 'Asia/Jakarta';
  let refNow = referenceNow || new Date();

  if (timeZoneOrNow instanceof Date) {
    refNow = timeZoneOrNow;
  } else if (typeof timeZoneOrNow === 'string') {
    timeZone = timeZoneOrNow;
  }

  const targetKey =
    typeof dateInput === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(dateInput)
      ? dateInput
      : getDateKeyInTimezone(dateInput, timeZone);

  if (!targetKey) return '';

  const todayKey = getDateKeyInTimezone(refNow, timeZone);

  // Menghitung tanggal kemarin dalam zona waktu profil
  const yesterdayRef = new Date(refNow.getTime() - 24 * 60 * 60 * 1000);
  const yesterdayKey = getDateKeyInTimezone(yesterdayRef, timeZone);

  if (targetKey === todayKey) return 'Hari ini';
  if (targetKey === yesterdayKey) return 'Kemarin';

  // Parse target key YYYY-MM-DD
  const [yStr, mStr, dStr] = targetKey.split('-');
  const year = parseInt(yStr, 10);
  const monthIdx = parseInt(mStr, 10) - 1;
  const day = parseInt(dStr, 10);

  // Dapatkan nama hari dalam zona waktu target
  const d = new Date(Date.UTC(year, monthIdx, day, 12, 0, 0));
  const daysShort = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  const monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  const dayOfWeek = d.getUTCDay();
  const dayName = daysShort[dayOfWeek];
  const monthName = monthsShort[monthIdx];

  const nowYear = parseInt(todayKey.split('-')[0], 10);
  if (year !== nowYear) {
    return `${dayName}, ${day} ${monthName} ${year}`;
  }
  return `${dayName}, ${day} ${monthName}`;
}

export function formatDateIndo(dateStr: string, timeZone = 'Asia/Jakarta'): string {
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return dateStr;

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });

  const parts = formatter.formatToParts(d);
  const partMap: Record<string, string> = {};
  for (const p of parts) {
    partMap[p.type] = p.value;
  }

  const day = parseInt(partMap['day'] || '1', 10);
  const monthIdx = parseInt(partMap['month'] || '1', 10) - 1;
  const month = months[monthIdx] || '';
  const year = partMap['year'] || '';
  const hours = partMap['hour'] || '00';
  const minutes = partMap['minute'] || '00';

  return `${day} ${month} ${year}, ${hours}:${minutes}`;
}

export function formatDateOnly(dateStr: string, timeZone = 'Asia/Jakarta'): string {
  const key = getDateKeyInTimezone(dateStr, timeZone);
  if (!key) return dateStr;

  const [yStr, mStr, dStr] = key.split('-');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  const day = parseInt(dStr, 10);
  const month = months[parseInt(mStr, 10) - 1] || '';
  const year = yStr;

  return `${day} ${month} ${year}`;
}
