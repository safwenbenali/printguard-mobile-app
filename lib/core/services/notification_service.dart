import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/detection_model.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized at this point via main()
  final notifService = NotificationService();
  await notifService.init();
  notifService.showLocalNotification(
    title: message.notification?.title ?? 'PrintGuard Alert',
    body: message.notification?.body ?? '',
    payload: message.data['detection_id'] as String?,
  );
}

/// ─────────────────────────────────────────────
///  Notification Service — FCM + local
/// ─────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();
  final _log = Logger();

  bool _initialized = false;

  static const _channelId = 'printguard_alerts';
  static const _channelName = 'PrintGuard Alerts';
  static const _channelDesc = 'Notifications for 3D print defect detection';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Android channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request FCM permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground FCM messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

    _log.i('NotificationService initialized');
  }

  void _onForegroundMessage(RemoteMessage message) {
    _log.d('FCM foreground: ${message.messageId}');
    showLocalNotification(
      title: message.notification?.title ?? 'PrintGuard Alert',
      body: message.notification?.body ?? '',
      payload: message.data['detection_id'] as String?,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // TODO: navigate to detection detail using the payload (detection_id)
    _log.d('Notification tapped. Payload: ${response.payload}');
  }

  void _onNotificationOpenedApp(RemoteMessage message) {
    _log.d('App opened from notification: ${message.messageId}');
  }

  /// Show a local notification immediately (foreground or background).
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Check if notifications are enabled in settings
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(AppStrings.keyNotificationsEnabled) ?? true;
    if (!enabled) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: AppColors.accent,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Trigger a notification for a new detection (called after saving to Firestore).
  Future<void> notifyDetection(DetectionRecord record) async {
    if (record.confidenceScore < 0.50) return; // only NOTIFY / STOP levels

    final emoji = record.alertLevel == AlertLevel.stop ? '🛑' : '⚠️';
    await showLocalNotification(
      title: '$emoji Defect Detected: ${record.className}',
      body:
          'Confidence: ${record.confidencePercent} — ${record.alertLevel}',
      payload: record.id,
    );
  }

  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      _log.w('Could not get FCM token: $e');
      return null;
    }
  }
}
