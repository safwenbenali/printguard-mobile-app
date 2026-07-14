import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryDark = Color(0xFF1A237E);
  static const Color accent = Color(0xFFE53935);
  static const Color accentOrange = Color(0xFFFF8F00);
  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131929);
  static const Color surfaceLight = Color(0xFF1E2A45);
  static const Color textPrimary = Color(0xFFECEFF1);
  static const Color textSecondary = Color(0xFF90A4AE);
  static const Color textHint = Color(0xFF546E7A);
  static const Color stop = Color(0xFFE53935);
  static const Color notify = Color(0xFFFF8F00);
  static const Color ok = Color(0xFF43A047);
  static const Color online = Color(0xFF43A047);
  static const Color offline = Color(0xFFE53935);
  static const Color divider = Color(0xFF1E2A45);
}

class AppStrings {
  static const String appName = 'PrintGuard AI';
  static const String company = 'RCI3D';
  static const String tagline = 'AI-Powered 3D Print Defect Detection';
  static const List<String> defectClasses = ['spaghetti','warping','under_extrusion','stringing'];
  static const String defaultServerUrl = 'http://192.168.1.100:5000';
  static const String detectionsCollection = 'detections';
  static const String usersCollection = 'users';
  static const String keyServerUrl = 'server_url';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String detection = '/detection';
  static const String stream = '/stream';
  static const String notifications = '/notifications';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
  static const String detectionDetail = '/detection-detail';
}

class AlertLevel {
  static const String stop = 'STOP';
  static const String notify = 'NOTIFY';
  static const String ok = 'CONTINUE';
  static String fromConfidence(double confidence) {
    if (confidence >= 0.80) return stop;
    if (confidence >= 0.50) return notify;
    return ok;
  }
  static Color color(String level) {
    switch (level) {
      case stop: return AppColors.stop;
      case notify: return AppColors.notify;
      default: return AppColors.ok;
    }
  }
  static IconData icon(String level) {
    switch (level) {
      case stop: return Icons.cancel_rounded;
      case notify: return Icons.warning_rounded;
      default: return Icons.check_circle_rounded;
    }
  }
}

class DefectInfo {
  static IconData icon(String className) {
    switch (className.toLowerCase()) {
      case 'spaghetti': return Icons.layers_rounded;
      case 'warping': return Icons.open_with_rounded;
      case 'under_extrusion': return Icons.opacity_rounded;
      case 'stringing': return Icons.linear_scale_rounded;
      default: return Icons.warning_amber_rounded;
    }
  }
  static Color color(String className) {
    switch (className.toLowerCase()) {
      case 'spaghetti': return const Color(0xFFE53935);
      case 'warping': return const Color(0xFFFF8F00);
      case 'under_extrusion': return const Color(0xFF1565C0);
      case 'stringing': return const Color(0xFF6A1B9A);
      default: return AppColors.textSecondary;
    }
  }
  static String description(String className) {
    switch (className.toLowerCase()) {
      case 'spaghetti': return 'Filament extruded in mid-air, forming a tangled mass.';
      case 'warping': return 'Print corners lifting from the bed due to thermal stress.';
      case 'under_extrusion': return 'Insufficient filament causing gaps or weak structures.';
      case 'stringing': return 'Thin strands of filament between model sections.';
      default: return 'Unknown defect type.';
    }
  }
}