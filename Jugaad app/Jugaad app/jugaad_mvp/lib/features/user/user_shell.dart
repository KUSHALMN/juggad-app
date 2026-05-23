import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/portal_mode.dart';
import '../../core/widgets/jugaad_bottom_nav.dart';

class UserShell extends StatelessWidget {
  final Widget child;

  const UserShell({Key? key, required this.child}) : super(key: key);

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/user/home')) return 0;
    if (location.startsWith('/user/book')) return 1;
    if (location.startsWith('/user/jobs')) return 2;
    if (location.startsWith('/user/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/user/home');
        break;
      case 1:
        context.go('/user/book');
        break;
      case 2:
        context.go('/user/jobs');
        break;
      case 3:
        context.go('/user/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: JugaadBottomNav(
        mode: PortalMode.user,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int idx) => _onItemTapped(idx, context),
      ),
    );
  }
}
