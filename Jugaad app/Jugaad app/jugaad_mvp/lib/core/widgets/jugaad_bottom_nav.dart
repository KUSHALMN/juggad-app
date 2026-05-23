import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/portal_mode.dart';

class JugaadBottomNav extends StatelessWidget {
  final PortalMode mode;
  final int currentIndex;
  final Function(int) onTap;

  const JugaadBottomNav({
    Key? key,
    required this.mode,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeColor = mode.primary;

    if (mode == PortalMode.user) {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeColor,
        unselectedItemColor: AppColors.kTextTertiary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        backgroundColor: AppColors.kBackground,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), activeIcon: Icon(Icons.search), label: 'Book'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), activeIcon: Icon(Icons.list_alt), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      );
    } else {
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeColor,
        unselectedItemColor: AppColors.kTextTertiary,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        backgroundColor: AppColors.kBackground,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      );
    }
  }
}
