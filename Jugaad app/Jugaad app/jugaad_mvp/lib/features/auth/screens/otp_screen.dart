import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/portal_mode.dart';
import '../../../core/services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final PortalMode selectedRole;

  const OtpScreen({Key? key, required this.selectedRole}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _phoneError;
  String? _otpError;
  int _attempts = 3;

  String _verificationId = '';

  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _countdown = 60;
  Timer? _timer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _phoneError = 'Enter a valid 10-digit number');
      return;
    }
    setState(() {
      _phoneError = null;
      _isLoading = true;
    });

    try {
      await _authService.sendOTP(
        phone: phone,
        onCodeSent: (verId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verId;
            _isOtpSent = true;
            _isLoading = false;
          });
          _startTimer();
          FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
        },
        onFailed: (errorMsg) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showErrorToast(errorMsg);
        },
        onAutoVerified: (user) async {
          if (!mounted) return;
          await _handleRouting(user.uid);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorToast('Failed to send OTP. Check network connection.');
    }
  }

  void _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) return;

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      final user = await _authService.verifyOTP(verificationId: _verificationId, otp: otp);
      
      // If user is null, it means it was the mock success from AuthService.
      final uid = user.uid;
      await _handleRouting(uid);

    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('Wrong OTP') || errorMsg.contains('invalid-verification-code')) {
         setState(() {
          _isLoading = false;
          _attempts--;
          _otpError = 'Incorrect OTP. $_attempts attempts remaining.';
        });
        _shakeController.forward();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorToast(errorMsg);
      }
    }
  }

  Future<void> _handleRouting(String uid) async {
    // Determine first time or registered
    bool isFirstTime = true;
    String approvalStatus = 'pending';

    try {
      if (widget.selectedRole == PortalMode.worker) {
        final workerDoc = await _firestore.collection('workers').doc(uid).get();
        if (workerDoc.exists) {
          isFirstTime = false;
          approvalStatus = workerDoc.data()?['approval_status'] ?? 'pending';
        } else {
          // Ensure user doc exists too
          await _firestore.collection('users').doc(uid).set({
            'role': widget.selectedRole.name,
            'phone': '+91${_phoneController.text}',
            'created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          isFirstTime = false;
        } else {
          await _firestore.collection('users').doc(uid).set({
            'role': widget.selectedRole.name,
            'phone': '+91${_phoneController.text}',
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('[FIRESTORE] Failed to fetch/create doc. Using mock routing.');
    }

    // Set Provider State
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(widget.selectedRole);

    print('[NAV] Auth gate: user=$uid, role=${widget.selectedRole.name}, workerStatus=$approvalStatus');

    String destinationScreen = 'Unknown';

    if (widget.selectedRole == PortalMode.user) {
      destinationScreen = 'UserHomeScreen';
    } else if (widget.selectedRole == PortalMode.worker) {
      if (isFirstTime) {
        destinationScreen = 'WorkerRegistrationScreen';
      } else {
        destinationScreen = 'WorkerHomeScreen ($approvalStatus)';
      }
    }

    print('[NAV] Routing to: $destinationScreen');

    setState(() {
      _isLoading = false;
    });

    if (widget.selectedRole == PortalMode.user) {
      context.go('/user/home');
    } else {
      if (isFirstTime) {
        context.go('/worker/register/step1');
      } else {
        context.go('/worker/home');
      }
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.kDanger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
        _verifyOtp();
      }
    } else {
      if (index > 0) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16.0),
              const Text(
                'Verify your number',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                _isOtpSent 
                    ? 'Enter the 6-digit code sent to +91 ${_phoneController.text}'
                    : 'We\'ll send you a 6-digit verification code.',
                style: const TextStyle(
                  fontSize: 14.0,
                  color: AppColors.kTextSecond,
                ),
              ),
              const SizedBox(height: 32.0),

              _isOtpSent ? _buildOtpEntry() : _buildPhoneEntry(),

              const Spacer(),
              
              ElevatedButton(
                onPressed: _isLoading ? null : (_isOtpSent ? _verifyOtp : _sendOtp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.selectedRole.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 20, width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(_isOtpSent ? 'Verify OTP' : 'Send OTP', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48.0,
          decoration: BoxDecoration(
            color: AppColors.kSurface,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _phoneError != null ? AppColors.kDanger : AppColors.kBorder, 
              width: _phoneError != null ? 1.5 : 0.5
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.kSurface2,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    bottomLeft: Radius.circular(8.0),
                  ),
                  border: Border(right: BorderSide(color: AppColors.kBorder, width: 0.5)),
                ),
                child: const Text(
                  '+91',
                  style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    hintText: 'Mobile number',
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text(
              _phoneError!,
              style: const TextStyle(color: AppColors.kDanger, fontSize: 12.0),
            ),
          ),
      ],
    );
  }

  Widget _buildOtpEntry() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: _otpError != null ? AppColors.kDangerLight : AppColors.kBackground,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: _otpError != null ? AppColors.kDanger : AppColors.kBorder,
                        width: _otpError != null ? 1.5 : 0.5,
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w600,
                          color: _otpError != null ? AppColors.kDanger : AppColors.kTextPrimary,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) => _onOtpChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8.0),
              if (_otpError != null)
                Text(
                  _otpError!,
                  style: const TextStyle(color: AppColors.kDanger, fontSize: 12.0, fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 24.0),
              
              _countdown > 0
                  ? Text(
                      'Resend OTP in 00:${_countdown.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: AppColors.kTextSecond, fontSize: 13.0),
                    )
                  : TextButton(
                      onPressed: () {
                        _startTimer();
                        setState(() => _otpError = null);
                        for (var c in _otpControllers) {
                          c.clear();
                        }
                        FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
                        _sendOtp();
                      },
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: widget.selectedRole.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
            ],
          ),
        );
      }
    );
  }
}
