import 'package:flutter/material.dart';

class AppColors {
  // Warna utama
  static const Color primary = Color(0xFF0284C7);

  // Warna semantik keuangan
  static const Color income = Color(0xFF15803D);
  static const Color expense = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // Warna tetap per jenis kegiatan (PRD Bagian 5)
  // Selalu disertai label teks atau ikon agar tidak bergantung pada warna semata.
  static const Color kindIntern = Color(0xFF0284C7);
  static const Color kindFreelance = Color(0xFF7C3AED);
  static const Color kindKuliah = Color(0xFF4338CA);
  static const Color kindPribadi = Color(0xFF64748B);

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
