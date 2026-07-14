enum DetectionVerdict { authentic, suspicious, forged }

extension DetectionVerdictX on DetectionVerdict {
  String get label {
    switch (this) {
      case DetectionVerdict.authentic:
        return 'Authentic';
      case DetectionVerdict.suspicious:
        return 'Suspicious';
      case DetectionVerdict.forged:
        return 'Likely Forged';
    }
  }

  static DetectionVerdict fromString(String value) {
    switch (value) {
      case 'authentic':
        return DetectionVerdict.authentic;
      case 'suspicious':
        return DetectionVerdict.suspicious;
      case 'forged':
        return DetectionVerdict.forged;
      default:
        return DetectionVerdict.suspicious;
    }
  }

  String get storageValue {
    switch (this) {
      case DetectionVerdict.authentic:
        return 'authentic';
      case DetectionVerdict.suspicious:
        return 'suspicious';
      case DetectionVerdict.forged:
        return 'forged';
    }
  }
}

class DetectionRecord {
  final String id;
  final String userId;
  final String documentName;
  final DetectionVerdict verdict;
  final double confidenceScore; // 0-100
  final int textBlockCount;
  final double fontConsistencyScore; // 0-100
  final String extractedTextPreview;
  final DateTime scannedAt;

  DetectionRecord({
    required this.id,
    required this.userId,
    required this.documentName,
    required this.verdict,
    required this.confidenceScore,
    required this.textBlockCount,
    required this.fontConsistencyScore,
    required this.extractedTextPreview,
    required this.scannedAt,
  });

  factory DetectionRecord.fromMap(String id, Map<String, dynamic> map) {
    return DetectionRecord(
      id: id,
      userId: map['userId'] as String? ?? '',
      documentName: map['documentName'] as String? ?? 'Untitled document',
      verdict: DetectionVerdictX.fromString(map['verdict'] as String? ?? 'suspicious'),
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      textBlockCount: (map['textBlockCount'] as num?)?.toInt() ?? 0,
      fontConsistencyScore: (map['fontConsistencyScore'] as num?)?.toDouble() ?? 0.0,
      extractedTextPreview: map['extractedTextPreview'] as String? ?? '',
      scannedAt: map['scannedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scannedAt'] as int)
          : DateTime.now(),
    );
  }
  

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'documentName': documentName,
      'verdict': verdict.storageValue,
      'confidenceScore': confidenceScore,
      'textBlockCount': textBlockCount,
      'fontConsistencyScore': fontConsistencyScore,
      'extractedTextPreview': extractedTextPreview,
      'scannedAt': scannedAt.millisecondsSinceEpoch,
    };
  }
}
