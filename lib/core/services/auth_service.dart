import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// ─────────────────────────────────────────────
///  Auth Service — Firebase Auth wrapper
/// ─────────────────────────────────────────────
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _log = Logger();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isLoggedIn => _auth.currentUser != null;

  /// Sign in with email + password. Returns error string or null on success.
  Future<String?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _persistUser(cred.user);
      _log.i('User signed in: ${cred.user?.uid}');
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  /// Register with email + password. Returns error string or null on success.
  Future<String?> register(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _persistUser(cred.user);
      _log.i('User registered: ${cred.user?.uid}');
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  /// Send password reset email. Returns error string or null on success.
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  /// Change password for currently signed-in user.
  Future<String?> updatePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'Not signed in.';

      // Re-authenticate first
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  /// Sign out and clear persisted session.
  Future<void> signOut() async {
    await _auth.signOut();
    await _clearPersistedUser();
    _log.i('User signed out');
  }

  // ── Persistence helpers ────────────────────────

  Future<void> _persistUser(User? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStrings.keyUserId, user.uid);
    await prefs.setString(AppStrings.keyUserEmail, user.email ?? '');
  }

  Future<void> _clearPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppStrings.keyUserId);
    await prefs.remove(AppStrings.keyUserEmail);
  }

  // ── Error mapping ──────────────────────────────

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'requires-recent-login':
        return 'Please log out and log in again before changing your password.';
      default:
        return 'Authentication error: $code';
    }
  }
}
