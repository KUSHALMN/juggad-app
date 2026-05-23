import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/jugaad_step_header.dart';
import 'post_job_state.dart';

class PostJobStep2Screen extends ConsumerStatefulWidget {
  const PostJobStep2Screen({Key? key}) : super(key: key);

  @override
  ConsumerState<PostJobStep2Screen> createState() => _PostJobStep2ScreenState();
}

class _PostJobStep2ScreenState extends ConsumerState<PostJobStep2Screen> {
  final TextEditingController _descController = TextEditingController();
  bool _loadingLocation = false;
  bool _locationDenied = false;
  String _address = 'Vijayanagar, Mysuru'; // Default Mysuru pilot area

  @override
  void initState() {
    super.initState();
    final current = ref.read(postJobProvider);
    _address = current.address;
    _descController.text = current.description;
    // Try fetching real location
    _fetchLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLocation = true);
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() {
          _loadingLocation = false;
          _locationDenied = true;
          _address = '';
        });
        print('[ERROR] Location denied. Showing manual input.');
        return;
      }

      setState(() => _locationDenied = false);

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final addr = place != null
          ? '${place.subLocality ?? place.locality}, ${place.administrativeArea}'
          : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';

      setState(() {
        _address = addr;
        _loadingLocation = false;
      });

      ref.read(postJobProvider.notifier).setLocation(pos.latitude, pos.longitude, addr);
    } catch (e) {
      print('[POST_JOB] Location fetch failed: $e — using default');
      setState(() => _loadingLocation = false);
    }
  }

  void _next() {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what you need help with'),
          backgroundColor: AppColors.kDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ref.read(postJobProvider.notifier).setDescription(desc);
    final state = ref.read(postJobProvider);
    print('[POST_JOB] Step 2: description set, location: ${state.address} (${state.lat}, ${state.lng})');
    context.push('/user/post-job/step3');
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(postJobProvider);

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Tell us more',
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
                  // Selected skill chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.kUserPrimaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.kUserBorder, width: 0.5),
                    ),
                    child: Text(
                      jobState.skill,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.kUserPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description textarea
                  const Text(
                    'Describe the issue',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 5,
                    minLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'e.g. My laptop screen is flickering and won\'t turn on...',
                      hintStyle: const TextStyle(color: AppColors.kTextTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.kSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.kUserPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location row
                  const Text(
                    'Your location',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary),
                  ),
                  const SizedBox(height: 8),
                  
                  if (_locationDenied)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.kDangerLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.kDanger, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.kDanger, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Location access denied. We need this to find workers near you.', style: TextStyle(fontSize: 12, color: AppColors.kDanger, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => Geolocator.openAppSettings(),
                                child: const Text('Open settings', style: TextStyle(fontSize: 12, color: AppColors.kUserPrimary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Or type your area', style: TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                        const SizedBox(height: 8),
                        TextField(
                          onChanged: (val) {
                            setState(() => _address = val);
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. Kuvempunagar, Mysuru',
                            hintStyle: const TextStyle(color: AppColors.kTextTertiary, fontSize: 13),
                            filled: true,
                            fillColor: AppColors.kSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.kBorder, width: 0.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.kUserPrimary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.kBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.kUserPrimary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _loadingLocation
                                ? const Text('Detecting location...', style: TextStyle(fontSize: 13, color: AppColors.kTextTertiary))
                                : Text(_address, style: const TextStyle(fontSize: 13, color: AppColors.kTextPrimary)),
                          ),
                          GestureDetector(
                            onTap: _fetchLocation,
                            child: const Text(
                              'Change',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kUserPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Budget hint card (amber tint)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.kWarningLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.kWarningBorder, width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.kWarning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Workers in your area charge ₹150–₹350 for ${jobState.skill.isNotEmpty ? jobState.skill.toLowerCase() : 'this'}.',
                            style: const TextStyle(fontSize: 12, color: AppColors.kWarning, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Next button pinned to bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ElevatedButton(
              onPressed: (_locationDenied && _address.trim().isEmpty) ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kUserPrimary,
                disabledBackgroundColor: AppColors.kBorder,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                (_locationDenied && _address.trim().isEmpty) ? 'Set location to continue' : 'Next → Confirm Job',
                style: TextStyle(
                  color: (_locationDenied && _address.trim().isEmpty) ? AppColors.kTextSecond : Colors.white,
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
