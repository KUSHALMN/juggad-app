import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkerRegistrationData {
  final String fullName;
  final String area;
  final List<String> skills;
  final int hourlyRate;
  final String? idDocUrl;

  const WorkerRegistrationData({
    this.fullName = '',
    this.area = 'Vijayanagar, Mysuru', // Default
    this.skills = const [],
    this.hourlyRate = 150,
    this.idDocUrl,
  });

  WorkerRegistrationData copyWith({
    String? fullName,
    String? area,
    List<String>? skills,
    int? hourlyRate,
    String? idDocUrl,
  }) {
    return WorkerRegistrationData(
      fullName: fullName ?? this.fullName,
      area: area ?? this.area,
      skills: skills ?? this.skills,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      idDocUrl: idDocUrl ?? this.idDocUrl,
    );
  }
}

class WorkerRegistrationNotifier extends Notifier<WorkerRegistrationData> {
  @override
  WorkerRegistrationData build() => const WorkerRegistrationData();

  void setStep1(String name, String area) {
    state = state.copyWith(fullName: name, area: area);
    print('[REGISTRATION] Step 1: name=$name, area=$area');
  }

  void setStep2(List<String> skills, int rate) {
    state = state.copyWith(skills: skills, hourlyRate: rate);
    print('[REGISTRATION] Step 2: skills=$skills, rate=$rate');
  }

  void setStep3(String docUrl) {
    state = state.copyWith(idDocUrl: docUrl);
    print('[REGISTRATION] Step 3: ID uploaded: $docUrl');
  }

  void reset() {
    state = const WorkerRegistrationData();
  }
}

final workerRegistrationProvider = NotifierProvider<WorkerRegistrationNotifier, WorkerRegistrationData>(
  WorkerRegistrationNotifier.new,
);
