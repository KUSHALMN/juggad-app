import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'app_theme.dart';
import '../services/heartbeat_service.dart';

enum PortalMode { user, worker }

extension PortalModeExtension on PortalMode {
  Color get primary {
    switch (this) {
      case PortalMode.user:
        return AppColors.kUserPrimary;
      case PortalMode.worker:
        return AppColors.kWorkerPrimary;
    }
  }

  Color get primaryLight {
    switch (this) {
      case PortalMode.user:
        return AppColors.kUserPrimaryLight;
      case PortalMode.worker:
        return AppColors.kWorkerPrimaryLight;
    }
  }

  ThemeData get theme {
    switch (this) {
      case PortalMode.user:
        return AppTheme.userTheme();
      case PortalMode.worker:
        return AppTheme.workerTheme();
    }
  }

  String get label {
    switch (this) {
      case PortalMode.user:
        return "User";
      case PortalMode.worker:
        return "Worker";
    }
  }

  String get pillText {
    switch (this) {
      case PortalMode.user:
        return "User";
      case PortalMode.worker:
        return "Worker";
    }
  }
}

class PortalModeProvider extends ChangeNotifier {
  static const String _prefKey = 'portal_mode';
  PortalMode _mode = PortalMode.user;

  PortalMode get mode => _mode;

  PortalModeProvider() {
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? modeString = prefs.getString(_prefKey);
    if (modeString == 'worker') {
      _mode = PortalMode.worker;
    } else {
      _mode = PortalMode.user;
    }
    await _syncHeartbeatForMode();
    notifyListeners();
  }

  Future<void> setMode(PortalMode newMode) async {
    _mode = newMode;
    print('[THEME] Portal mode set to: ${_mode.name}');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newMode.name);
    await _syncHeartbeatForMode();
  }

  Future<void> _syncHeartbeatForMode() async {
    if (_mode == PortalMode.worker) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
        if (doc.exists && doc.data()?['approval_status'] == 'approved') {
          HeartbeatService().startHeartbeat(uid);
        } else {
          HeartbeatService().stopHeartbeat();
        }
      } else {
        HeartbeatService().stopHeartbeat();
      }
    } else {
      HeartbeatService().stopHeartbeat();
    }
  }

  void toggleMode() {
    setMode(_mode == PortalMode.user ? PortalMode.worker : PortalMode.user);
  }
}
