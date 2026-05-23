import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class OfflineBannerOverlay extends StatefulWidget {
  final Widget child;
  const OfflineBannerOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<OfflineBannerOverlay> createState() => _OfflineBannerOverlayState();
}

class _OfflineBannerOverlayState extends State<OfflineBannerOverlay> {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    // Use the multi-result API from connectivity_plus ^7.0.0
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
        });
      }
    });

    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() {
          _isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: const BoxDecoration(
                  color: AppColors.kBackground,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -4)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.kDanger.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.wifi_off, color: AppColors.kDanger, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('No internet connection.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                            SizedBox(height: 2),
                            Text("Some features won't work.", style: TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Manually check again
                          Connectivity().checkConnectivity();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kSurface,
                          foregroundColor: AppColors.kTextPrimary,
                          side: const BorderSide(color: AppColors.kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
