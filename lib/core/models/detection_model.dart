import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printguard2/core/constants/app_constants.dart';

class BoundingBox {
  final String className;
  final double confidence;
  final double x1, y1, x2, y2;

  const BoundingBox({
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
  // Try 'class' first, then 'class_name', fallback to 'unknown'
  String className = json['class']?.toString() ?? 
                     json['class_name']?.toString() ?? 
                     'unknown';
  
  return BoundingBox(
    className: className,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    x1: (json['x1'] as num?)?.toDouble() ?? 0,
    y1: (json['y1'] as num?)?.toDouble() ?? 0,
    x2: (json['x2'] as num?)?.toDouble() ?? 0,
    y2: (json['y2'] as num?)?.toDouble() ?? 0,
  );
}

  Map<String, dynamic> toMap() => {
    'class_name': className,
    'confidence': confidence,
    'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
  };
}

class DetectionRecord {
  final String? id;
  final String userId;
  final String className;
  final double confidenceScore; // 0.0 – 1.0
  final String alertLevel;
  final List<BoundingBox> boxes;
  final String? imageUrl;
  final DateTime timestamp;
  final String status; // 'unread' | 'read'
  final String? printerName;
  final String? rootCause;
  final String? suggestedFix;
  final String? urgencyLevel;

  const DetectionRecord({
    this.id,
    required this.userId,
    required this.className,
    required this.confidenceScore,
    required this.alertLevel,
    required this.boxes,
    this.imageUrl,
    required this.timestamp,
    this.status = 'unread',
    this.printerName,
    this.rootCause,
    this.suggestedFix,
    this.urgencyLevel,
  });

  bool get isRead => status == 'read';
  String get confidencePercent =>
      '${(confidenceScore * 100).toStringAsFixed(1)}%';

  DetectionRecord copyWith({String? id, String? status}) => DetectionRecord(
    id: id ?? this.id,
    userId: userId,
    className: className,
    confidenceScore: confidenceScore,
    alertLevel: alertLevel,
    boxes: boxes,
    imageUrl: imageUrl,
    timestamp: timestamp,
    status: status ?? this.status,
    printerName: printerName,
  );

  factory DetectionRecord.fromApiResponse({
    required Map<String, dynamic> json,
    required String userId,
    String? rootCause,
    String? suggestedFix,
    String? urgencyLevel,
  }) {
    final detections = (json['detections'] as List<dynamic>? ?? [])
        .map((d) => BoundingBox.fromJson(d as Map<String, dynamic>))
        .toList();

    // Pick the highest-confidence detection as the primary class
    double maxConf = 0;
    String topClass = 'none';
    for (final b in detections) {
      if (b.confidence > maxConf) {
        maxConf = b.confidence;
        topClass = b.className;
      }
    }

    return DetectionRecord(
      userId: userId,
      className: topClass,
      confidenceScore: maxConf,
      alertLevel: AlertLevel.fromConfidence(maxConf),
      boxes: detections,
      imageUrl: json['annotated_image'] as String?,
      timestamp: DateTime.now(),
      rootCause: rootCause,
      suggestedFix: suggestedFix,
      urgencyLevel: urgencyLevel,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'class_name': className,
    'confidence_score': confidenceScore,
    'alert_level': alertLevel,
    'boxes': boxes.map((b) => b.toMap()).toList(),
    'image_url': imageUrl,
    'timestamp': Timestamp.fromDate(timestamp),
    'status': status,
    'printer_name': printerName,
    'root_cause': rootCause,
    'suggested_fix': suggestedFix,
    'urgency_level': urgencyLevel,
  };

  static DetectionRecord fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DetectionRecord(
      id: doc.id,
      userId: d['user_id'] as String? ?? '',
      className: d['class_name'] as String? ?? 'unknown',
      confidenceScore: (d['confidence_score'] as num?)?.toDouble() ?? 0.0,
      alertLevel: d['alert_level'] as String? ?? 'CONTINUE',
      boxes: (d['boxes'] as List<dynamic>? ?? [])
          .map((b) => BoundingBox.fromJson(b as Map<String, dynamic>))
          .toList(),
      imageUrl: d['image_url'] as String?,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'unread',
      printerName: d['printer_name'] as String?,
      rootCause: d['root_cause'] as String?,
      suggestedFix: d['suggested_fix'] as String?,
      urgencyLevel: d['urgency_level'] as String?,
    );
  }
}

class DetectionStats {
  final int total;
  final Map<String, int> byClass;
  final Map<String, int> byAlertLevel;
  final List<DayCount> last7Days;

  const DetectionStats({
    required this.total,
    required this.byClass,
    required this.byAlertLevel,
    required this.last7Days,
  });
}

class DayCount {
  final DateTime date;
  final int count;
  const DayCount(this.date, this.count);
}