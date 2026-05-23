import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'worker_registration_state.dart';

class WorkerRegistrationStep3 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep3({Key? key}) : super(key: key);

  @override
  ConsumerState<WorkerRegistrationStep3> createState() => _WorkerRegistrationStep3State();
}

class _WorkerRegistrationStep3State extends ConsumerState<WorkerRegistrationStep3> {
  String? _uploadedFileName;
  String? _uploadedFileUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  String _normalizeArea(String area) {
    return area.toLowerCase().replaceAll(',', '').replaceAll(' ', '_');
  }

  String _normalizeSkill(String skill) {
    return skill.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> _pickFile() async {
    try {
      setState(() => _isUploading = true);
      
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final fileBytes = result.files.single.bytes;
      if (fileBytes == null) {
        throw Exception("Could not read file data");
      }
      
      final fileName = result.files.single.name;
      final uid = AuthService().currentUser?.uid ?? 'unknown_worker';
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('worker_ids')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      await storageRef.putData(fileBytes);
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _uploadedFileName = fileName;
        _uploadedFileUrl = downloadUrl;
        _isUploading = false;
      });

      ref.read(workerRegistrationProvider.notifier).setStep3(_uploadedFileUrl!);
    } catch (e) {
      print('Error picking/uploading file: $e');
      setState(() => _isUploading = false);
    }
  }

  Future<void> _submit() async {
    if (_uploadedFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an ID document'), backgroundColor: AppColors.kDanger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    final state = ref.read(workerRegistrationProvider);
    final uid = AuthService().currentUser?.uid;
    final phone = AuthService().currentUser?.phoneNumber;

    if (uid == null || phone == null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session expired. Please log in again.'), backgroundColor: AppColors.kDanger),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('workers').doc(uid).set({
        'worker_id': uid,
        'name': state.fullName,
        'phone': phone,
        'area': _normalizeArea(state.area),
        'skills': state.skills.map(_normalizeSkill).toList(),
        'rate_per_hour': state.hourlyRate,
        'id_document_url': state.idDocUrl,
        'approval_status': 'pending',
        'status': 'offline',
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('[REGISTRATION] Submitted. approval_status=pending');
    } catch (e) {
      print('[REGISTRATION] Firestore error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: AppColors.kDanger),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    ref.read(workerRegistrationProvider.notifier).reset();
    if (mounted) {
      context.go('/worker/register/success');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'ID Verification',
            currentStep: 3,
            totalSteps: 3,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload any government ID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const SizedBox(height: 8),
                  const Text('We need this to verify your identity. This is kept secure and never shared with users.', style: TextStyle(fontSize: 13, color: AppColors.kTextSecond)),
                  const SizedBox(height: 24),
                  
                  GestureDetector(
                    onTap: _isUploading ? null : _pickFile,
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _uploadedFileUrl == null ? AppColors.kSurface : AppColors.kSuccess.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _uploadedFileUrl == null ? AppColors.kBorder : AppColors.kSuccess,
                          width: 1,
                        ),
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.kWorkerPrimary))
                          : _uploadedFileUrl != null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.kSuccess, size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      _uploadedFileName ?? 'Document uploaded',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.kSuccess),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.upload_file, color: AppColors.kTextTertiary, size: 32),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap to upload Aadhaar / Voter ID / DL',
                                      style: TextStyle(fontSize: 12, color: AppColors.kTextSecond),
                                    ),
                                  ],
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
              onPressed: (_isSubmitting || _uploadedFileUrl == null) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kSuccess,
                disabledBackgroundColor: AppColors.kSuccess.withOpacity(0.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit for approval', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
