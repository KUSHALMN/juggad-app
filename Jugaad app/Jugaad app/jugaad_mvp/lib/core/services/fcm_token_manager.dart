import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMTokenManager {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> refreshAndUploadToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _uploadToken(user.uid, token);
      }

      _fcm.onTokenRefresh.listen((newToken) {
        _uploadToken(user.uid, newToken);
      });
    } catch (e) {
      print("Failed to refresh FCM token: $e");
    }
  }

  static Future<void> _uploadToken(String uid, String token) async {
    // Determine if user or worker by checking collections
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      await _firestore.collection('users').doc(uid).update({
        'fcm_token': token,
        'fcm_updated_at': FieldValue.serverTimestamp(),
      });
      return;
    }
    
    final workerDoc = await _firestore.collection('workers').doc(uid).get();
    if (workerDoc.exists) {
      await _firestore.collection('workers').doc(uid).update({
        'fcm_token': token,
        'fcm_updated_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
