import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({Key? key}) : super(key: key);

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isMockMode = false; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Jobs', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.kUserPrimary,
          unselectedLabelColor: AppColors.kTextTertiary,
          indicatorColor: AppColors.kUserPrimary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Scheduled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTab(),
          _buildScheduledTab(),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return _buildEmptyState('Please log in to see jobs', () => context.go('/splash'));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('user_id', isEqualTo: uid)
          .where('status', whereIn: ['searching', 'assigned', 'in_progress'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        print('[JOBS] Active jobs count: ${docs.length}');

        if (docs.isEmpty) {
          return _buildEmptyState('No active jobs. Book one!', () => context.push('/user/post-job/step1'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? 'searching';
            return _JobCard(
              title: data['skill'] as String? ?? 'Service',
              status: status,
              onTap: () {
                if (status == 'searching' || status == 'assigned') {
                  context.push('/user/matching?job_id=${docs[index].id}');
                } else if (status == 'in_progress') {
                  context.push('/user/tracking?job_id=${docs[index].id}');
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScheduledTab() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return _buildEmptyState('Please log in to see scheduled jobs', () => context.go('/splash'));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('scheduled_jobs')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        print('[JOBS] Scheduled jobs count: ${docs.length}');

        if (docs.isEmpty) {
          return _buildEmptyState('No upcoming jobs. Schedule one →', () => context.push('/user/post-job/step1'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _ScheduledJobCard(
              title: data['skill'] as String? ?? 'Service',
              location: data['location']?['address'] as String? ?? 'Unknown',
              datetime: _formatDateTime(data['scheduled_at']),
              status: data['status'] as String? ?? 'pending',
              workerName: data['worker_name'] as String?,
              workerPhone: data['worker_phone'] as String?,
            );
          },
        );
      },
    );
  }

  String _formatDateTime(dynamic scheduledAt) {
    if (scheduledAt == null) return 'Unknown time';
    DateTime dt;
    if (scheduledAt is Timestamp) dt = scheduledAt.toDate();
    else if (scheduledAt is String) dt = DateTime.tryParse(scheduledAt) ?? DateTime.now();
    else return 'Unknown time';

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[dt.weekday - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $hour:$minute $period';
  }

  Widget _buildEmptyState(String message, VoidCallback onAction) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 48, color: AppColors.kSurface2),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.kTextSecond, fontSize: 14)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.kUserPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Book service', style: TextStyle(color: AppColors.kUserPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─── ACTIVE JOB CARD ───────────────────────────────────────
class _JobCard extends StatelessWidget {
  final String title;
  final String status;
  final VoidCallback onTap;

  const _JobCard({
    required this.title,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.kUserPrimary;
    String statusText = 'Searching';
    if (status == 'assigned') {
      statusColor = AppColors.kWarning;
      statusText = 'Worker assigned';
    } else if (status == 'in_progress') {
      statusColor = AppColors.kSuccess;
      statusText = 'In progress';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.kBorder, width: 0.5)),
      elevation: 0,
      color: AppColors.kSurface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.kTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SCHEDULED JOB CARD ────────────────────────────────────
class _ScheduledJobCard extends StatelessWidget {
  final String title;
  final String location;
  final String datetime;
  final String status; // 'confirmed' or 'pending'
  final String? workerName;
  final String? workerPhone;

  const _ScheduledJobCard({
    required this.title,
    required this.location,
    required this.datetime,
    required this.status,
    this.workerName,
    this.workerPhone,
  });

  Future<void> _callWorker() async {
    if (workerPhone == null) return;
    final url = Uri.parse('tel:$workerPhone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == 'confirmed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Datetime badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.kUserPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  datetime,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.kUserPrimary),
                ),
              ),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfirmed ? AppColors.kSuccess.withOpacity(0.1) : AppColors.kWarningLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isConfirmed ? 'Confirmed' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isConfirmed ? AppColors.kSuccess : AppColors.kWarning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.kTextTertiary),
              const SizedBox(width: 4),
              Expanded(child: Text(location, style: const TextStyle(fontSize: 12, color: AppColors.kTextSecond))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: AppColors.kBorder),
          const SizedBox(height: 12),
          
          if (!isConfirmed)
            const Text(
              "We're confirming your worker. You'll get an SMS.",
              style: TextStyle(fontSize: 11, color: AppColors.kTextSecond),
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.kWorkerPrimaryLight,
                  child: Text(
                    workerName?.substring(0, 1) ?? 'W',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.kWorkerPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workerName ?? 'Worker Assigned',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: _callWorker,
                  child: const Text(
                    'Call',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kUserPrimary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
