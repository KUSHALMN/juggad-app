import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'worker_registration_state.dart';

class WorkerRegistrationStep2 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep2({Key? key}) : super(key: key);

  @override
  ConsumerState<WorkerRegistrationStep2> createState() =>
      _WorkerRegistrationStep2State();
}

class _WorkerRegistrationStep2State
    extends ConsumerState<WorkerRegistrationStep2> {
  final List<String> _allSkills = [
    'Laptop repair',
    'Phone repair',
    'Electrician',
    'Plumber',
    'Carpenter',
    'AC service',
  ];

  final Set<String> _selectedSkills = {};
  final TextEditingController _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(workerRegistrationProvider);
    _selectedSkills.addAll(state.skills);
    if (state.hourlyRate > 0) {
      _rateController.text = state.hourlyRate.toString();
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _next() {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one skill'),
          backgroundColor: AppColors.kDanger,
        ),
      );
      return;
    }

    final rateStr = _rateController.text.trim();
    final rate = int.tryParse(rateStr) ?? 0;
    if (rate < 50 || rate > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid hourly rate (Rs 50 - Rs 2000)'),
          backgroundColor: AppColors.kDanger,
        ),
      );
      return;
    }

    ref
        .read(workerRegistrationProvider.notifier)
        .setStep2(_selectedSkills.toList(), rate);
    context.push('/worker/register/step3');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Skills & Rate',
            currentStep: 2,
            totalSteps: 3,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What do you do?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select all services you can provide.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.kTextSecond,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: _allSkills.map((skill) {
                      final isSelected = _selectedSkills.contains(skill);
                      return FilterChip(
                        label: Text(skill),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                        selectedColor:
                            AppColors.kWorkerPrimary.withOpacity(0.15),
                        checkmarkColor: AppColors.kWorkerPrimary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.kWorkerPrimary
                              : AppColors.kTextPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.kWorkerPrimary
                                : AppColors.kBorder,
                            width: isSelected ? 1.2 : 0.5,
                          ),
                        ),
                        backgroundColor: AppColors.kSurface,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Your hourly rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set a fair rate. You can change it later.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.kTextSecond,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Example: 250',
                      prefixText: 'Rs ',
                      filled: true,
                      fillColor: AppColors.kSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.kBorder,
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.kBorder,
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.kWorkerPrimary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kWorkerPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
