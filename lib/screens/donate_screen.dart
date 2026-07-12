import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../utils/theme_utils.dart';
import '../services/razorpay_service.dart';
import '../services/auth_service.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final RazorpayService _razorpayService = RazorpayService();
  final TextEditingController _customAmountController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _razorpayService.clear();
    _customAmountController.dispose();
    super.dispose();
  }

  void _payWithRazorpay(int amountInRupees) {
    if (amountInRupees < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount (minimum ₹1)')),
      );
      return;
    }

    final user = _authService.currentUser;
    final email = user?.email ?? '';
    String contact = '';
    if (user?.phoneNumber != null) {
      contact = user!.phoneNumber!;
      if (contact.startsWith('+91')) {
        contact = contact.substring(3);
      }
    }

    if (contact.isEmpty) {
      _promptPhoneAndPay(amountInRupees, email);
    } else {
      _openRazorpay(amountInRupees, email, contact);
    }
  }

  void _promptPhoneAndPay(int amountInRupees, String email) {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Phone Number', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your phone number for Razorpay payment',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                prefixText: '+91 ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 18),
                hintText: '9876543210',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              phoneController.dispose();
              Navigator.of(ctx).pop();
              setState(() => _isProcessing = false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              if (phone.length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
                );
                return;
              }
              phoneController.dispose();
              Navigator.of(ctx).pop();
              _openRazorpay(amountInRupees, email, phone);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _openRazorpay(int amountInRupees, String email, String contact) {
    setState(() => _isProcessing = true);

    _razorpayService.openCheckout(
      amountInPaise: amountInRupees * 100,
      name: 'Tic Tac Toe',
      description: 'Support Development - ₹$amountInRupees',
      email: email,
      contact: contact,
      onSuccess: (PaymentSuccessResponse response) {
        setState(() => _isProcessing = false);
        if (mounted) {
          _showPaymentSuccess(response.paymentId ?? 'N/A');
        }
      },
      onFailure: (PaymentFailureResponse response) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      onExternalWallet: () {
        setState(() => _isProcessing = false);
      },
    );
  }

  void _showPaymentSuccess(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thank You!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment was successful',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Payment ID: $paymentId',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomAmountDialog() {
    _customAmountController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Custom Amount', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter amount in ₹ (minimum ₹1)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 24),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 24),
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 24),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(_customAmountController.text.trim()) ?? 0;
              if (amount < 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount (minimum ₹1)')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              _payWithRazorpay(amount);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
            ),
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: appBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Support Developer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC407A).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 50,
                          color: Color(0xFFEC407A),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Thank You!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Your support helps keep this app free and ad-free. Choose an amount to contribute securely via Razorpay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          _DonationButton(
                            amount: '10',
                            label: 'Buy me a Tea',
                            icon: Icons.local_cafe,
                            color: const Color(0xFF4CAF50),
                            onTap: () => _payWithRazorpay(10),
                          ),
                          _DonationButton(
                            amount: '50',
                            label: 'Buy me a Coffee',
                            icon: Icons.coffee,
                            color: const Color(0xFF795548),
                            onTap: () => _payWithRazorpay(50),
                          ),
                          _DonationButton(
                            amount: '100',
                            label: 'Support Development',
                            icon: Icons.favorite,
                            color: const Color(0xFFE91E63),
                            onTap: () => _payWithRazorpay(100),
                          ),
                          _DonationButton(
                            amount: '500',
                            label: 'Become a Sponsor',
                            icon: Icons.star,
                            color: const Color(0xFFFFC107),
                            onTap: () => _payWithRazorpay(500),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : () => _showCustomAmountDialog(),
                          icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                          label: const Text(
                            'Custom Amount',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      if (_isProcessing) ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(color: Color(0xFF6D28D9)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationButton extends StatelessWidget {
  final String amount;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DonationButton({
    required this.amount,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              '₹$amount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
