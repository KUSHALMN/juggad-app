import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class JugaadStepHeader extends StatelessWidget {
  final String title;
  final int currentStep; // 1-based
  final int totalSteps;
  final VoidCallback? onBack;

  const JugaadStepHeader({
    Key? key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: back + step label
            Row(
              children: [
                if (onBack != null)
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.kBorder, width: 0.5),
                      ),
                      child: const Icon(Icons.arrow_back, size: 18, color: AppColors.kTextPrimary),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.kBorder, width: 0.5),
                  ),
                  child: Text(
                    'Step $currentStep/$totalSteps',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kTextSecond,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.kTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            // Progress dots
            Row(
              children: List.generate(totalSteps, (index) {
                final active = index < currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? AppColors.kUserPrimary : AppColors.kSurface2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
