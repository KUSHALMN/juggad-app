import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/portal_mode.dart';
import 'core/services/notification_service.dart';
import 'core/services/heartbeat_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'features/shared/widgets/offline_banner.dart';
import 'core/services/fcm_token_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await HeartbeatService().init();
    await NotificationService().init(AppRouter.rootNavigatorKey);
    FCMTokenManager.refreshAndUploadToken();
  } catch (e) {
    print('[MAIN] Init error (Mocking fallback enabled): $e');
  }

  runApp(
    ProviderScope(
      child: pkg_provider.MultiProvider(
        providers: [
          pkg_provider.ChangeNotifierProvider(create: (_) => PortalModeProvider()),
        ],
        child: const JugaadApp(),
      ),
    ),
  );
}

class JugaadApp extends StatelessWidget {
  const JugaadApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final modeProvider = pkg_provider.Provider.of<PortalModeProvider>(context, listen: false);
    final router = AppRouter.getRouter(modeProvider);

    return pkg_provider.Consumer<PortalModeProvider>(
      builder: (context, portalModeProvider, child) {
        final mode = portalModeProvider.mode;

        return MaterialApp.router(
          title: 'Jugaad App',
          theme: mode.theme,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) {
            return OfflineBannerOverlay(child: child!);
          },
        );
      },
    );
  }
}
