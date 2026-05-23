import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class ActiveJobScreen extends StatefulWidget {
  final String jobId;

  const ActiveJobScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> with WidgetsBindingObserver {
  StreamSubscription<DocumentSnapshot>? _jobSub;
  Map<String, dynamic>? _jobData;
  
  Timer? _elapsedTimer;
  String _elapsedString = '00:00';
  bool _isActioning = false;
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
      
      print('[ACTIVE_JOB] Status: ${data['status']}, worker_ack: ${data['worker_ack']}');
      print('[ACTIVE_JOB] Payment received: ${data['payment_status']}');
      
      setState(() => _jobData = data);

      if (data['worker_ack'] == true && data['status'] == 'in_progress') {
        _startElapsedTimer(data['started_at'] as Timestamp?);
      }
      
      if (data['payment_status'] == 'paid') {
        _handlePaymentReceived();
      }
    }, onError: (e) {
      print('[ACTIVE_JOB] Error listening: $e');
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

  Future<void> _callCustomer() async {
    final phone = _jobData?['customer_phone'] as String? ?? '9876543210';
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _markArrived() async {
    setState(() => _isActioning = true);
    print('[ACTIVE_JOB] Arrived. Sending ack...');
    
    try {
      await ApiService().ackJob(widget.jobId);
    } catch (e) {
      print('[ACTIVE_JOB] Ack failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark arrived: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _showCompletionSheet() {
    final amount = _jobData?['amount'] ?? 350;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: AppColors.kBackground,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ready to mark this job as done?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
            const SizedBox(height: 16),
            Text('You\'ll earn ₹$amount for this job.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kSuccess)),
            const SizedBox(height: 8),
            const Text('Customer will confirm on their end.', style: TextStyle(fontSize: 11, color: AppColors.kTextSecond)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markCompleted();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kSuccess,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm completion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not yet', style: TextStyle(color: AppColors.kTextTertiary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markCompleted() async {
    setState(() => _isActioning = true);
    print('[ACTIVE_JOB] Marking completed...');
    
    try {
      await ApiService().completeJob(widget.jobId);
    } catch (e) {
      print('[ACTIVE_JOB] Complete failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete job: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _simulatePaymentReceived() {
    print('[ACTIVE_JOB] Payment received: paid');
    _handlePaymentReceived();
  }

  void _handlePaymentReceived() {
    final amount = _jobData?['amount'] ?? 350;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('₹$amount added to your earnings!'), backgroundColor: AppColors.kSuccess),
    );
    if (mounted) context.go('/worker/home');
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
          print('[ACTIVE_JOB] App resumed after > 10 min. Force refreshing Firestore listener.');
          _jobSub?.cancel();
          _startFirestoreListener();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobData == null) {
      return const Scaffold(backgroundColor: AppColors.kBackground, body: Center(child: CircularProgressIndicator()));
    }

    final status = _jobData!['status'] as String? ?? 'assigned';
    final workerAck = _jobData!['worker_ack'] as bool? ?? false;

    if (status == 'assigned' || (status == 'in_progress' && !workerAck)) {
      return _buildEnRouteState();
    } else if (status == 'in_progress' && workerAck) {
      return _buildWorkingState();
    } else if (status == 'completed') {
      return _buildWrapUpState();
    }

    // Fallback
    return const Scaffold(backgroundColor: AppColors.kBackground, body: Center(child: Text('Unknown state')));
  }

  // ─── STATE 1: EN ROUTE ─────────────────────────────────────
  Widget _buildEnRouteState() {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kTextPrimary),
          onPressed: () => context.go('/worker/home'),
        ),
        title: const Text('Active Job', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16)),
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            height: 48,
            color: AppColors.kWarningLight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Head to the job', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kWarning)),
                Text('2.1 km away', style: TextStyle(fontSize: 13, color: AppColors.kWarning)),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.kBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.kUserPrimaryLight,
                              child: Text(_jobData!['customer_name'].substring(0, 1), style: const TextStyle(color: AppColors.kUserPrimary, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_jobData!['customer_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary))),
                            GestureDetector(
                              onTap: _callCustomer,
                              child: const Text('Call customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.kUserPrimary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 0.5, color: AppColors.kBorder),
                        const SizedBox(height: 12),
                        Text(_jobData!['address'], style: const TextStyle(fontSize: 14, color: AppColors.kTextSecond)),
                        const SizedBox(height: 16),
                        // Mock Map Thumbnail
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.kSurface2,
                            borderRadius: BorderRadius.circular(10),
                            image: const DecorationImage(
                              image: NetworkImage('https://www.transparenttextures.com/patterns/grid-noise.png'),
                              repeat: ImageRepeat.repeat,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.location_on, color: AppColors.kWarning, size: 32),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Job details
                  Text(_jobData!['service'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const SizedBox(height: 8),
                  Text(_jobData!['description'], style: const TextStyle(fontSize: 13, color: AppColors.kTextSecond, fontStyle: FontStyle.italic), maxLines: 2),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ElevatedButton(
              onPressed: _isActioning ? null : _markArrived,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kSuccess,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isActioning
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("I've arrived", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATE 2: WORKING ──────────────────────────────────────
  Widget _buildWorkingState() {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kTextPrimary),
          onPressed: () => context.go('/worker/home'),
        ),
        title: const Text('Active Job', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 48,
            color: AppColors.kSuccess.withOpacity(0.1),
            alignment: Alignment.center,
            child: const Text('Job in progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kSuccess)),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.kBorder, width: 1),
                      ),
                      child: Text('Started 10:30 AM · $_elapsedString elapsed', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Compact Customer Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.kBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.kUserPrimaryLight,
                          child: Text(_jobData!['customer_name'].substring(0, 1), style: const TextStyle(color: AppColors.kUserPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_jobData!['customer_name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary))),
                        GestureDetector(
                          onTap: _callCustomer,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: AppColors.kUserPrimaryLight, shape: BoxShape.circle),
                            child: const Icon(Icons.phone, color: AppColors.kUserPrimary, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ElevatedButton(
              onPressed: _isActioning ? null : _showCompletionSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kSuccess,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Mark as completed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATE 3: WRAP-UP ──────────────────────────────────────
  Widget _buildWrapUpState() {
    final amount = _jobData!['amount'] ?? 350;
    
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kTextPrimary),
          onPressed: () => context.go('/worker/home'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.kSuccess.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('Job marked complete!', style: TextStyle(color: AppColors.kSuccess, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            const Text('Waiting for customer to pay...', style: TextStyle(fontSize: 13, color: AppColors.kTextSecond)),
            const SizedBox(height: 12),
            Text('₹$amount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.kSuccess)),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: AppColors.kSuccess),
          ],
        ),
      ),
    );
  }
}
