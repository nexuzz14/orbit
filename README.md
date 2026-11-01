# Orbit

Pusat kendali pribadi untuk uang, tugas, dan jadwal. Spesifikasi lengkap ada di [docs/PRD.md](docs/PRD.md) (versi 5).

## Struktur

| Folder | Isi |
| --- | --- |
| `supabase/` | Migrasi SQL, seed, uji pgTAP, Edge Functions |
| `web/` | Next.js (App Router, TypeScript, Tailwind) |
| `app/` | Flutter Android (`orbit_app`, `id.my.nabilcf.orbit`) |
| `packages/` | Kontrak bersama dan set uji |
| `docs/` | PRD, threat model, keputusan, runbook insiden |

## Status

Fase 1 (fondasi keuangan). Fase 2 belum dimulai.

## Menjalankan

Lihat `docs/decisions.md` untuk keputusan teknis dan `.env.example` di `web/` dan `supabase/` untuk variabel yang perlu diisi.

```
npx supabase start
npx supabase db reset
npx supabase test db
cd web && npm install && npm run dev
```
