import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ServerStatus {
  final bool modelLoaded;
  final String serverVersion;

  ServerStatus({required this.modelLoaded, required this.serverVersion});

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    return ServerStatus(
      modelLoaded: json['model_loaded'] as bool? ??
          json['modelLoaded'] as bool? ??
          false,
      serverVersion: json['server_version'] as String? ??
          json['serverVersion'] as String? ??
          'N/A',
    );
  }

  factory ServerStatus.offline() =>
      ServerStatus(modelLoaded: false, serverVersion: 'N/A');
}

/// ─────────────────────────────────────────────
///  API Service — communicates with Flask server
/// ─────────────────────────────────────────────
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _log = Logger();

  late Dio _dio;
  String _baseUrl = AppStrings.defaultServerUrl;

  /// Call this once on app start (or after user changes URL in settings).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl =
        prefs.getString(AppStrings.keyServerUrl) ?? AppStrings.defaultServerUrl;
    _buildDio();
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
  }

  String get currentBaseUrl => _baseUrl;

  // ── Endpoints ────────────────────────────────

  /// GET /status → server & model health.
  Future<ServerStatus> getStatus() async {
    try {
      final res = await _dio.get('/status');
      return ServerStatus.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _log.w('GET /status failed: $e');
      return ServerStatus.offline();
    } catch (e) {
      return ServerStatus.offline();
    }
  }

  /// POST /upload_raw — send image file, receive detection results.
  ///
  /// Returns the raw response map (detections list + annotated_image).
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
      return res.data as Map<String, dynamic>;
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
      return res.data as Map<String, dynamic>;
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

  /// Build the MJPEG stream URL (for MjpegWidget).
  String get streamUrl => '$_baseUrl/stream';

  /// Ping server, returns true if reachable.
  Future<bool> isReachable() async {
    try {
      final status = await getStatus();
      return status.modelLoaded ||
          status.serverVersion != 'N/A'; // server responded
    } catch (_) {
      return false;
    }
  }
}
