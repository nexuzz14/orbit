import 'package:flutter/material.dart';

class AppColors {
  // Warna utama brand Orbit (Cyan -> Indigo -> Violet)
  static const Color primary = Color(0xFF6366F1);
  static const Color brandCyan = Color(0xFF0EA5E9);
  static const Color brandIndigo = Color(0xFF6366F1);
  static const Color brandViolet = Color(0xFF8B5CF6);

  // Latar belakang & kartu mode gelap (Obsidian Space)
  static const Color darkBackground = Color(0xFF060913);
  static const Color darkSurface = Color(0xFF0D1322);
  static const Color darkBorder = Color(0xFF1E293B);

  // Latar belakang & kartu mode terang
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Gradien utama Orbit
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandCyan, brandIndigo, brandViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Warna semantik keuangan
  static const Color income = Color(0xFF10B981);
  static const Color expense = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Warna tetap per jenis kegiatan (PRD Bagian 5)
  // Selalu disertai label teks atau ikon agar tidak bergantung pada warna semata.
  static const Color kindIntern = Color(0xFF0EA5E9);
  static const Color kindFreelance = Color(0xFF8B5CF6);
  static const Color kindKuliah = Color(0xFFF59E0B);
  static const Color kindPribadi = Color(0xFF10B981);

  static Color getKindColor(String kind) {
    switch (kind.toLowerCase()) {
      case 'intern':
        return kindIntern;
      case 'freelance':
        return kindFreelance;
      case 'kuliah':
        return kindKuliah;
      case 'pribadi':
      default:
        return kindPribadi;
    }
  }

  static String getKindLabel(String kind) {
    switch (kind.toLowerCase()) {
      case 'intern':
        return 'Magang';
      case 'freelance':
        return 'Proyek';
      case 'kuliah':
        return 'Mata Kuliah';
      case 'pribadi':
      default:
        return 'Kegiatan';
    }
  }
}
