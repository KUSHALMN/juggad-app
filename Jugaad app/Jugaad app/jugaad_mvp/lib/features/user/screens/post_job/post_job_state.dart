import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- DATA MODEL ---
class PostJobData {
  final String skill;
  final String urgency; // 'now' | 'scheduled'
  final DateTime? scheduledAt;
  final String description;
  final double lat;
  final double lng;
  final String address;

  const PostJobData({
    this.skill = '',
    this.urgency = 'now',
    this.scheduledAt,
    this.description = '',
    this.lat = 12.3375, // Default: Vijayanagar, Mysuru
    this.lng = 76.6120,
    this.address = 'Vijayanagar, Mysuru',
  });

  PostJobData copyWith({
    String? skill,
    String? urgency,
    DateTime? scheduledAt,
    String? description,
    double? lat,
    double? lng,
    String? address,
  }) {
    return PostJobData(
      skill: skill ?? this.skill,
      urgency: urgency ?? this.urgency,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toApiPayload(String userId) => {
    'user_id': userId,
    'skill': skill,
    'urgency': urgency,
    'scheduled_at': scheduledAt?.toIso8601String(),
    'description': description,
    'location': {'lat': lat, 'lng': lng, 'address': address},
    'status': 'pending_match',
  };
}

// --- STATE NOTIFIER (Riverpod v2: Notifier) ---
class PostJobNotifier extends Notifier<PostJobData> {
  @override
  PostJobData build() => const PostJobData();

  void setSkill(String skill) {
    state = state.copyWith(skill: skill);
    print('[POST_JOB] Skill set: $skill');
  }

  void setUrgency(String urgency) {
    state = state.copyWith(urgency: urgency);
  }

  void setScheduledAt(DateTime? dt) {
    state = state.copyWith(scheduledAt: dt);
  }

  void setDescription(String desc) {
    state = state.copyWith(description: desc);
  }

  void setLocation(double lat, double lng, String address) {
    state = state.copyWith(lat: lat, lng: lng, address: address);
    print('[POST_JOB] Step 2: description set, location: $address ($lat, $lng)');
  }

  void reset() {
    state = const PostJobData();
  }
}

// --- PROVIDER ---
final postJobProvider = NotifierProvider<PostJobNotifier, PostJobData>(
  PostJobNotifier.new,
);
