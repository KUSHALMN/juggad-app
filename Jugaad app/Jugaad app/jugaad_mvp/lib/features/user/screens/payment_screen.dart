import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final double amount;
  
  const PaymentScreen({Key? key, required this.jobId, required this.amount}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String _paymentMethod = 'upi';
  bool _paymentFailed = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('[PAYMENT] Razorpay result: SUCCESS - ${response.paymentId}');
    setState(() {
      _isProcessing = false;
      _paymentFailed = false;
    });
    // Navigate to Completion screen
    context.go('/user/completion?job_id=${widget.jobId}&worker_name=Ravi%20Kumar&duration=45');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('[PAYMENT] Razorpay result: ERROR - ${response.code} - ${response.message}');
    setState(() {
      _isProcessing = false;
      _paymentFailed = true;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('[PAYMENT] Razorpay result: WALLET - ${response.walletName}');
  }

  Future<void> _startPayment() async {
    setState(() {
      _isProcessing = true;
      _paymentFailed = false;
    });

    const razorpayKey = String.fromEnvironment('RAZORPAY_KEY_ID');
    if (razorpayKey.isEmpty) {
      print('[PAYMENT] Missing RAZORPAY_KEY_ID dart-define. Checkout blocked.');
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
      return;
    }

    try {
      final order = await ApiService().createRazorpayOrder(widget.jobId);
      final orderId = order['order_id'] as String?;
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Backend returned empty order_id');
      }
      print('[PAYMENT] Razorpay order created: $orderId');

      final options = {
        'key': razorpayKey,
        'order_id': orderId,
        'amount': order['amount'],
        'name': 'Jugaad Services',
        'description': 'Payment for job ${widget.jobId}',
        'prefill': {
          'contact': AuthService().currentUser?.phoneNumber ?? '',
          'email': AuthService().currentUser?.email ?? 'support@jugaad.app'
        }
      };

      _razorpay.open(options);
    } catch (e) {
      print('[PAYMENT] Error launching razorpay: $e');
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    const platformFee = 18.0;
    final serviceFee = widget.amount;
    final displayTotal = serviceFee + platformFee;

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Payment', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.kTextPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Trust row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            color: AppColors.kSurface2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: AppColors.kSuccess, size: 16),
                SizedBox(width: 8),
                Text("You'll only be charged after the job is done", style: TextStyle(fontSize: 12, color: AppColors.kTextSecond)),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_paymentFailed) _buildPaymentFailedState(),
                  
                  // Price breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.kBorder, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPriceRow('Service fee', '₹${serviceFee.toStringAsFixed(2)}'),
                        const SizedBox(height: 12),
                        _buildPriceRow('Platform fee', '₹${platformFee.toStringAsFixed(2)}'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: AppColors.kBorder, thickness: 0.5),
                        ),
                        _buildPriceRow('Total', '₹${displayTotal.toStringAsFixed(2)}', isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Payment methods
                  const Text('Select payment method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
                  const SizedBox(height: 16),
                  
                  _buildPaymentMethodTile('UPI', Icons.account_balance, 'upi'),
                  const SizedBox(height: 12),
                  _buildPaymentMethodTile('Credit/Debit Card', Icons.credit_card, 'card'),
                  const SizedBox(height: 12),
                  _buildPaymentMethodTile('Wallet', Icons.account_balance_wallet, 'wallet'),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kUserPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Pay ₹${displayTotal.toStringAsFixed(2)} securely', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                const Text('Powered by Razorpay', style: TextStyle(fontSize: 11, color: AppColors.kTextTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFailedState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kDangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kDanger, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: AppColors.kDanger, size: 20),
              SizedBox(width: 8),
              Text('Payment unsuccessful', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kDanger)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('UPI transaction was declined.', style: TextStyle(fontSize: 13, color: AppColors.kDanger)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kUserPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Try again', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _paymentFailed = false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.kUserPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Use different method', style: TextStyle(color: AppColors.kUserPrimary, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.kWarningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Your job slot is held for 5 minutes.', style: TextStyle(fontSize: 11, color: AppColors.kWarning, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.kTextPrimary : AppColors.kTextSecond,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: AppColors.kTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(String title, IconData icon, String value) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.kUserPrimaryLight.withOpacity(0.5) : AppColors.kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.kUserPrimary : AppColors.kBorder, width: isSelected ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.kUserPrimary : AppColors.kTextTertiary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.kUserPrimary : AppColors.kTextPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.kUserPrimary, size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: AppColors.kTextTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
