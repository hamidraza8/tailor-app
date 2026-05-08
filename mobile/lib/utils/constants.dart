import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF00695C);
  static const Color secondary = Color(0xFFE91E63);
  static const Color secondaryLight = Color(0xFFF48FB1);
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBg = Color(0xFFF5F5F5);
  static const Color white = Colors.white;
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF616161);
  static const Color textLight = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color green = Color(0xFF43A047);
  static const Color blue = Color(0xFF1E88E5);
  static const Color orange = Color(0xFFF57C00);
  static const Color purple = Color(0xFF8E24AA);
  static const Color teal = Color(0xFF00897B);
  static const Color red = Color(0xFFE53935);
}

class ApiConfig {
  static String baseUrl = 'https://torin.pk/api';
  static const Duration timeout = Duration(seconds: 30);
}

class OrderTypes {
  static const List<Map<String, dynamic>> types = [
    {'id': 'suit', 'name': 'Suit', 'urdu': 'سوٹ', 'icon': Icons.checkroom},
    {'id': 'kurti', 'name': 'Kurti', 'urdu': 'کرتی', 'icon': Icons.dry_cleaning},
    {'id': 'trouser', 'name': 'Trouser', 'urdu': 'ٹراؤزر', 'icon': Icons.straighten},
    {'id': 'frock', 'name': 'Frock', 'urdu': 'فراک', 'icon': Icons.woman},
    {'id': 'abaya', 'name': 'Abaya', 'urdu': 'عبایہ', 'icon': Icons.accessibility_new},
    {'id': 'alteration', 'name': 'Alteration', 'urdu': 'مرمت', 'icon': Icons.build},
  ];
}

class OrderStatus {
  static const String pending = 'Pending';
  static const String cutting = 'Cutting';
  static const String stitching = 'Stitching';
  static const String finishing = 'Finishing';
  static const String ready = 'Ready';
  static const String delivered = 'Delivered';

  static const List<String> all = [
    pending,
    cutting,
    stitching,
    finishing,
    ready,
    delivered,
  ];

  static Color colorFor(String status) {
    switch (status) {
      case pending:
        return AppColors.warning;
      case cutting:
        return AppColors.blue;
      case stitching:
        return AppColors.purple;
      case finishing:
        return AppColors.orange;
      case ready:
        return AppColors.success;
      case delivered:
        return AppColors.textLight;
      default:
        return AppColors.textMedium;
    }
  }
}

class PaymentMethods {
  static const List<String> methods = [
    'Cash',
    'JazzCash',
    'EasyPaisa',
    'Bank Transfer',
  ];
}

class AssetTypes {
  static const List<String> types = [
    'Sewing Machine',
    'Overlock Machine',
    'Iron / Press',
    'Cutting Table',
    'Mannequin',
    'Furniture',
    'Computer / Device',
    'Other',
  ];
}
