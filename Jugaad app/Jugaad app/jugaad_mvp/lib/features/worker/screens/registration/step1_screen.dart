import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'worker_registration_state.dart';

class WorkerRegistrationStep1 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep1({Key? key}) : super(key: key);

  @override
  ConsumerState<WorkerRegistrationStep1> createState() => _WorkerRegistrationStep1State();
}

class _WorkerRegistrationStep1State extends ConsumerState<WorkerRegistrationStep1> {
  final TextEditingController _nameController = TextEditingController();
  final String _phone = AuthService().currentUser?.phoneNumber ?? '+919876543210';
  
  final List<String> _areas = [
    'Vijayanagar, Mysuru',
    'Kuvempunagar, Mysuru',
    'Jayalakshmipuram, Mysuru',
    'Gokulam, Mysuru'
  ];
  String _selectedArea = 'Vijayanagar, Mysuru';

  @override
  void initState() {
    super.initState();
    final state = ref.read(workerRegistrationProvider);
    if (state.fullName.isNotEmpty) _nameController.text = state.fullName;
    _selectedArea = _areas.contains(state.area) ? state.area : _areas.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name'), backgroundColor: AppColors.kDanger),
      );
      return;
    }

    ref.read(workerRegistrationProvider.notifier).setStep1(name, _selectedArea);
    context.push('/worker/register/step2');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Basic Information',
            currentStep: 1,
            totalSteps: 3,
            onBack: () {
              if (context.canPop()) context.pop();
              else context.go('/splash');
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ravi Kumar',
                      filled: true,
                      fillColor: AppColors.kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.kWorkerPrimary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _phone),
                    readOnly: true,
                    style: const TextStyle(color: AppColors.kTextSecond),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.kSurface2, // Grayed out
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: const Icon(Icons.check_circle, color: AppColors.kSuccess, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Operating Area', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.kBorder, width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedArea,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.kTextTertiary),
                        items: _areas.map((area) => DropdownMenuItem(
                          value: area,
                          child: Text(area, style: const TextStyle(fontSize: 14, color: AppColors.kTextPrimary)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedArea = val);
                        },
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Next → Skills & Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
