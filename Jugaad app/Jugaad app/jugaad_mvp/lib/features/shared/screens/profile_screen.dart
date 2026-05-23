import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/portal_mode.dart';
import 'package:jugaad_mvp/features/shared/widgets/mode_switch_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isWorkerOnline = false;

  void _showModeSwitchSheet(PortalMode currentMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModeSwitchSheet(currentMode: currentMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<PortalModeProvider>(context);
    final isWorker = modeProvider.mode == PortalMode.worker;
    final primaryColor = isWorker ? AppColors.kWorkerPrimary : AppColors.kUserPrimary;
    final primaryLightColor = isWorker ? AppColors.kWorkerPrimaryLight : AppColors.kUserPrimaryLight;

    print('[PROFILE] Current mode: ${modeProvider.mode.name}');

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isWorker ? 'Worker Profile' : 'User Profile',
          style: const TextStyle(color: AppColors.kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {}, // MVP: No edit profile yet
            child: Text('Edit', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Avatar & Info
            CircleAvatar(
              radius: 24,
              backgroundColor: primaryLightColor,
              child: Text('RM', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 12),
            const Text('Ravi M.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
            const SizedBox(height: 4),
            const Text('+91 9876543210 · Mysuru', style: TextStyle(fontSize: 13, color: AppColors.kTextSecond)),
            
            const SizedBox(height: 24),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(isWorker ? '24' : '4', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                    Text(isWorker ? 'Jobs done' : 'Jobs booked', style: const TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                  ],
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: AppColors.kBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                ),
                Column(
                  children: const [
                    Text('4.8 ★', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                    Text('Rating', style: TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Role Toggle Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.kBorder, width: 0.5),
              ),
              child: Column(
                children: [
                  const Text('Switch your active portal', style: TextStyle(fontSize: 11, color: AppColors.kTextSecond)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // User Segment
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isWorker) _showModeSwitchSheet(modeProvider.mode);
                          },
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: !isWorker ? AppColors.kUserPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'User mode',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !isWorker ? Colors.white : AppColors.kTextSecond,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Worker Segment
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isWorker) _showModeSwitchSheet(modeProvider.mode);
                          },
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: isWorker ? AppColors.kWorkerPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Worker mode',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isWorker ? Colors.white : AppColors.kTextSecond,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Worker-only Online Status
            if (isWorker)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.kBorder, width: 0.5))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Online status', style: TextStyle(fontSize: 14, color: AppColors.kTextPrimary)),
                          CupertinoSwitch(
                            value: _isWorkerOnline,
                            activeColor: AppColors.kSuccess,
                            onChanged: (val) => setState(() => _isWorkerOnline = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Workers are expected to stay online during pilot.', style: TextStyle(fontSize: 10, color: AppColors.kWarning)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            
            // Menu List
            _buildMenuItem(Icons.person_outline, 'Account settings'),
            _buildMenuItem(Icons.payment_outlined, 'Payment methods'),
            _buildMenuItem(Icons.notifications_none, 'Notification settings'),
            if (isWorker) _buildMenuItem(Icons.account_balance_wallet_outlined, 'Payout settings'),
            if (isWorker) _buildMenuItem(Icons.account_balance_outlined, 'Bank account'),
            _buildMenuItem(Icons.help_outline, 'Help & support'),
            
            // Logout
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 44,
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.kBorder, width: 0.5))),
              child: Row(
                children: const [
                  Icon(Icons.logout, color: AppColors.kDanger, size: 20),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(fontSize: 14, color: AppColors.kDanger, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 44,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.kBorder, width: 0.5))),
      child: Row(
        children: [
          Icon(icon, color: AppColors.kTextSecond, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.kTextPrimary))),
          const Icon(Icons.chevron_right, color: AppColors.kTextTertiary, size: 20),
        ],
      ),
    );
  }
}
