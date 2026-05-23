import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';

class IncomingRequestScreen extends StatefulWidget {
  final String jobId;
  final String skill;

  const IncomingRequestScreen({
    Key? key,
    required this.jobId,
    this.skill = 'Laptop repair',
  }) : super(key: key);

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  int _secondsLeft = 60;
  bool _isActioning = false;

  @override
  void initState() {
    super.initState();
    print('[INCOMING] Job request received: jobId=${widget.jobId}, skill=${widget.skill}');
    
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        if (!mounted) return;
        final newSecs = ((1.0 - _timerController.value) * 60).round();
        if (newSecs != _secondsLeft) {
          setState(() => _secondsLeft = newSecs);
        }
        if (_timerController.isCompleted && !_isActioning) {
          _onTimerExpired();
        }
      });
      
    _timerController.forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _onTimerExpired() async {
    if (_isActioning) return;
    setState(() => _isActioning = true);
    
    print('[INCOMING] Timer expired. Auto-dismiss.');
    await _passJob();
  }

  Future<void> _acceptJob() async {
    if (_isActioning) return;
    setState(() => _isActioning = true);
    
    print('[INCOMING] Worker tapped Accept for job: ${widget.jobId}');
    
    try {
      final jobData = await ApiService().getJob(widget.jobId);
      final expectedVersion = jobData['version'] as int? ?? 1;

      await ApiService().acceptJob(widget.jobId, expectedVersion);
      print('[INCOMING] Accept result: 200');
      if (mounted) context.go('/worker/active?job_id=${widget.jobId}');
    } catch (e) {
      if (e.toString().contains('409')) {
        print('[INCOMING] Accept result: 409 (Race condition)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Another worker accepted this job first.'),
              backgroundColor: AppColors.kWarning,
            ),
          );
          context.go('/worker/home');
        }
      } else {
        print('[INCOMING] Error accepting job: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
          setState(() => _isActioning = false);
        }
      }
    }
  }

  Future<void> _passJob() async {
    try {
      await ApiService().declineJob(widget.jobId);
      print('[INCOMING] Pass result: 200');
    } catch (e) {
      print('[INCOMING] Error passing job: $e');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request expired — waiting for next job'),
          backgroundColor: AppColors.kNeutral,
        ),
      );
      context.go('/worker/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Treat the Scaffold background as the 35% black overlay
    // Wrap with WillPopScope to prevent back button
    return WillPopScope(
      onWillPop: () async => false, // Cannot dismiss by back button
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.35),
        body: Column(
          children: [
            // Tap area above to dismiss? Prompt says "Cannot dismiss by tapping overlay."
            Expanded(child: Container()),
            
            // The Bottom Sheet UI
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.kBackground,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // URGENT HEADER BAR
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.kWorkerPrimary,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New job request!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Tap accept to confirm', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Countdown
                  Text('$_secondsLeft', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const Text('seconds to respond', style: TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                  
                  const SizedBox(height: 16),
                  
                  // Job summary card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.kBorder, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.skill, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.kWarningLight, borderRadius: BorderRadius.circular(12)),
                              child: const Text('Right now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.kWarning)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('2.1 km from you', style: TextStyle(fontSize: 14, color: AppColors.kTextSecond)),
                        const SizedBox(height: 12),
                        const Text('₹280–₹350', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kWorkerPrimary)),
                        const SizedBox(height: 8),
                        const Divider(height: 1, thickness: 0.5, color: AppColors.kBorder),
                        const SizedBox(height: 8),
                        const Text(
                          '"My laptop screen is completely blank but the keyboard is lighting up."',
                          style: TextStyle(fontSize: 12, color: AppColors.kTextSecond, fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Button row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: _isActioning ? null : _passJob,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.kNeutralBorder),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Pass', style: TextStyle(color: AppColors.kTextSecond, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isActioning ? null : _acceptJob,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kWorkerPrimary,
                              minimumSize: const Size(0, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isActioning
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Incentive warning
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Passing often reduces your job priority.',
                      style: TextStyle(fontSize: 10, color: AppColors.kWarning, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
