import 'package:flutter/material.dart';

class AppColors {
  // Primary purple palette
  static const Color primary = Color(0xFF7B1FA2);
  static const Color primaryDark = Color(0xFF4A148C);
  static const Color primaryLight = Color(0xFFAB47BC);
  static const Color accent = Color(0xFFCE93D8);
  static const Color purpleBlue = Color(0xFF5C6BC0);
  static const Color lavender = Color(0xFFF3E5F5);

  // Surfaces
  static const Color background = Color(0xFFF8F5FC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color white = Colors.white;

  // Text
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF6E6E8A);
  static const Color textLight = Color(0xFF9E9EAE);

  // Semantic
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color green = Color(0xFF66BB6A);
  static const Color blue = Color(0xFF42A5F5);
  static const Color orange = Color(0xFFFFA726);
  static const Color purple = Color(0xFF7B1FA2);
  static const Color teal = Color(0xFF26A69A);
  static const Color red = Color(0xFFEF5350);
  static const Color pink = Color(0xFFEC407A);

  // Legacy aliases
  static const Color secondary = Color(0xFFCE93D8);
  static const Color secondaryLight = Color(0xFFF3E5F5);

  // Gradients
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF4A148C), Color(0xFF5C6BC0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF5C6BC0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primary.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

class AppRadius {
  static const double card = 20;
  static const double button = 16;
  static const double input = 14;
  static const double header = 32;
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
  static const String received = 'Received';
  static const String pending = 'Pending';
  static const String cutting = 'Cutting';
  static const String stitching = 'Stitching';
  static const String finishing = 'Finishing';
  static const String ready = 'Ready';
  static const String delivered = 'Delivered';

  static const List<String> all = [
    received,
    cutting,
    stitching,
    finishing,
    ready,
    delivered,
  ];

  static Color colorFor(String status) {
    switch (status) {
      case received:
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
