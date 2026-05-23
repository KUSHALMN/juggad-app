import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

// Note: This file models the Admin Ops Panel. It can be run as a Flutter Web app.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0; // Dashboard, Jobs, Workers, Ops

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    // Admin specific colors
    final Color adminPrimary = const Color(0xFF3D1F7A);
    final Color adminLight = const Color(0xFFEDE8F7);
    final Color adminBorder = const Color(0xFF9B82D4);

    return Scaffold(
      backgroundColor: colors.background, // Slightly off-white for admin dashboard feel
      appBar: AppBar(
        backgroundColor: adminPrimary,
        title: const Text('Jugaad Ops', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.white),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              radius: 14.0,
              backgroundColor: adminLight,
              child: Text('AD', style: TextStyle(color: adminPrimary, fontSize: 10.0, fontWeight: FontWeight.w700)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // STATUS BAR SUMMARY (2x2 Grid)
              // ==========================================
              const Text('System Status', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryTile('Active jobs', '12', const Color(0xFFE1F5EE), const Color(0xFF0F6E56)), // Green tile
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildSummaryTile('Workers online', '45/60', const Color(0xFFE1F5EE), const Color(0xFF0F6E56)), // Green tile (>60%)
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryTile('Pending jobs', '3', const Color(0xFFFCEBEB), const Color(0xFFA32D2D), isAlert: true), // Red tile
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildSummaryTile('Scheduled today', '8', const Color(0xFFE6F1FB), const Color(0xFF185FA5)), // Blue tile
                  ),
                ],
              ),
              const SizedBox(height: 32.0),

              // ==========================================
              // PENDING JOBS LIST (NEEDS ATTENTION)
              // ==========================================
              Row(
                children: [
                  Container(
                    width: 8.0,
                    height: 8.0,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFA32D2D)),
                  ),
                  const SizedBox(width: 8.0),
                  const Text(
                    'NEEDS ATTENTION (3)',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700, color: Color(0xFFA32D2D), letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                'Jobs where no worker was auto-matched or worker declined.',
                style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16.0),
              
              _buildPendingJobCard(
                service: 'Laptop repair',
                customerName: 'Vivek Sharma',
                phone: '+91 9876543210',
                time: '10 mins ago',
                area: 'Vijayanagar 1st Stage',
                adminPrimary: adminPrimary,
                adminBorder: adminBorder,
                context: context,
              ),
              const SizedBox(height: 12.0),
              _buildPendingJobCard(
                service: 'Plumber',
                customerName: 'Anjali D.',
                phone: '+91 8765432109',
                time: '15 mins ago',
                area: 'Gokulam',
                adminPrimary: adminPrimary,
                adminBorder: adminBorder,
                context: context,
              ),

              const SizedBox(height: 32.0),
              
              // ==========================================
              // PENDING WORKER APPROVALS
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending Approvals', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () {}, child: Text('View all', style: TextStyle(color: adminPrimary))),
                ],
              ),
              const SizedBox(height: 8.0),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xFFEF9F27), width: 1.0), // Amber border
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFAEEDA),
                      child: Icon(Icons.person_add, color: Color(0xFFBA7517)),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Suresh K.', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
                          Text('Electrician · Applied 2 hrs ago', style: TextStyle(fontSize: 12.0, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: adminPrimary,
                        side: BorderSide(color: adminPrimary),
                      ),
                      onPressed: () {},
                      child: const Text('Review'),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 64.0), // Padding for bottom nav
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        mode: 'admin',
      ),
    );
  }

  Widget _buildSummaryTile(String title, String value, Color bgColor, Color textColor, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0),
        border: isAlert ? Border.all(color: textColor, width: 1.0) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingJobCard({
    required String service,
    required String customerName,
    required String phone,
    required String time,
    required String area,
    required Color adminPrimary,
    required Color adminBorder,
    required BuildContext context,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withOpacity(0.02),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(service, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
              Text(time, style: const TextStyle(fontSize: 12.0, color: Color(0xFFA32D2D), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8.0),
          Text('$customerName · $phone', style: TextStyle(fontSize: 13.0, color: Colors.grey[700])),
          const SizedBox(height: 4.0),
          Row(
            children: [
              Icon(Icons.location_on, size: 14.0, color: Colors.grey[500]),
              const SizedBox(width: 4.0),
              Text(area, style: TextStyle(fontSize: 12.0, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            height: 40.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: adminPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              onPressed: () => _showAssignWorkerBottomSheet(context, adminPrimary, adminBorder),
              child: const Text('Assign worker manually', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignWorkerBottomSheet(BuildContext context, Color adminPrimary, Color adminBorder) {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, // 70% of screen
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available workers nearby', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1.0),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildWorkerRow(context, 'Rajesh K.', 'Laptop, Phone', '0.8 km', true, adminPrimary),
                    const SizedBox(height: 12.0),
                    _buildWorkerRow(context, 'Arun M.', 'Laptop', '1.2 km', true, adminPrimary),
                    const SizedBox(height: 12.0),
                    _buildWorkerRow(context, 'Suresh V.', 'Laptop, AC', '2.5 km', false, adminPrimary), // Offline
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkerRow(BuildContext context, String name, String skills, String distance, bool isOnline, Color adminPrimary) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.0,
            backgroundColor: Colors.grey[100],
            child: Icon(Icons.person, color: Colors.grey[500]),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8.0),
                    if (isOnline)
                      Container(width: 8.0, height: 8.0, decoration: const BoxDecoration(color: Color(0xFF0F6E56), shape: BoxShape.circle))
                    else
                      Container(width: 8.0, height: 8.0, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text('$skills · $distance', style: TextStyle(fontSize: 12.0, color: Colors.grey[600])),
              ],
            ),
          ),
          if (isOnline)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: adminPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onPressed: () {},
              child: const Text('Assign', style: TextStyle(fontSize: 12.0, color: Colors.white)),
            )
          else
            Text('Offline', style: TextStyle(fontSize: 12.0, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
