import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/detection_model.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

// ── Singletons ────────────────────────────────

final authServiceProvider = Provider<AuthService>((_) => AuthService());
final apiServiceProvider = Provider<ApiService>((_) => ApiService());
final firestoreServiceProvider =
    Provider<FirestoreService>((_) => FirestoreService());
final notificationServiceProvider =
    Provider<NotificationService>((_) => NotificationService());

// ── Auth state ────────────────────────────────

/// Emits the current Firebase user (null when signed out).
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).when(
        data: (user) => user?.uid,
        loading: () => null,
        error: (_, __) => null,
      );
});

// ── Server status ─────────────────────────────

final serverStatusProvider =
    FutureProvider.autoDispose<ServerStatus>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getStatus();
});

// ── Detections stream ─────────────────────────

/// Realtime Firestore stream of all detections for the current user.
final detectionsStreamProvider =
    StreamProvider.autoDispose<List<DetectionRecord>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();
  final fs = ref.read(firestoreServiceProvider);
  return fs.detectionsStream(uid);
});

/// Unread badge count.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  final fs = ref.read(firestoreServiceProvider);
  return fs.unreadCount(uid);
});

/// Today's detection count.
final todayCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  final fs = ref.read(firestoreServiceProvider);
  return fs.todayCount(uid);
});

// ── Statistics ────────────────────────────────

final detectionStatsProvider =
    FutureProvider.autoDispose<DetectionStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return const DetectionStats(
      total: 0,
      byClass: {},
      byAlertLevel: {},
      last7Days: [],
    );
  }
  final fs = ref.read(firestoreServiceProvider);
  return fs.getStats(uid);
});

// ── Detection flow state ──────────────────────

class DetectionState {
  final bool isLoading;
  final DetectionRecord? result;
  final String? error;

  const DetectionState({
    this.isLoading = false,
    this.result,
    this.error,
  });

  DetectionState copyWith({
    bool? isLoading,
    DetectionRecord? result,
    String? error,
  }) {
    return DetectionState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class DetectionNotifier extends StateNotifier<DetectionState> {
  DetectionNotifier(this._ref) : super(const DetectionState());

  final Ref _ref;

  Future<void> detect(dynamic imageInput) async {
    state = const DetectionState(isLoading: true);

    try {
      final api = _ref.read(apiServiceProvider);
      final uid = _ref.read(currentUserIdProvider);
      if (uid == null) {
        state = const DetectionState(error: 'Not authenticated');
        return;
      }

      Map<String, dynamic>? response;
      if (imageInput is List<int>) {
        response = await api.uploadImageBytes(
          imageInput as dynamic,
          filename: 'capture.jpg',
        );
      } else {
        response = await api.uploadImage(imageInput);
      }

      if (response == null) {
        state =
            const DetectionState(error: 'No response from server. Is it running?');
        return;
      }

      final record = DetectionRecord.fromApiResponse(
        json: response,
        userId: uid,
      );

      state = DetectionState(result: record);
    } catch (e) {
      state = DetectionState(error: e.toString());
    }
  }

  Future<String?> saveCurrentResult() async {
    final record = state.result;
    if (record == null) return null;

    final fs = _ref.read(firestoreServiceProvider);
    final id = await fs.saveDetection(record);
    if (id != null) {
      final notif = _ref.read(notificationServiceProvider);
      final saved = record.copyWith(id: id);
      await notif.notifyDetection(saved);
      state = state.copyWith(result: saved);
    }
    return id;
  }

  void reset() {
    state = const DetectionState();
  }
}

final detectionProvider =
    StateNotifierProvider.autoDispose<DetectionNotifier, DetectionState>(
  (ref) => DetectionNotifier(ref),
);

// ── Connectivity ──────────────────────────────

final connectivityProvider = StateProvider<bool>((_) => true);
