import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/portal_mode.dart';
import 'package:go_router/go_router.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({Key? key}) : super(key: key);

  void _selectRole(BuildContext context, PortalMode mode) {
    context.go('/auth/otp?role=${mode.name}');
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
                'How will you use Jugaad?',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'You can switch roles anytime',
                style: TextStyle(
                  fontSize: 13.0,
                  color: AppColors.kTextSecond,
                ),
              ),
              const SizedBox(height: 40.0),

              // User Role Card
              _JugaadRoleCard(
                title: 'I need help',
                subtitle: 'Book local workers in minutes',
                icon: Icons.person_search,
                color: AppColors.kUserPrimary,
                bgColor: AppColors.kUserPrimaryLight,
                borderColor: AppColors.kUserBorder,
                onTap: () => _selectRole(context, PortalMode.user),
              ),
              const SizedBox(height: 24.0),

              // Worker Role Card
              _JugaadRoleCard(
                title: 'I offer skills',
                subtitle: 'Earn by doing jobs nearby',
                icon: Icons.handyman,
                color: AppColors.kWorkerPrimary,
                bgColor: AppColors.kWorkerPrimaryLight,
                borderColor: AppColors.kWorkerBorder,
                onTap: () => _selectRole(context, PortalMode.worker),
              ),
              const SizedBox(height: 12.0),

              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 12.0, color: AppColors.kWorkerPrimary),
                  SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      "You'll start receiving job requests immediately after approval.",
                      style: TextStyle(fontSize: 10.0, color: AppColors.kWorkerPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JugaadRoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _JugaadRoleCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.0),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.0,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16.0),
          ],
        ),
      ),
    );
  }
}
