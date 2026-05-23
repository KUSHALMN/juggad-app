import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class CompletionScreen extends StatefulWidget {
  final String jobId;
  final String workerName;
  final int durationMinutes;

  const CompletionScreen({
    Key? key,
    required this.jobId,
    required this.workerName,
    required this.durationMinutes,
  }) : super(key: key);

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    
    // Start animation after a tiny delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    
    print('[COMPLETION] Review submitted: rating=$_rating');
    
    try {
      // Use set with merge in case the job doesn't exist yet in mock
      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).set({
        'rating': _rating,
        'review_text': _reviewController.text.trim(),
        'status': 'completed_reviewed',
      }, SetOptions(merge: true));
    } catch (e) {
      print('[COMPLETION] Firebase error ignored in mock: $e');
    }
    
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (mounted) {
      context.go('/user/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Success Animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.kSuccess.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.kSuccess, size: 56),
                ),
              ),
              const SizedBox(height: 24),
              
              // Job Done Text
              const Text(
                'Job done!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.workerName} · Laptop repair · ${widget.durationMinutes} mins',
                style: const TextStyle(fontSize: 13, color: AppColors.kTextSecond),
              ),
              const SizedBox(height: 8),
              const Text(
                'Worker arrived in 12 minutes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kSuccess),
              ),
              
              const SizedBox(height: 48),
              
              // Rating stars
              const Text('Tap to rate your experience', style: TextStyle(fontSize: 11, color: AppColors.kTextTertiary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: index < _rating ? AppColors.kWarning : AppColors.kTextTertiary,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 24),
              
              // Review input
              TextField(
                controller: _reviewController,
                maxLines: 2,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional: Leave a review...',
                  hintStyle: const TextStyle(color: AppColors.kTextTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.kSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.kUserPrimary, width: 1)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              
              const Spacer(),
              
              // CTAs
              ElevatedButton(
                onPressed: (_rating > 0 && !_isSubmitting) ? _submitReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kUserPrimary,
                  disabledBackgroundColor: AppColors.kUserPrimary.withOpacity(0.5),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/user/post-job/step1'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.kUserPrimary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Book again', style: TextStyle(color: AppColors.kUserPrimary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
