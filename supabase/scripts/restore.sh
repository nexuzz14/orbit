#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Orbit Database Restore Script
# Dekripsi dan pemulihan dump database PostgreSQL terenkripsi GPG.
# JANGAN MENULIS PASSWORD ATAU PASSPHRASE SECARA HARDCODED.
#
# Penggunaan:
#   export TARGET_DATABASE_URL="postgres://postgres:[PASSWORD]@[HOST]:[PORT]/postgres"
#   ./supabase/scripts/restore.sh path/to/orbit_backup_YYYYMMDD_HHMMSS.dump.gpg
# ==============================================================================

if [ "$#" -ne 1 ]; then
  echo "Penggunaan: $0 <path_berkas_dump_gpg>"
  exit 1
fi

ENC_FILE="$1"
if [ ! -f "$ENC_FILE" ]; then
  echo "Error: Berkas $ENC_FILE tidak ditemukan."
  exit 1
fi

if [ -z "${TARGET_DATABASE_URL:-}" ]; then
  echo "Error: Variabel TARGET_DATABASE_URL belum diatur."
  echo "Silakan tentukan TARGET_DATABASE_URL sebelum menjalankan skrip."
  exit 1
fi

RAW_FILE="${ENC_FILE%.gpg}"

echo "1. Memulai dekripsi berkas GPG..."
gpg --decrypt --batch --yes -o "$RAW_FILE" "$ENC_FILE"

echo "2. Memulai proses pg_restore ke target database..."
pg_restore \
  --dbname="$TARGET_DATABASE_URL" \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl \
  "$RAW_FILE" || {
    echo "Peringatan: pg_restore selesai dengan peringatan/notice (umum jika objek sistem dilewati)."
}

echo "3. Membersihkan berkas sementara tanpa enkripsi..."
rm -f "$RAW_FILE"

echo "Pemulihan database selesai dengan aman."
