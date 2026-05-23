import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';

// ─── MATCHING STATES ────────────────────────────────────────
enum MatchingState { searching, expanding, assigned }

// ─── MATCHING SCREEN ─────────────────────────────────────────

class MatchingScreen extends StatefulWidget {
  final String jobId;
  const MatchingScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Firestore ────────────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _jobSub;
  Map<String, dynamic> _jobData = {};
  Map<String, dynamic>? _workerData;

  // ── UI State ─────────────────────────────────────────────
  MatchingState _matchingState = MatchingState.searching;

  // ── 90s Fallback Timer ───────────────────────────────────
  Timer? _fallbackTimer;
  int _fallbackSecondsLeft = 90;
  Timer? _fallbackCountTimer;

  // ── 60s Accept Countdown ─────────────────────────────────
  late AnimationController _acceptCountdown;   // drains 1→0 in 60s
  late AnimationController _acceptPulse;       // scale pulse at <10s

  // ── Pulse ring animation ─────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseRadius;
  late Animation<double> _pulseOpacity;

  bool _isActioning = false;
  DateTime? _lastBackgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _startFirestoreListener();
    _startFallbackTimer();

    // --- DEV SHORTCUT: Press F in debug console to test state B ---
    // Uncomment below to auto-simulate worker assignment after 5s
    // Future.delayed(const Duration(seconds: 5), _simulateWorkerAssigned);
  }

  void _initAnimations() {
    // Pulse ring
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _pulseRadius = Tween<double>(begin: 28, end: 44).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Accept countdown (60s drain)
    _acceptCountdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onCountdownExpired();
      });

    // Pulse scale when <10s
    _acceptPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
  }

  void _startFirestoreListener() {
    if (widget.jobId.isEmpty) return;

    _jobSub = FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      final status = data['status'] as String? ?? 'searching';
      final fallback = data['fallback_triggered'] as bool? ?? false;
      final version = data['version'];

      print('[MATCHING] Job status changed: $status, version: $version');
      print('[MATCHING] fallback_triggered: $fallback');

      _updateState(status, fallback, data);
    }, onError: (e) {
      print('[MATCHING] Listener error: $e');
    });
  }

  void _updateState(String status, bool fallback, Map<String, dynamic> data) {
    setState(() => _jobData = data);

    if (status == 'in_progress') {
      if (mounted) context.go('/user/tracking?job_id=${widget.jobId}');
      return;
    } else if (status == 'completed') {
      final amount = data['payment_amount'] ?? data['amount'] ?? 0;
      if (mounted) context.go('/user/payment?job_id=${widget.jobId}&amount=$amount');
      return;
    } else if (status == 'cancelled' || status == 'scheduled') {
      if (mounted) context.go('/user/home');
      return;
    }

    MatchingState newState;
    if (status == 'assigned' || status == 'manually_assigned') {
      newState = MatchingState.assigned;
    } else if (fallback) {
      newState = MatchingState.expanding;
    } else {
      newState = MatchingState.searching;
    }

    if (newState != _matchingState) {
      print('[MATCHING] Transitioning to state: $newState');
      setState(() {
        _matchingState = newState;
        _isActioning = false;
      });

      if (newState == MatchingState.expanding) {
        _pulseController.duration = const Duration(milliseconds: 2500);
        _pulseRadius = Tween<double>(begin: 28, end: 56).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
        );
        _pulseController.repeat();
      }

      if (newState == MatchingState.assigned) {
        _fallbackTimer?.cancel();
        _fallbackCountTimer?.cancel();
        _acceptCountdown.reset();
        _acceptCountdown.forward();
        final workerId = data['worker_id'];
        if (workerId != null) {
          _fetchWorkerDetails(workerId);
        }
      }
    }
  }

  Future<void> _fetchWorkerDetails(String workerId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('workers').doc(workerId).get();
      if (doc.exists && mounted) {
        setState(() {
          _workerData = doc.data();
          // Provide some defaults if missing
          _workerData!['name'] ??= 'Worker';
          _workerData!['specialty'] ??= _jobData['skill'] ?? 'Helper';
          _workerData!['rating'] ??= 4.5;
          _workerData!['jobs_done'] ??= 0;
          _workerData!['distance_km'] ??= 2.0;
          _workerData!['eta_mins'] ??= 15;
          _workerData!['initials'] ??= (_workerData!['name'] as String).substring(0, 1).toUpperCase();
        });
      }
    } catch (e) {
      print('[MATCHING] Error fetching worker $workerId: $e');
    }
  }

  void _startFallbackTimer() {
    _fallbackSecondsLeft = 90;
    _fallbackTimer?.cancel();
    _fallbackCountTimer?.cancel();

    _fallbackTimer = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      // Note: Real fallback is handled by backend Cloud Function/Logic
    });

    // Decrement countdown every second
    _fallbackCountTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_fallbackSecondsLeft > 0) _fallbackSecondsLeft--;
      });
    });
  }

  void _simulateWorkerAssigned() {
    if (!mounted) return;
    print('[MATCHING] Job status changed: assigned, version: 2');
    print('[MATCHING] Transitioning to state: MatchingState.assigned');
    setState(() => _matchingState = MatchingState.assigned);
    _fallbackTimer?.cancel();
    _fallbackCountTimer?.cancel();
    _acceptCountdown.forward();
  }

  void _onCountdownExpired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time expired — restarting search'),
        backgroundColor: AppColors.kUserPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _acceptCountdown.reset();
    setState(() => _matchingState = MatchingState.searching);
    _startFallbackTimer();
  }

  Future<void> _cancelJob() async {
    print('[MATCHING] Cancelling job: ${widget.jobId}');
    try {
      await ApiService().deleteJob(widget.jobId);
    } catch (e) {
      print('[MATCHING] Error cancelling job: $e');
    }
    if (mounted) context.go('/user/home');
  }

  Future<void> _acceptWorker() async {
    setState(() => _isActioning = true);
    print('[MATCHING] Accepting worker for job: ${widget.jobId}');
    
    try {
      final expectedVersion = _jobData['version'] as int? ?? 1;
      await ApiService().acceptJob(widget.jobId, expectedVersion);
      if (mounted) {
        // Navigate to tracking screen
        context.go('/user/tracking?job_id=${widget.jobId}');
      }
    } catch (e) {
      print('[MATCHING] Error accepting worker: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        if (e.toString().contains('409')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Version mismatch or job already modified.'),
              backgroundColor: AppColors.kWarning,
            ),
          );
          // Revert to searching
          setState(() => _matchingState = MatchingState.searching);
          _startFallbackTimer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _declineWorker() async {
    setState(() => _isActioning = true);
    try {
      await ApiService().declineJob(widget.jobId);
      // The Firestore listener will pick up the 'searching' state, no manual UI state change needed here.
    } catch (e) {
      print('[MATCHING] Error declining job: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _requestCallback() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Callback requested'),
        content: const Text('Our team will call you shortly to confirm a worker.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertToScheduled() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    print('[MATCHING] Job converted to scheduled at: $scheduledAt');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job scheduled for ${scheduledAt.day}/${scheduledAt.month} at ${time.format(context)}'),
          backgroundColor: AppColors.kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/user/home');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jobSub?.cancel();
    _fallbackTimer?.cancel();
    _fallbackCountTimer?.cancel();
    _pulseController.dispose();
    _acceptCountdown.dispose();
    _acceptPulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        if (DateTime.now().difference(_lastBackgroundTime!).inMinutes >= 10) {
          print('[MATCHING] App resumed after > 10 min. Force refreshing Firestore listener.');
          _jobSub?.cancel();
          _startFirestoreListener();
        }
      }
    }
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: switch (_matchingState) {
          MatchingState.searching  => _buildSearching(false),
          MatchingState.expanding  => _buildSearching(true),
          MatchingState.assigned   => _buildAssigned(),
        },
      ),
    );
  }

  // ─── STATE A / A2: SEARCHING ─────────────────────────────
  Widget _buildSearching(bool isExpanding) {
    final skill = _jobData['skill'] as String? ?? 'Service';
    final urgency = _jobData['urgency'] as String? ?? 'now';

    return Column(
      children: [

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing ring animation
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return SizedBox(
                      width: isExpanding ? 80 : 64,
                      height: isExpanding ? 80 : 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer pulse ring
                          Opacity(
                            opacity: _pulseOpacity.value.clamp(0.0, 1.0),
                            child: Container(
                              width: _pulseRadius.value * 2,
                              height: _pulseRadius.value * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.kUserPrimary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Inner solid dot
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: AppColors.kUserPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                Text(
                  isExpanding ? 'Still looking...' : 'Finding a worker nearby...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  isExpanding
                      ? "We've expanded your search radius."
                      : 'Usually takes under 2 minutes',
                  style: const TextStyle(fontSize: 13, color: AppColors.kTextSecond),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Progress bar
                if (!isExpanding)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.kSurface2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.kUserPrimary),
                    ),
                  ),

                const SizedBox(height: 32),

                // Job summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.kBorder, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _jobSummaryRow(Icons.handyman, 'Service', skill),
                      const SizedBox(height: 8),
                      _jobSummaryRow(Icons.bolt, 'Urgency', urgency == 'now' ? 'Right now' : 'Scheduled'),
                      const SizedBox(height: 8),
                      _jobSummaryRow(Icons.access_time, 'Posted', 'Just now'),
                    ],
                  ),
                ),

                // Fallback cards (STATE A2 only)
                if (isExpanding) ...[
                  const SizedBox(height: 24),
                  _buildScheduleCard(),
                  const SizedBox(height: 8),
                  _buildCallbackCard(),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() => _matchingState = MatchingState.expanding);
                      _startFallbackTimer();
                    },
                    child: const Text(
                      'Keep searching',
                      style: TextStyle(fontSize: 12, color: AppColors.kTextTertiary),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Fallback countdown (only state A)
                if (!isExpanding)
                  Text(
                    'Expanding search in ${_fallbackSecondsLeft}s if no match found',
                    style: const TextStyle(fontSize: 11, color: AppColors.kTextTertiary),
                  ),

                const SizedBox(height: 16),

                // Cancel link
                TextButton(
                  onPressed: _cancelJob,
                  child: const Text(
                    'Cancel job',
                    style: TextStyle(fontSize: 13, color: AppColors.kDanger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kWarningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kWarningBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.schedule, size: 20, color: AppColors.kWarning),
              SizedBox(width: 10),
              Text('Schedule for a specific time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kWarning)),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 30),
            child: Text('We guarantee a worker for your preferred slot.', style: TextStyle(fontSize: 11, color: AppColors.kWarning)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _convertToScheduled,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.kWarning),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Pick a time →', style: TextStyle(color: AppColors.kWarning, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallbackCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kUserPrimaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kUserBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.phone, size: 20, color: AppColors.kUserPrimary),
              SizedBox(width: 10),
              Text("We'll match you manually", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kUserPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 30),
            child: Text('Our team will call to confirm a worker.', style: TextStyle(fontSize: 11, color: AppColors.kUserPrimary)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _requestCallback,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.kUserPrimary),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Request callback →', style: TextStyle(color: AppColors.kUserPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATE B: WORKER ASSIGNED ────────────────────────────
  Widget _buildAssigned() {
    final worker = _workerData ?? {};
    final name = worker['name'] as String? ?? 'Worker';
    final specialty = worker['specialty'] as String? ?? _jobData['skill'] ?? 'Helper';
    final rating = worker['rating']?.toString() ?? '4.5';
    final jobsDone = worker['jobs_done']?.toString() ?? '0';
    final distance = worker['distance_km']?.toString() ?? '2.0';
    final eta = worker['eta_mins']?.toString() ?? '15';
    final initials = worker['initials'] as String? ?? (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'W');
    final countdown = _acceptCountdown.value;
    final _ = ((1.0 - countdown) * 60).round(); // secsLeft available if needed

    return Column(
      children: [
        // Green banner
        Container(
          width: double.infinity,
          height: 56,
          color: AppColors.kWorkerPrimary,
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Worker found!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Accept within 60 seconds', style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),

        // Countdown bar
        AnimatedBuilder(
          animation: _acceptCountdown,
          builder: (context, _) {
            final secs = ((1.0 - _acceptCountdown.value) * 60).round();
            Color barColor = AppColors.kSuccess;
            if (secs <= 30) barColor = AppColors.kWarning;
            if (secs <= 10) barColor = AppColors.kDanger;
            return LinearProgressIndicator(
              value: 1.0 - _acceptCountdown.value,
              minHeight: 4,
              backgroundColor: AppColors.kSurface2,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            );
          },
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Worker card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.kBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.kBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.kWorkerPrimaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.kWorkerBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.kWorkerPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                                Text(specialty, style: const TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Stats row (3 signals)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statChip(Icons.star, rating, AppColors.kWarning),
                          _statChip(Icons.check_circle_outline, '$jobsDone jobs', AppColors.kSuccess),
                          _statChip(Icons.near_me, '$distance km', AppColors.kUserPrimary),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ETA row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.kBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Text('ETA', style: TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
                            const Spacer(),
                            Text(
                              '~$eta mins away',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Button row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isActioning ? null : _acceptWorker,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kWorkerPrimary,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isActioning
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Accept worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _isActioning ? null : _declineWorker,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.kNeutralBorder),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Decline', style: TextStyle(color: AppColors.kTextSecond)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('Declining resumes search.', style: TextStyle(fontSize: 11, color: AppColors.kTextTertiary)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Widget _jobSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.kTextTertiary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kTextPrimary)),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }
}
