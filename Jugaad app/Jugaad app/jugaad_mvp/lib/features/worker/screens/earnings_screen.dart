import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({Key? key}) : super(key: key);

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  // Mock mode for local preview
  final bool _isMockMode = false;
  String? _upiId;
  int _balance = 0;
  int _pendingBalance = 0;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please login to view earnings')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('workers').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          _balance = data['balance'] as int? ?? 0;
          _pendingBalance = data['pending_balance'] as int? ?? 0;
          _upiId = data['upi_id'] as String?;
        }

        return Scaffold(
          backgroundColor: AppColors.kBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Earnings', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.kWorkerPrimaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.kWorkerBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL BALANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.kTextSecond)),
                      const SizedBox(height: 8),
                      Text('₹$_balance', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.kWorkerPrimary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('₹$_pendingBalance pending', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kWarning)),
                          const SizedBox(width: 16),
                          const Text('Paid out via UPI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kTextSecond)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: _balance > 0 ? _requestPayout : null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _balance > 0 ? AppColors.kWorkerPrimary : AppColors.kBorder, width: 1.5),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Request payout →', 
                            style: TextStyle(
                              color: _balance > 0 ? AppColors.kWorkerPrimary : AppColors.kTextTertiary, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Payout Info Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.kSurface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.kBorder, width: 0.5),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: AppColors.kTextTertiary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Payouts process every Monday via UPI to your registered number.',
                          style: TextStyle(fontSize: 11, color: AppColors.kTextSecond, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Jobs List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('RECENT JOBS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.kTextSecond)),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History page coming soon')));
                        },
                        child: const Text('See all completed →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.kWorkerPrimary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Jobs List Content
                _buildJobsList(uid),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      }
    );
  }

  void _requestPayout() {
    if (_balance <= 0) return;

    if (_upiId == null || _upiId!.isEmpty) {
      _showUpiDialog();
    } else {
      _processPayoutRequest();
    }
  }

  void _showUpiDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter UPI ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'yourname@upi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final upi = controller.text.trim();
              if (upi.isNotEmpty) {
                final uid = AuthService().currentUser?.uid;
                if (uid != null) {
                  FirebaseFirestore.instance.collection('workers').doc(uid).update({'upi_id': upi});
                  setState(() => _upiId = upi);
                }
                Navigator.pop(context);
                _processPayoutRequest();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _processPayoutRequest() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance.collection('payout_requests').add({
      'worker_id': uid,
      'amount': _balance,
      'upi_id': _upiId,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payout requested — processed every Monday'),
        backgroundColor: AppColors.kSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildJobsList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('worker_id', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading jobs'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.kWorkerPrimary)));
        }

        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No completed jobs yet.', style: TextStyle(color: AppColors.kTextTertiary)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final paymentStatus = data['payment_status'] as String? ?? 'pending';
            
            return _EarningJobRow(
              service: data['skill'] as String? ?? 'Service',
              date: 'Recent', // For MVP, normally parse created_at timestamp
              amount: data['amount'] as int? ?? 0,
              isPaid: paymentStatus == 'paid',
            );
          },
        );
      },
    );
  }
}

class _EarningJobRow extends StatelessWidget {
  final String service;
  final String date;
  final int amount;
  final bool isPaid;

  const _EarningJobRow({
    required this.service,
    required this.date,
    required this.amount,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBorder, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$amount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPaid ? AppColors.kSuccess.withOpacity(0.1) : AppColors.kWarningLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPaid ? 'Paid' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? AppColors.kSuccess : AppColors.kWarning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
