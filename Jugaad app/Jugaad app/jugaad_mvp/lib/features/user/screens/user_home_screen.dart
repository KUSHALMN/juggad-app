import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';

// --- RIVERPOD PROVIDERS ---

// Dummy location for MVP: 'Vijayanagar, Mysuru'
final nearbyWorkersProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('workers')
        .where('status', isEqualTo: 'online')
        .get();
    
    final Map<String, int> counts = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final skills = data['skills'] as List<dynamic>? ?? [];
      for (var skill in skills) {
        final skillStr = skill.toString();
        counts[skillStr] = (counts[skillStr] ?? 0) + 1;
      }
    }
    return counts;
  } catch (e) {
    print('[HOME] Error loading nearby workers: $e');
    return {};
  }
});

final recentJobsProvider = StreamProvider<QuerySnapshot>((ref) {
  final uid = AuthService().currentUser?.uid;
  if (uid == null) return const Stream.empty();
  final stream = FirebaseFirestore.instance
      .collection('jobs')
      .where('user_id', isEqualTo: uid)
      .where('status', whereIn: ['completed', 'cancelled'])
      .orderBy('created_at', descending: true)
      .limit(2)
      .snapshots();

  final sub = stream.listen((snapshot) {
    print('[HOME] Recent jobs stream: ${snapshot.docs.length} docs');
  }, onError: (e) {
    print('[HOME] Recent jobs stream error: $e');
  });

  ref.onDispose(() => sub.cancel());

  return stream;
});

// --- SCREEN WIDGET ---

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set status bar to blue tint for User Mode
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Hi User 👋',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: AppColors.kTextSecond,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    const Text(
                      'What do you need help with?',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Speed Signal Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: AppColors.kWarningLight,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: AppColors.kWarningBorder, width: 0.5),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, color: AppColors.kWarning, size: 20),
                          SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              'Workers near you — avg arrival ~20 mins',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.kWarning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Search Bar
                    InkWell(
                      onTap: () => context.push('/user/post-job/step1'),
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        height: 44.0,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: AppColors.kSurface,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: AppColors.kBorder, width: 0.5),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, color: AppColors.kTextTertiary, size: 20),
                            SizedBox(width: 12.0),
                            Text(
                              'Search for a skill...',
                              style: TextStyle(color: AppColors.kTextTertiary, fontSize: 14.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    // Services Grid Header
                    const Text(
                      'SERVICES',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kTextTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],
                ),
              ),
            ),
            
            // Services Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  _buildServiceCard(context, ref, 'Laptop repair', Icons.laptop_mac),
                  _buildServiceCard(context, ref, 'Phone repair', Icons.phone_android),
                  _buildServiceCard(context, ref, 'Electrician', Icons.electrical_services),
                  _buildServiceCard(context, ref, 'Plumber', Icons.plumbing),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECENT',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kTextTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    _buildRecentJobsList(ref),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, WidgetRef ref, String title, IconData icon) {
    final countsAsync = ref.watch(nearbyWorkersProvider);

    return InkWell(
      onTap: () {
        // Mock routing to /user/post-job with skill
        print('[NAV] Navigating to /user/post-job/step1 with skill=$title');
        context.push('/user/post-job/step1');
      },
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.kSurface,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: AppColors.kBorder, width: 0.5),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.kUserPrimary, size: 32.0),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                color: AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            countsAsync.when(
              data: (counts) => Text(
                '${counts[title] ?? 0} nearby',
                style: const TextStyle(fontSize: 9.0, color: AppColors.kUserPrimary),
              ),
              loading: () => Shimmer.fromColors(
                baseColor: AppColors.kSurface2,
                highlightColor: AppColors.kSurface,
                child: Container(width: 40, height: 10, color: Colors.white),
              ),
              error: (_, __) => const Text('Unknown', style: TextStyle(fontSize: 9.0, color: AppColors.kTextTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentJobsList(WidgetRef ref) {
    final recentAsync = ref.watch(recentJobsProvider);

    return recentAsync.when(
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          // Empty state
          return Center(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.kUserPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: const Text('Book your first job', style: TextStyle(color: AppColors.kUserPrimary)),
            ),
          );
        }

        return Column(
          children: snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.kSurface2,
                child: Icon(Icons.history, color: AppColors.kTextSecond),
              ),
              title: Text(data['skill'] ?? 'Unknown Job', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(data['status'] ?? 'Completed', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.kTextTertiary),
            );
          }).toList(),
        );
      },
      loading: () => Shimmer.fromColors(
        baseColor: AppColors.kSurface2,
        highlightColor: AppColors.kSurface,
        child: Column(
          children: [
            Container(height: 60, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 8.0)),
            Container(height: 60, width: double.infinity, color: Colors.white),
          ],
        ),
      ),
      error: (_, __) => const Text('Failed to load recent jobs', style: TextStyle(color: AppColors.kDanger)),
    );
  }
}
