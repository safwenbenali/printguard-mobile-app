import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/chat_message.dart';
import '../models/detection_model.dart';
import 'api_service.dart';

class AiAssistantService {
  static final AiAssistantService _instance = AiAssistantService._internal();
  factory AiAssistantService() => _instance;
  AiAssistantService._internal();

  final _log = Logger();
  final _api = ApiService();

  Future<String> explainDetection(DetectionRecord record) async {
    try {
      final res = await _api.dio.post('/ai/explain', data: {
        'class_name': record.className,
        'confidence': record.confidenceScore * 100,
        'alert_level': record.alertLevel,
        'printer_name': record.printerName,
        'defect_count': record.boxes.length,
      });
      return (res.data as Map<String, dynamic>)['response'] as String?
          ?? 'Could not generate explanation.';
    } on DioException catch (e) {
      _log.e('explainDetection failed: $e');
      return 'Could not connect to AI server. Check your connection.';
    }
  }

  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    try {
      final messages = [
        ...history.map((m) => m.toApiFormat()),
        {'role': 'user', 'content': userMessage},
      ];
      final res = await _api.dio.post('/ai/chat', data: {'messages': messages});
      return (res.data as Map<String, dynamic>)['response'] as String?
          ?? 'No response received.';
    } on DioException catch (e) {
      _log.e('sendMessage failed: $e');
      return 'Connection error. Please try again.';
    }
  }
}