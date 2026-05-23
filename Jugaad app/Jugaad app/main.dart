import 'package:flutter/material.dart';
import 'theme.dart';
import 'onboarding_screens.dart';
import 'auth_screens.dart';
import 'user_home_screen.dart';
import 'worker_home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'job_posting_screen.dart';
import 'job_match_screen.dart';
import 'worker_active_job_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_browse_profile_screens.dart';
import 'payment_screens.dart';
import 'error_screens.dart';

void main() {
  runApp(const JugaadPreviewApp());
}

class JugaadPreviewApp extends StatefulWidget {
  const JugaadPreviewApp({Key? key}) : super(key: key);

  @override
  State<JugaadPreviewApp> createState() => _JugaadPreviewAppState();
}

class _JugaadPreviewAppState extends State<JugaadPreviewApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _currentMode = 'user'; // 'user', 'worker', 'admin'

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void switchMode(String mode) {
    setState(() {
      _currentMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jugaad MVP Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(mode: _currentMode),
      darkTheme: AppTheme.getDarkTheme(mode: _currentMode),
      themeMode: _themeMode,
      home: PreviewGallery(
        toggleTheme: toggleTheme,
        switchMode: switchMode,
        currentMode: _currentMode,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class PreviewGallery extends StatelessWidget {
  final VoidCallback toggleTheme;
  final Function(String) switchMode;
  final String currentMode;
  final bool isDark;

  const PreviewGallery({
    Key? key,
    required this.toggleTheme,
    required this.switchMode,
    required this.currentMode,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jugaad MVP Screens'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme toggles
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'user', label: Text('User Mode')),
              ButtonSegment(value: 'worker', label: Text('Worker Mode')),
              ButtonSegment(value: 'admin', label: Text('Admin Mode')),
            ],
            selected: {currentMode},
            onSelectionChanged: (Set<String> newSelection) {
              switchMode(newSelection.first);
            },
          ),
          const SizedBox(height: 24.0),

          const Text('1. Onboarding & Auth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRouteButton(context, 'Splash Screen', const SplashScreen()),
          _buildRouteButton(context, 'Role Select', const RoleSelectScreen()),
          _buildRouteButton(context, 'OTP Auth', const OtpScreen()),
          const Divider(height: 32),

          const Text('2. User Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRouteButton(context, 'User Home', const UserHomeScreen()),
          _buildRouteButton(context, 'Job Posting Flow', const JobPostingScreen()),
          _buildRouteButton(context, 'Job Matching Flow', const JobMatchScreen()),
          _buildRouteButton(context, 'Browse Workers', const WorkerBrowseScreen()),
          _buildRouteButton(context, 'Payment', const PaymentScreen()),
          const Divider(height: 32),

          const Text('3. Worker Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRouteButton(context, 'Worker Home', const WorkerHomeScreen()),
          _buildRouteButton(context, 'Active Job', const WorkerActiveJobScreen()),
          _buildRouteButton(context, 'Earnings', const WorkerEarningsScreen()),
          const Divider(height: 32),

          const Text('4. Admin & Errors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRouteButton(context, 'Admin Dashboard', const AdminDashboardScreen()),
          _buildRouteButton(context, 'Payment Failed', const PaymentFailedScreen()),
          _buildRouteButton(context, 'Worker Cancelled', const WorkerCancelledScreen()),
          _buildRouteButton(context, 'Worker No-Show', const WorkerNoShowScreen()),
        ],
      ),
    );
  }

  Widget _buildRouteButton(BuildContext context, String title, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Text(title),
      ),
    );
  }
}
