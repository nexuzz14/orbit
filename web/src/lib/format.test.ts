import test from 'node:test';
import assert from 'node:assert/strict';
import {
  getGreeting,
  getDateKeyInTimezone,
  formatTransactionGroupDate,
  formatDateIndo,
  formatDateOnly,
} from './format';

test('Sapaan Waktu Asia/Jakarta (UTC+7)', () => {
  // Pagi: 04.00 - 10.59
  assert.equal(getGreeting(new Date('2026-10-31T21:00:00Z')), 'Selamat Pagi'); // 04:00 WIB
  assert.equal(getGreeting(new Date('2026-11-01T01:30:00Z')), 'Selamat Pagi'); // 08:30 WIB
  assert.equal(getGreeting(new Date('2026-11-01T03:59:00Z')), 'Selamat Pagi'); // 10:59 WIB

  // Siang: 11.00 - 14.59
  assert.equal(getGreeting(new Date('2026-11-01T04:00:00Z')), 'Selamat Siang'); // 11:00 WIB
  assert.equal(getGreeting(new Date('2026-11-01T07:59:00Z')), 'Selamat Siang'); // 14:59 WIB

  // Sore: 15.00 - 17.59
  assert.equal(getGreeting(new Date('2026-11-01T08:00:00Z')), 'Selamat Sore'); // 15:00 WIB
  assert.equal(getGreeting(new Date('2026-11-01T10:59:00Z')), 'Selamat Sore'); // 17:59 WIB

  // Malam: 18.00 - 03.59
  assert.equal(getGreeting(new Date('2026-11-01T11:00:00Z')), 'Selamat Malam'); // 18:00 WIB
  assert.equal(getGreeting(new Date('2026-11-01T16:30:00Z')), 'Selamat Malam'); // 23:30 WIB (batas malam)
  assert.equal(getGreeting(new Date('2026-11-01T19:00:00Z')), 'Selamat Malam'); // 02:00 WIB
  assert.equal(getGreeting(new Date('2026-11-01T20:59:00Z')), 'Selamat Malam'); // 03:59 WIB
});

test('Format Header Grup Transaksi dan Batas Hari WIB (23.30 WIB)', () => {
  // Waktu acuan: 31 Oktober 2026 pukul 23:45 WIB (16:45 UTC)
  const now = new Date('2026-10-31T16:45:00Z');

  // Transaksi pada 31 Oktober 2026 pukul 23:30 WIB (16:30 UTC)
  const tx2330 = '2026-10-31T16:30:00Z';
  const key2330 = getDateKeyInTimezone(tx2330);
  assert.equal(key2330, '2026-10-31', 'Transaksi 23:30 WIB harus masuk ke tanggal 2026-10-31');

  const header2330 = formatTransactionGroupDate(key2330, now);
  assert.equal(header2330, 'Hari ini');
  assert.equal(header2330.includes(':'), false, 'Header grup transaksi tidak boleh memuat jam');

  // Transaksi kemarin: 30 Oktober 2026 pukul 22:00 WIB (15:00 UTC)
  const txYesterday = '2026-10-30T15:00:00Z';
  const keyYesterday = getDateKeyInTimezone(txYesterday);
  assert.equal(keyYesterday, '2026-10-30');
  const headerYesterday = formatTransactionGroupDate(keyYesterday, now);
  assert.equal(headerYesterday, 'Kemarin');
  assert.equal(headerYesterday.includes(':'), false);

  // Transaksi lampau: Sabtu, 31 Oktober 2026 (dilihat dari 10 November 2026)
  const refLater = new Date('2026-11-10T03:00:00Z');
  const headerOld = formatTransactionGroupDate(key2330, refLater);
  assert.equal(headerOld, 'Sab, 31 Okt');
  assert.equal(headerOld.includes(':'), false, 'Header transaksi lampau tidak boleh memuat jam');
});
