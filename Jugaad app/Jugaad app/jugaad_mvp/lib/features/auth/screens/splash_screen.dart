import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as pkg_provider;
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/portal_mode.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() async {
    if (_authService.currentUser != null) {
      print('[NAV] Auth gate: user=${_authService.currentUser?.uid}');
      if (mounted) {
        final mode =
            pkg_provider.Provider.of<PortalModeProvider>(context, listen: false)
                .mode;
        context.go(mode == PortalMode.worker ? '/worker/home' : '/user/home');
        return;
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 1500)); 
  }

  void _navigateToRoleSelect(BuildContext context) {
    context.go('/auth/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              
              // App Icon (56dp rounded square, blue tint, white checkmark)
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: AppColors.kUserPrimary,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32.0,
                ),
              ),
              const SizedBox(height: 24.0),
              
              // Title
              const Text(
                'Jugaad',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kTextPrimary,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8.0),
              
              // Subtitle
              const Text(
                'Skills near you, fast.',
                style: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.kTextSecond,
                ),
              ),
              
              const SizedBox(height: 48.0),
              
              // Social Proof Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: AppColors.kSurface,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.kBorder, width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16.0, color: AppColors.kUserPrimary),
                    SizedBox(width: 8.0),
                    Text(
                      'Live in Vijayanagar, Mysuru\nWorkers reach you in ~20 mins',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.0, color: AppColors.kTextPrimary, height: 1.4),
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Primary CTA
              ElevatedButton(
                onPressed: () => _navigateToRoleSelect(context),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 16.0),
              
              // Tertiary CTA
              TextButton(
                onPressed: () => _navigateToRoleSelect(context), // Route to sign in
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(color: AppColors.kTextSecond),
                ),
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }
}
