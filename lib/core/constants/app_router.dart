import 'package:flutter/material.dart';
import '/features/auth/presentation/screens/splash_screen.dart';
import '/features/auth/presentation/screens/login_screen.dart';
import '/features/auth/presentation/screens/register_screen.dart';
import '/features/dashboard/presentation/screens/home_screen.dart';
import '/features/detection/presentation/screens/detection_screen.dart';
import '/features/stream/presentation/screens/stream_screen.dart';
import '/features/notifications/presentation/screens/notifications_screen.dart';
import '/features/statistics/presentation/screens/statistics_screen.dart';
import '/features/settings/presentation/screens/settings_screen.dart';
import '/features/assistant/presentation/screens/ai_assistant_screen.dart';
import '/core/models/detection_model.dart';
import 'app_constants.dart';


class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:        return _fade(const SplashScreen());
      case AppRoutes.login:         return _slide(const LoginScreen());
      case AppRoutes.register:      return _slide(const RegisterScreen());
      case AppRoutes.home:          return _fade(const HomeScreen());
      case AppRoutes.detection:     return _slide(const DetectionScreen());
      case AppRoutes.stream:        return _slide(const StreamScreen());
      case AppRoutes.notifications: return _slide(const NotificationsScreen());
      case AppRoutes.statistics:    return _slide(const StatisticsScreen());
      case AppRoutes.settings:      return _slide(const SettingsScreen());
      case AppRoutes.assistant:
        final record = settings.arguments as DetectionRecord;
        return _slide(AiAssistantScreen(record: record));
      default: return _fade(const SplashScreen());
    }
  }

  static PageRoute _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  static PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );
}