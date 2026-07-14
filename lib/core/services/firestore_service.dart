import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../models/detection_model.dart';

/// ─────────────────────────────────────────────
///  Firestore Service — CRUD for detections
/// ─────────────────────────────────────────────
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _db = FirebaseFirestore.instance;
  final _log = Logger();

  CollectionReference<Map<String, dynamic>> get _detections =>
      _db.collection(AppStrings.detectionsCollection);

  // ── Write ─────────────────────────────────────

  /// Save a detection record; returns the generated Firestore ID.
  Future<String?> saveDetection(DetectionRecord record) async {
    try {
      final doc = await _detections.add(record.toFirestore());
      _log.i('Detection saved: ${doc.id}');
      return doc.id;
    } catch (e) {
      _log.e('Failed to save detection: $e');
      return null;
    }
  }

  /// Mark a single detection as read.
  Future<void> markAsRead(String docId) async {
    try {
      await _detections.doc(docId).update({'status': 'read'});
    } catch (e) {
      _log.w('Failed to mark $docId as read: $e');
    }
  }

  /// Mark all unread detections for a user as read.
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _db.batch();
      final unread = await _detections
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'unread')
          .get();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
    } catch (e) {
      _log.e('Failed to mark all as read: $e');
    }
  }

  // ── Read ──────────────────────────────────────

  /// Stream of all detections for [userId], newest first.
  Stream<List<DetectionRecord>> detectionsStream(String userId) {
    return _detections
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) =>
            snap.docs.map(DetectionRecord.fromFirestore).toList());
  }

  /// One-time fetch for statistics computation.
  Future<List<DetectionRecord>> fetchDetections({
    required String userId,
    int limit = 500,
    String? filterClass,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _detections
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (filterClass != null) {
        q = q.where('class_name', isEqualTo: filterClass);
      }
      if (since != null) {
        q = q.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }

      final snap = await q.get();
      return snap.docs.map(DetectionRecord.fromFirestore).toList();
    } catch (e) {
      _log.e('Failed to fetch detections: $e');
      return [];
    }
  }

  /// Count of today's detections for [userId].
  Future<int> todayCount(String userId) async {
    final midnight = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    try {
      final snap = await _detections
          .where('user_id', isEqualTo: userId)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(midnight))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      _log.w('todayCount failed: $e');
      return 0;
    }
  }

  /// Count of unread detections for [userId].
  Future<int> unreadCount(String userId) async {
    try {
      final snap = await _detections
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'unread')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Compute stats from the last 30 days.
  Future<DetectionStats> getStats(String userId) async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final records = await fetchDetections(userId: userId, since: since);

    final byClass = <String, int>{};
    final byAlert = <String, int>{};
    final byDay = <String, int>{};

    for (final r in records) {
      byClass[r.className] = (byClass[r.className] ?? 0) + 1;
      byAlert[r.alertLevel] = (byAlert[r.alertLevel] ?? 0) + 1;

      final dayKey =
          '${r.timestamp.year}-${r.timestamp.month.toString().padLeft(2, '0')}-${r.timestamp.day.toString().padLeft(2, '0')}';
      byDay[dayKey] = (byDay[dayKey] ?? 0) + 1;
    }

    // Build last-7-days array with zero-fill
    final last7 = <DayCount>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      last7.add(DayCount(d, byDay[key] ?? 0));
    }

    return DetectionStats(
      total: records.length,
      byClass: byClass,
      byAlertLevel: byAlert,
      last7Days: last7,
    );
  }
}
