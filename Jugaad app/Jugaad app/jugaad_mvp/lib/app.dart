import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/portal_mode.dart';
import 'core/services/auth_service.dart';

import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/role_select_screen.dart';
import 'features/auth/screens/otp_screen.dart';

import 'features/user/user_shell.dart';
import 'features/user/screens/user_home_screen.dart';
import 'features/user/screens/post_job/step1_screen.dart';
import 'features/user/screens/post_job/step2_screen.dart';
import 'features/user/screens/post_job/step3_screen.dart';
import 'features/user/screens/matching/matching_screen.dart';
import 'features/user/screens/tracking_screen.dart';
import 'features/user/screens/payment_screen.dart';
import 'features/user/screens/completion_screen.dart';
import 'features/user/screens/jobs/jobs_screen.dart';
import 'features/worker/worker_shell.dart';
import 'features/worker/screens/worker_home_screen.dart';
import 'features/worker/screens/registration/step1_screen.dart';
import 'features/worker/screens/registration/step2_screen.dart';
import 'features/worker/screens/registration/step3_screen.dart';
import 'features/worker/screens/registration/approval_submitted_screen.dart';
import 'features/worker/screens/incoming_request_screen.dart';
import 'features/worker/screens/active_job_screen.dart';
import 'features/worker/screens/earnings_screen.dart';
import 'features/shared/screens/profile_screen.dart';

// Placeholder Screens for Routing
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: const TextStyle(fontSize: 24))),
    );
  }
}

class AppRouter {
  static final AuthService _authService = AuthService();
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  static CustomTransitionPage _fadeTransition(BuildContext context, GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static GoRouter? _router;

  static GoRouter getRouter(PortalModeProvider modeProvider) {
    _router ??= GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: modeProvider,
      redirect: (context, state) {
        final isLoggedIn = _authService.currentUser != null;
        final isAuthRoute = state.uri.toString().startsWith('/splash') || 
                            state.uri.toString().startsWith('/auth');

        if (!isLoggedIn && !isAuthRoute) {
          return '/splash';
        }

        // Mode gating
        if (isLoggedIn) {
          final mode = modeProvider.mode;
          final path = state.uri.toString();
          
          if (path == '/splash' || path.startsWith('/auth')) {
            return mode == PortalMode.worker ? '/worker/home' : '/user/home';
          }
          
          if (mode == PortalMode.user && path.startsWith('/worker')) {
            return '/user/home';
          }
          if (mode == PortalMode.worker && path.startsWith('/user')) {
            return '/worker/home';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => _fadeTransition(context, state, const SplashScreen()),
        ),
        GoRoute(
          path: '/auth/role',
          pageBuilder: (context, state) => _fadeTransition(context, state, const RoleSelectScreen()),
        ),
        GoRoute(
          path: '/auth/otp',
          pageBuilder: (context, state) {
            final roleName = state.uri.queryParameters['role'] ?? 'user';
            final role = roleName == 'worker' ? PortalMode.worker : PortalMode.user;
            return _fadeTransition(context, state, OtpScreen(selectedRole: role));
          },
        ),

        // POST JOB WIZARD — outside shell (fullscreen flow)
        GoRoute(
          path: '/user/post-job/step1',
          pageBuilder: (context, state) => _fadeTransition(context, state, const PostJobStep1Screen()),
        ),
        GoRoute(
          path: '/user/post-job/step2',
          pageBuilder: (context, state) => _fadeTransition(context, state, const PostJobStep2Screen()),
        ),
        GoRoute(
          path: '/user/post-job/step3',
          pageBuilder: (context, state) => _fadeTransition(context, state, const PostJobStep3Screen()),
        ),
        GoRoute(
          path: '/user/matching',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            return _fadeTransition(context, state, MatchingScreen(jobId: jobId));
          },
        ),
        GoRoute(
          path: '/user/tracking',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            return _fadeTransition(context, state, TrackingScreen(jobId: jobId));
          },
        ),
        GoRoute(
          path: '/user/payment',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            final amount = double.tryParse(state.uri.queryParameters['amount'] ?? '0') ?? 0;
            return _fadeTransition(context, state, PaymentScreen(jobId: jobId, amount: amount));
          },
        ),
        GoRoute(
          path: '/user/completion',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            final workerName = state.uri.queryParameters['worker_name'] ?? 'Worker';
            final duration = int.tryParse(state.uri.queryParameters['duration'] ?? '0') ?? 0;
            return _fadeTransition(context, state, CompletionScreen(jobId: jobId, workerName: workerName, durationMinutes: duration));
          },
        ),
        GoRoute(
          path: '/user/chat/:jobId',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId'] ?? '';
            return _fadeTransition(context, state, PlaceholderScreen(title: 'Chat: $jobId'));
          },
        ),

        // WORKER REGISTRATION WIZARD — outside shell
        GoRoute(
          path: '/worker/register/step1',
          pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerRegistrationStep1()),
        ),
        GoRoute(
          path: '/worker/register/step2',
          pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerRegistrationStep2()),
        ),
        GoRoute(
          path: '/worker/register/step3',
          pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerRegistrationStep3()),
        ),
        GoRoute(
          path: '/worker/register/success',
          pageBuilder: (context, state) => _fadeTransition(context, state, const ApprovalSubmittedScreen()),
        ),
        GoRoute(
          path: '/worker/incoming',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            final skill = state.uri.queryParameters['skill'] ?? 'Laptop repair';
            return CustomTransitionPage(
              key: state.pageKey,
              opaque: false, // Allows the black background overlay to be transparent
              child: IncomingRequestScreen(jobId: jobId, skill: skill),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          },
        ),

        // USER SHELL
        ShellRoute(
          builder: (context, state, child) {
            return UserShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/user/home',
              pageBuilder: (context, state) => _fadeTransition(context, state, const UserHomeScreen()),
            ),
            GoRoute(
              path: '/user/book',
              pageBuilder: (context, state) => _fadeTransition(context, state, const PlaceholderScreen(title: 'Book Service')),
            ),
            GoRoute(
              path: '/user/jobs',
              pageBuilder: (context, state) => _fadeTransition(context, state, const JobsScreen()),
            ),
            GoRoute(
              path: '/user/profile',
              pageBuilder: (context, state) => _fadeTransition(context, state, const ProfileScreen()),
            ),
          ],
        ),

        // WORKER SHELL
        ShellRoute(
          builder: (context, state, child) {
            return WorkerShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/worker/home',
              pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerHomeScreen()),
            ),
            GoRoute(
              path: '/worker/active',
              pageBuilder: (context, state) {
                final jobId = state.uri.queryParameters['job_id'] ?? '';
                return _fadeTransition(context, state, ActiveJobScreen(jobId: jobId));
              },
            ),
            GoRoute(
              path: '/worker/earnings',
              pageBuilder: (context, state) => _fadeTransition(context, state, const EarningsScreen()),
            ),
            GoRoute(
              path: '/worker/profile',
              pageBuilder: (context, state) => _fadeTransition(context, state, const ProfileScreen()),
            ),
          ],
        ),
      ],
    );
    return _router!;
  }
}
