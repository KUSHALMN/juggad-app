import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/jugaad_step_header.dart';
import '../../../../core/services/api_service.dart';
import 'post_job_state.dart';

class PostJobStep3Screen extends ConsumerStatefulWidget {
  const PostJobStep3Screen({Key? key}) : super(key: key);

  @override
  ConsumerState<PostJobStep3Screen> createState() => _PostJobStep3ScreenState();
}

class _PostJobStep3ScreenState extends ConsumerState<PostJobStep3Screen> {
  bool _isPosting = false;

  String _formatScheduledAt(DateTime? dt) {
    if (dt == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hour:$min $period';
  }

  Future<void> _postJob() async {
    final jobState = ref.read(postJobProvider);

    setState(() => _isPosting = true);
    print('[POST_JOB] Posting job to API...');

    try {
      final res = await ApiService().createJob({
        'skill': jobState.skill.toLowerCase().replaceAll(' ', '_'),
        'description': jobState.description,
        'lat': jobState.lat,
        'lng': jobState.lng,
        'urgency': jobState.urgency,
        'scheduled_at': jobState.scheduledAt?.toIso8601String(),
      });
      final jobId = res['job_id'] ?? res['id'];
      if (jobId == null || jobId.toString().isEmpty) {
        throw Exception('Backend did not return job_id');
      }

      print('[POST_JOB] Job created: job_id=$jobId');
      ref.read(postJobProvider.notifier).reset();

      if (mounted) {
        // Navigate to matching screen with job_id
        context.go('/user/matching?job_id=$jobId');
      }
    } catch (e) {
      print('[POST_JOB] Error: $e');
      setState(() => _isPosting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't post job. Try again."),
            backgroundColor: AppColors.kDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(postJobProvider);
    final isScheduled = jobState.urgency == 'scheduled';

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Confirm your job',
            currentStep: 3,
            totalSteps: 3,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.kBorder, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(Icons.handyman, 'Service', jobState.skill),
                        const Divider(height: 24, thickness: 0.5, color: AppColors.kBorder),
                        _buildSummaryRow(
                          isScheduled ? Icons.schedule : Icons.bolt,
                          'Timing',
                          isScheduled ? _formatScheduledAt(jobState.scheduledAt) : 'Right now',
                        ),
                        const Divider(height: 24, thickness: 0.5, color: AppColors.kBorder),
                        _buildSummaryRow(Icons.location_on, 'Location', jobState.address),
                        const Divider(height: 24, thickness: 0.5, color: AppColors.kBorder),
                        _buildSummaryRow(Icons.currency_rupee, 'Estimated cost', '₹150 – ₹350'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description preview
                  if (jobState.description.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.kBorder, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.kTextTertiary)),
                          const SizedBox(height: 6),
                          Text(jobState.description, style: const TextStyle(fontSize: 13, color: AppColors.kTextPrimary, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Scheduled note
                  if (isScheduled)
                    const Text(
                      'We\'ll confirm a worker 2 hours before your slot.',
                      style: TextStyle(fontSize: 11, color: AppColors.kTextSecond),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),

          // Bottom CTA — pinned
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _postJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kUserPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isPosting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isScheduled ? 'Schedule job' : 'Post job',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.kUserPrimary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.kTextTertiary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary)),
          ],
        ),
      ],
    );
  }
}
