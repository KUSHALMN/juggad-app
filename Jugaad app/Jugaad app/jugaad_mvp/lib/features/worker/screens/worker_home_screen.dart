import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';

import 'package:jugaad_mvp/core/theme/app_colors.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({Key? key}) : super(key: key);

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  String _approvalStatus = 'pending';
  bool _isOnline = false;
  String? _activeJobId;
  StreamSubscription<DocumentSnapshot>? _workerSub;
  StreamSubscription<QuerySnapshot>? _jobsSub;

  @override
  void initState() {
    super.initState();
    _startListeners();
    
    // Set status bar to green tint
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _startListeners() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    _workerSub = FirebaseFirestore.instance.collection('workers').doc(uid).snapshots().listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _approvalStatus = doc.data()?['approval_status'] ?? 'pending';
        });
      }
    });

    _jobsSub = FirebaseFirestore.instance.collection('jobs')
      .where('worker_id', isEqualTo: uid)
      .where('status', whereIn: ['assigned', 'in_progress'])
      .snapshots().listen((snap) {
        if (!mounted) return;
        setState(() {
          if (snap.docs.isNotEmpty) {
            _activeJobId = snap.docs.first.id;
          } else {
            _activeJobId = null;
          }
        });
      });
  }

  @override
  void dispose() {
    _workerSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  void _toggleOnline(bool value) {
    setState(() => _isOnline = value);
    print('[WORKER_HOME] Online status: $_isOnline');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.kWorkerPrimaryLight,
          statusBarIconBrightness: Brightness.dark,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hi Ravi 👋',
              style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.kWorkerPrimaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Today: ₹350',
                style: TextStyle(color: AppColors.kWorkerPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Approval Banner
              if (_approvalStatus == 'pending')
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.kWarningLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.kWarningBorder, width: 0.5),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.access_time_filled, color: AppColors.kWarning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registration pending approval — you\'ll go live within 24 hours.',
                          style: TextStyle(fontSize: 12, color: AppColors.kWarning, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Active Job Banner
              if (_activeJobId != null)
                GestureDetector(
                  onTap: () => context.go('/worker/active?job_id=$_activeJobId'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.kWorkerPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.kWorkerBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.play_circle_fill, color: AppColors.kWorkerPrimary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Active job: Laptop Repair · 1.2 km away',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kWorkerPrimary),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: AppColors.kWorkerPrimary, size: 16),
                      ],
                    ),
                  ),
                ),

              // Online Status Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.kBorder, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isOnline ? "You're online · Receiving jobs" : "You're offline",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isOnline ? AppColors.kSuccess : AppColors.kTextTertiary,
                            ),
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isOnline,
                          activeColor: AppColors.kSuccess,
                          onChanged: _toggleOnline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.kBorder),
                    const SizedBox(height: 12),
                    const Text(
                      'Stay online to earn more. Workers offline miss job requests.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppColors.kWarning, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // Earnings Summary Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.kBorder, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('THIS WEEK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.kTextSecond)),
                    SizedBox(height: 8),
                    Text('₹1,840 earned · 6 jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                    SizedBox(height: 4),
                    Text('₹600 pending payout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.kWarning)),
                  ],
                ),
              ),


              const SizedBox(height: 24),

              // Recent Jobs List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Jobs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                    GestureDetector(
                      onTap: () => context.go('/worker/earnings'),
                      child: const Text('See all →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kWorkerPrimary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  _CompactJobCard(service: 'Laptop repair', name: 'Arun K.', amount: '₹350', status: 'Completed'),
                  _CompactJobCard(service: 'Phone screen', name: 'Priya M.', amount: '₹800', status: 'Completed'),
                  _CompactJobCard(service: 'AC service', name: 'Ramesh B.', amount: '₹450', status: 'Completed'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactJobCard extends StatelessWidget {
  final String service;
  final String name;
  final String amount;
  final String status;

  const _CompactJobCard({
    required this.service,
    required this.name,
    required this.amount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.kBorder, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                const SizedBox(height: 2),
                Text('$name · $status', style: const TextStyle(fontSize: 11, color: AppColors.kTextSecond)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kSuccess)),
        ],
      ),
    );
  }
}
