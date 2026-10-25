import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

// ── FIXED: ServerStatus with cameraConnected ──────────────────────
class ServerStatus {
  final bool modelLoaded;
  final bool cameraConnected;  // ← ADDED: missing field
  final int totalDetections;   // ← ADDED: useful for status display
  final String? lastDetection; // ← ADDED: timestamp of last detection
  final String serverVersion;

  ServerStatus({
    required this.modelLoaded,
    required this.cameraConnected,
    required this.totalDetections,
    this.lastDetection,
    required this.serverVersion,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    return ServerStatus(
      modelLoaded: json['model_loaded'] as bool? ??
          json['modelLoaded'] as bool? ??
          false,
      cameraConnected: json['camera_connected'] as bool? ??
          json['cameraConnected'] as bool? ??
          false,
      totalDetections: json['total_detections'] as int? ??
          json['totalDetections'] as int? ??
          0,
      lastDetection: json['last_detection'] as String? ??
          json['lastDetection'] as String?,
      serverVersion: json['version'] as String? ??
          json['server_version'] as String? ??
          json['serverVersion'] as String? ??
          'N/A',
    );
  }

  factory ServerStatus.offline() => ServerStatus(
        modelLoaded: false,
        cameraConnected: false,
        totalDetections: 0,
        lastDetection: null,
        serverVersion: 'N/A',
      );

  Map<String, dynamic> toJson() => {
        'model_loaded': modelLoaded,
        'camera_connected': cameraConnected,
        'total_detections': totalDetections,
        'last_detection': lastDetection,
        'version': serverVersion,
      };
}

/// ─────────────────────────────────────────────
///  API Service — communicates with Flask server
/// ─────────────────────────────────────────────
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // Build Dio with the default URL so _dio is never uninitialized
  ApiService._internal() {
    _buildDio();
  }

  final _log = Logger();

  late Dio _dio;
  String _baseUrl = AppStrings.defaultServerUrl;

  /// Call this once on app start (or after user changes URL in settings).
  /// Loads the saved URL from SharedPreferences and rebuilds Dio.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl =
        prefs.getString(AppStrings.keyServerUrl) ?? AppStrings.defaultServerUrl;
    _buildDio();
    _log.i('✅ ApiService initialized with baseUrl: $_baseUrl');
  }

  void _buildDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => _log.d(obj),
      ),
    );
  }

  /// Update server URL at runtime (from Settings screen).
  Future<void> updateBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStrings.keyServerUrl, url);
    _buildDio();
    _log.i('✅ Base URL updated to: $url');
  }

  String get currentBaseUrl => _baseUrl;
  Dio get dio => _dio;

  // ── Endpoints ────────────────────────────────

  /// GET /status → server & model health.
  Future<ServerStatus> getStatus() async {
    try {
      final res = await _dio.get('/status');
      _log.d('📡 GET /status response: ${res.data}');
      return ServerStatus.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _log.w('GET /status failed: $e');
      return ServerStatus.offline();
    } catch (e) {
      _log.w('GET /status error: $e');
      return ServerStatus.offline();
    }
  }

  /// POST /upload_raw — send image file, receive detection results.
  Future<Map<String, dynamic>?> uploadImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final res = await _dio.post(
        '/upload_raw',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      // Ensure detection_id is captured
      final data = res.data as Map<String, dynamic>;
      if (data['detection_id'] == null) {
        // If server doesn't return detection_id, generate one
        data['detection_id'] = DateTime.now().millisecondsSinceEpoch.toString();
        _log.w('⚠️ Server did not return detection_id, generated one: ${data['detection_id']}');
      }
      
      return data;
    } on DioException catch (e) {
      _log.e('POST /upload_raw failed: $e');
      return null;
    }
  }

  /// POST /upload_raw — send raw bytes (e.g., from image_picker).
  Future<Map<String, dynamic>?> uploadImageBytes(
    Uint8List bytes, {
    String filename = 'capture.jpg',
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final res = await _dio.post(
        '/upload_raw',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      final data = res.data as Map<String, dynamic>;
      if (data['detection_id'] == null) {
        data['detection_id'] = DateTime.now().millisecondsSinceEpoch.toString();
        _log.w('⚠️ Server did not return detection_id, generated one: ${data['detection_id']}');
      }
      
      return data;
    } on DioException catch (e) {
      _log.e('POST /upload_raw bytes failed: $e');
      return null;
    }
  }

  /// GET /detect → latest detection without sending an image.
  Future<Map<String, dynamic>?> getLatestDetection() async {
    try {
      final res = await _dio.get('/detect');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log.w('GET /detect failed: $e');
      return null;
    }
  }

  /// POST /alert — mark an alert as read on the server side.
  Future<bool> markAlertRead(String detectionId) async {
    try {
      await _dio.post('/alert', data: {'detection_id': detectionId});
      return true;
    } on DioException catch (e) {
      _log.w('POST /alert failed: $e');
      return false;
    }
  }

  // ── AI Assistant Endpoints ──────────────────────────────────────

  /// POST /ai/chat — send chat messages to AI
  Future<Map<String, dynamic>?> sendChatMessage({
    required List<Map<String, String>> messages,
    String system = 'You are a helpful 3D printing assistant.',
  }) async {
    try {
      final res = await _dio.post(
        '/ai/chat',
        data: {
          'messages': messages,
          'system': system,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log.e('POST /ai/chat failed: $e');
      return {'error': e.message, 'status': 'error'};
    }
  }

  /// POST /ai/explain — get explanation for a detection
  Future<Map<String, dynamic>?> explainDetection({
    required String className,
    required double confidence,
    required String alertLevel,
    required String printerName,
    required int defectCount,
  }) async {
    try {
      final res = await _dio.post(
        '/ai/explain',
        data: {
          'class_name': className,
          'confidence': confidence,
          'alert_level': alertLevel,
          'printer_name': printerName,
          'defect_count': defectCount,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _log.e('POST /ai/explain failed: $e');
      return {'error': e.message, 'status': 'error'};
    }
  }

  /// Build the MJPEG stream URL (for MjpegWidget).
  String get streamUrl => '$_baseUrl/stream';

  /// Ping server, returns true if reachable.
  Future<bool> isReachable() async {
    try {
      final status = await getStatus();
      return status.modelLoaded || status.serverVersion != 'N/A';
    } catch (_) {
      return false;
    }
  }
  /// POST /recommend — get proactive recommendation from Grok
  Future<Map<String, String>?> getRecommendation({
    required String className,
    required double confidence,
    String? imageBase64,
  }) async {
    try {
      _log.i('📤 Calling /recommend with: className=$className, confidence=$confidence');

      final res = await _dio.post(
        '/recommend',
        data: {
          'class_name': className,
          'confidence': confidence,
          'image_base64': imageBase64 ?? '',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      // ── DEBUG: Print raw response ──
      _log.i('📥 Raw recommendation response: ${res.data}');

      final data = res.data as Map<String, dynamic>;

      // ── Try multiple field names ──
      final rootCause = data['root_cause'] ?? data['rootCause'] ?? 'No root cause available';
      final suggestedFix = data['suggested_fix'] ?? data['suggestedFix'] ?? 'No fix available';
      final urgencyLevel = data['urgency_level'] ?? data['urgencyLevel'] ?? 'NOTIFY';

      _log.i('✅ Parsed: rootCause=$rootCause, suggestedFix=$suggestedFix, urgencyLevel=$urgencyLevel');

      return {
        'rootCause': rootCause.toString(),
        'suggestedFix': suggestedFix.toString(),
        'urgencyLevel': urgencyLevel.toString(),
      };
    } on DioException catch (e) {
      _log.e('POST /recommend failed: $e');
      return {
        'rootCause': 'Network error. Please try again.',
        'suggestedFix': 'Check your server connection.',
        'urgencyLevel': 'NOTIFY',
      };
    } catch (e) {
      _log.e('Unexpected error in /recommend: $e');
      return {
        'rootCause': 'Unexpected error occurred.',
        'suggestedFix': 'Check server logs.',
        'urgencyLevel': 'NOTIFY',
      };
    }
  }
  
}