import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF18332D);
  static const green = Color(0xFF246B56);
  static const cream = Color(0xFFF7F5EF);
  static const orange = Color(0xFFD8864B);
}

abstract final class AppCategories {
  static const all = 'الكل';
  static const values = [
    all,
    'مشروبات ساخنة',
    'قهوة',
    'مشروبات باردة',
    'عصائر',
    'شيشة',
    'سناكس',
    'حلويات',
    'أكلات',
  ];
}
