import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Production-ready Firebase Phone OTP auth service.
/// Handles: Send OTP → Verify OTP → Get JWT → Sign out.
/// The JWT (ID token) is sent as `Authorization: Bearer <token>`
/// to all backend API calls. Backend verifies with firebase_admin.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Current state ───────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── 1. Send OTP ─────────────────────────────────────────
  /// Sends OTP to the given phone number (digits only, no country code).
  /// [onCodeSent] fires with the verificationId needed for step 2.
  /// [onAutoVerified] fires if Android auto-resolves the OTP.
  /// [onFailed] fires with a human-readable error message.
  Future<void> sendOTP({
    required String phone,
    required Function(String verificationId) onCodeSent,
    Function(User user)? onAutoVerified,
    Function(String error)? onFailed,
    int? forceResendingToken,
  }) async {
    // Ensure +91 prefix for Indian numbers
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,

      // Android auto-resolution (SMS Retriever API)
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          if (result.user != null) {
            await _ensureUserDoc(result.user!);
            onAutoVerified?.call(result.user!);
          }
        } catch (e) {
          onFailed?.call('Auto-verification failed: $e');
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        String message;
        switch (e.code) {
          case 'invalid-phone-number':
            message = 'Invalid phone number format';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Try again later.';
            break;
          case 'quota-exceeded':
            message = 'SMS quota exceeded. Contact support.';
            break;
          default:
            message = e.message ?? 'OTP send failed';
        }
        onFailed?.call(message);
      },

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto-retrieval timed out — user must enter OTP manually
      },
    );
  }

  // ─── 2. Verify OTP → Sign in ─────────────────────────────
  /// Verifies the 6-digit OTP against the verificationId from step 1.
  /// Returns the signed-in [User] or throws on failure.
  Future<User> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );

    try {
      final result = await _auth.signInWithCredential(credential);
      if (result.user == null) throw Exception('Sign-in returned null user');
      await _ensureUserDoc(result.user!);
      return result.user!;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
          throw Exception('Wrong OTP. Please try again.');
        case 'session-expired':
          throw Exception('OTP expired. Request a new one.');
        default:
          throw Exception(e.message ?? 'Verification failed');
      }
    }
  }

  // ─── 3. Get JWT (for backend API calls) ───────────────────
  /// Returns a fresh Firebase ID token (JWT).
  /// Call this BEFORE every API request.
  /// [forceRefresh] = true forces a new token (default: use cached).
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  /// Convenience: returns the full Authorization header value.
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getIdToken();
    if (token == null) throw Exception('Not authenticated');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─── 4. Sign out ──────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── 5. Ensure Firestore user document exists ─────────────
  /// Creates the /users/{uid} doc on first login.
  /// Subsequent logins update last_login only.
  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        'display_name': '',
        'email': '',
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'last_login': FieldValue.serverTimestamp(),
      });
    }
  }
}
