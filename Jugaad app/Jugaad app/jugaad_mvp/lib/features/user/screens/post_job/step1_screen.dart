import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/jugaad_step_header.dart';
import 'post_job_state.dart';

class PostJobStep1Screen extends ConsumerStatefulWidget {
  const PostJobStep1Screen({Key? key}) : super(key: key);

  @override
  ConsumerState<PostJobStep1Screen> createState() => _PostJobStep1ScreenState();
}

class _PostJobStep1ScreenState extends ConsumerState<PostJobStep1Screen> {
  String _urgency = 'now'; // 'now' | 'scheduled'
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  static const _services = [
    {'title': 'Laptop repair', 'icon': Icons.laptop_mac},
    {'title': 'Phone repair', 'icon': Icons.phone_android},
    {'title': 'Electrician', 'icon': Icons.electrical_services},
    {'title': 'Plumber', 'icon': Icons.plumbing},
  ];

  void _selectService(String skill) {
    final urgency = _urgency;
    DateTime? scheduledAt;

    if (urgency == 'scheduled' && _scheduledDate != null && _scheduledTime != null) {
      scheduledAt = DateTime(
        _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
        _scheduledTime!.hour, _scheduledTime!.minute,
      );
    }

    ref.read(postJobProvider.notifier).setSkill(skill);
    ref.read(postJobProvider.notifier).setUrgency(urgency);
    ref.read(postJobProvider.notifier).setScheduledAt(scheduledAt);

    print('[POST_JOB] Step 1: skill=$skill, urgency=$urgency, scheduledAt=$scheduledAt');
    context.push('/user/post-job/step2');
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _scheduledDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) setState(() => _scheduledTime = time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'What do you need help with?',
            currentStep: 1,
            totalSteps: 3,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Grid 2x2
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.3,
                    children: _services.map((s) {
                      final title = s['title'] as String;
                      final icon = s['icon'] as IconData;
                      return InkWell(
                        onTap: () => _selectService(title),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.kSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.kBorder, width: 0.5),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: AppColors.kUserPrimary, size: 32),
                              const Spacer(),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Urgency Label
                  const Text(
                    'How soon?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pill Toggle
                  Row(
                    children: [
                      _buildUrgencyPill('Right now', 'now'),
                      const SizedBox(width: 8),
                      _buildUrgencyPill('Schedule for later', 'scheduled'),
                    ],
                  ),

                  // Date/time picker when scheduled
                  if (_urgency == 'scheduled') ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPickerTile(
                            label: _scheduledDate == null
                                ? 'Pick date'
                                : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                            icon: Icons.calendar_today,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPickerTile(
                            label: _scheduledTime == null
                                ? 'Pick time'
                                : _scheduledTime!.format(context),
                            icon: Icons.access_time,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text(
                    'Tap a service to continue →',
                    style: TextStyle(fontSize: 11, color: AppColors.kTextTertiary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyPill(String label, String value) {
    final selected = _urgency == value;
    return GestureDetector(
      onTap: () => setState(() => _urgency = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.kUserPrimary : AppColors.kBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.kUserPrimary : AppColors.kBorder,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.kTextSecond,
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.kUserBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.kUserPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.kTextPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
