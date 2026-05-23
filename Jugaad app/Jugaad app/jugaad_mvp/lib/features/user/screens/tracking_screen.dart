import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class TrackingScreen extends StatefulWidget {
  final String jobId;
  const TrackingScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with WidgetsBindingObserver {
  StreamSubscription<DocumentSnapshot>? _jobSub;
  Map<String, dynamic>? _jobData;
  Timer? _elapsedTimer;
  String _elapsedString = '00:00';
  bool _isEtaPassed = false;
  DateTime? _lastBackgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFirestoreListener();
  }

  void _startFirestoreListener() {
    if (widget.jobId.isEmpty) return;

    _jobSub = FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      
      print('[TRACKING] Worker ETA updated: ${data['worker_eta']}');
      
      setState(() {
        _jobData = data;
      });

      if (data['worker_ack'] == true && data['status'] == 'in_progress') {
        _startElapsedTimer(data['started_at'] as Timestamp?);
      }
      
      // Navigate to payment if job is completed
      if (data['status'] == 'completed') {
        final amount = data['payment_amount'] ?? data['amount'] ?? 350;
        context.go('/user/payment?job_id=${widget.jobId}&amount=$amount');
      } else if (data['status'] == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job was cancelled.'), backgroundColor: Colors.red),
        );
        context.go('/user/home');
      }
    }, onError: (e) {
      print('[TRACKING] Error listening to job: $e');
    });
  }

  void _startElapsedTimer(Timestamp? startedAt) {
    if (_elapsedTimer != null && _elapsedTimer!.isActive) return;
    
    final startTime = startedAt?.toDate() ?? DateTime.now();
    
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final duration = DateTime.now().difference(startTime);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      setState(() {
        _elapsedString = '$minutes:$seconds';
      });
    });
  }


  Future<void> _callWorker() async {
    final phone = _jobData?['worker_phone'] as String? ?? '9876543210';
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jobSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        if (DateTime.now().difference(_lastBackgroundTime!).inMinutes >= 10) {
          print('[TRACKING] App resumed after > 10 min. Force refreshing Firestore listener.');
          _jobSub?.cancel();
          _startFirestoreListener();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isWorking = _jobData!['worker_ack'] == true && _jobData!['status'] == 'in_progress';
    final eta = _jobData!['worker_eta'] ?? 15;
    final workerName = _jobData!['worker_name'] ?? 'Ravi Kumar';

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Track Worker', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kTextPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
            
          // Mock Map Area
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              image: const DecorationImage(
                image: NetworkImage('https://www.transparenttextures.com/patterns/grid-noise.png'),
                repeat: ImageRepeat.repeat,
              ),
            ),
            child: Stack(
              children: [
                // Live badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.kDanger, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        const Text('Live', style: TextStyle(color: AppColors.kDanger, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                
                // Static blue pin (user)
                const Positioned(
                  bottom: 40,
                  right: 100,
                  child: Icon(Icons.location_on, color: AppColors.kUserPrimary, size: 40),
                ),
                
                // Amber pin (worker)
                AnimatedPositioned(
                  duration: const Duration(seconds: 1),
                  top: isWorking ? 120 : 60,
                  left: isWorking ? 220 : 80,
                  child: const Icon(Icons.directions_car, color: AppColors.kWarning, size: 36),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status pill or Cancelled Banner
                  if (_jobData!['status'] == 'cancelled' && _jobData!['canceller'] == 'worker')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.kWarningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.kWarningBorder, width: 1),
                      ),
                      child: Column(
                        children: [
                          Text('$workerName had to cancel. Finding you another worker...', 
                               textAlign: TextAlign.center,
                               style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kWarning)),
                          const SizedBox(height: 12),
                          const CircularProgressIndicator(color: AppColors.kWarning, strokeWidth: 2),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => context.go('/user/home'),
                            child: const Text('Cancel job instead', style: TextStyle(fontSize: 12, color: AppColors.kTextSecond, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isWorking ? AppColors.kSuccess.withOpacity(0.1) : AppColors.kWarningLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isWorking ? AppColors.kSuccess : AppColors.kWarningBorder, width: 1),
                        ),
                        child: Text(
                          isWorking ? 'Working now' : 'On the way · ~$eta mins',
                          style: TextStyle(
                            color: isWorking ? AppColors.kSuccess : AppColors.kWarning,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Elapsed timer card
                  if (isWorking)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.kBorder, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: AppColors.kUserPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Started 10:30 AM · $_elapsedString elapsed',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary),
                          ),
                        ],
                      ),
                    ),

                  // Worker card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.kBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.kWorkerPrimaryLight,
                          child: Text(
                            workerName.substring(0, 1),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.kWorkerPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(workerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _callWorker,
                              icon: const Icon(Icons.phone, size: 16, color: AppColors.kUserPrimary),
                              label: const Text('Call', style: TextStyle(color: AppColors.kUserPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: () => context.push('/user/chat/${widget.jobId}'),
                              icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.kUserPrimary),
                              label: const Text('Chat', style: TextStyle(color: AppColors.kUserPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  
                  // Worker no-show prompt
                  if (_jobData!['status'] == 'assigned' && _isEtaPassed && _jobData!['worker_ack'] != true)
                    Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.kWarningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.kWarningBorder, width: 1),
                      ),
                      child: Column(
                        children: [
                          const Text('Has the worker arrived yet?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kWarning)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: AppColors.kBackground,
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                      builder: (context) => Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Report Issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                                            const SizedBox(height: 16),
                                            ListTile(
                                              leading: const Icon(Icons.phone, color: AppColors.kUserPrimary),
                                              title: const Text('1. Call worker', style: TextStyle(fontWeight: FontWeight.bold)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _callWorker();
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.autorenew, color: AppColors.kDanger),
                                              title: const Text('2. Request replacement', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.kDanger)),
                                              onTap: () {
                                                print('[ERROR] Worker no show. Flagging admin and finding replacement.');
                                                Navigator.pop(context);
                                                context.go('/user/home');
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.kDanger)),
                                  child: const Text('No, report issue', style: TextStyle(color: AppColors.kDanger, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _isEtaPassed = false),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.kSuccess),
                                  child: const Text("Yes, they're here", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
