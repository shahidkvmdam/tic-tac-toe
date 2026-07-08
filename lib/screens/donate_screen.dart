import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../utils/theme_utils.dart';
import '../services/razorpay_service.dart';
import '../services/billing_service.dart';
import '../services/auth_service.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  static const String upiId = '9608801985@upi';
  static const String payeeName = 'MD SHAHID';
  static const String paypalLink = 'https://paypal.me/sentinelll';
  static const String buyMeCoffeeLink = 'https://buymeacoffee.com/sentinelll';

  final RazorpayService _razorpayService = RazorpayService();
  final BillingService _billingService = BillingService.instance;
  final TextEditingController _customAmountController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isProcessing = false;
  bool _isBillingLoading = true;
  String? _billingError;

  @override
  void initState() {
    super.initState();
    _initBilling();
  }

  Future<void> _initBilling() async {
    try {
      await _billingService.initialize();
      if (mounted) {
        setState(() {
          _isBillingLoading = false;
          _billingError = _billingService.isAvailable
              ? null
              : 'In-app billing is not available on this device.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBillingLoading = false;
          _billingError = 'Failed to load billing products.';
        });
      }
    }
  }

  @override
  void dispose() {
    _razorpayService.clear();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _launchUPI(BuildContext context, {String? amount}) async {
    HapticFeedback.mediumImpact();

    // mode=01 tells GPay this is P2P (person-to-person), not merchant payment
    String uriStr = 'upi://pay?pa=$upiId&pn=$payeeName&cu=INR&mode=01';
    if (amount != null) {
      uriStr += '&am=$amount';
    }

    debugPrint('Launching UPI URI: $uriStr');

    try {
      final launched = await launchUrlString(
        uriStr,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open any UPI application.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('UPI Launch Error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI Error: $e'),
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              'Enter your phone number for UPI payment',
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

  void _showBillingError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _buyBadge(ProductDetails product) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final started = await _billingService.purchase(product);
      if (!started) {
        _showBillingError('Purchase could not be started.');
      }
    } catch (e) {
      _showBillingError('Purchase error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
              _showPaymentOptions(amount);
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

  void _showUpiOptions(BuildContext context, {String? amount}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              amount != null ? 'Pay ₹$amount via UPI' : 'Pay via UPI',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred UPI app',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _UpiOption(
              icon: Icons.account_balance_wallet,
              title: 'Google Pay',
              color: const Color(0xFF1B5E20),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context, amount: amount);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.phone_android,
              title: 'PhonePe',
              color: const Color(0xFF673AB7),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context, amount: amount);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.payment,
              title: 'Paytm',
              color: const Color(0xFF00BCD4),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context, amount: amount);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.apps,
              title: 'Any UPI App',
              color: const Color(0xFF6750A4),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context, amount: amount);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentOptions(int amount) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pay ₹$amount',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a payment method',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _UpiOption(
              icon: Icons.credit_card,
              title: 'Razorpay (UPI / Card / Wallet)',
              color: const Color(0xFF0284C7),
              onTap: () {
                Navigator.of(ctx).pop();
                _payWithRazorpay(amount);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.account_balance_wallet,
              title: 'UPI App (GPay / PhonePe / Paytm)',
              color: const Color(0xFF6D28D9),
              onTap: () {
                Navigator.of(ctx).pop();
                _showUpiOptions(context, amount: amount.toString());
              },
            ),
          ],
        ),
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
          child: Stack(
            children: [
              Column(
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

                          // Heart icon
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

                          // Thank you text
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
                            'Your support helps keep this app free and ad-free. Every contribution, no matter how small, is greatly appreciated!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Play Store support tiers (badges)
                          if (_isBillingLoading)
                            const CircularProgressIndicator(color: Colors.white70)
                          else if (_billingError != null)
                            Text(
                              _billingError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.workspace_premium,
                                          color: Color(0xFFFFD700),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Unlock a Supporter Badge',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildBadgeCard(
                                    'support-bronze-50',
                                    'Bronze Supporter',
                                    '₹50',
                                    const Color(0xFFCD7F32),
                                    'bronze',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildBadgeCard(
                                    'support-silver-100',
                                    'Silver Supporter',
                                    '₹100',
                                    const Color(0xFFC0C0C0),
                                    'silver',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildBadgeCard(
                                    'support-gold-250',
                                    'Gold Supporter',
                                    '₹250',
                                    const Color(0xFFFFD700),
                                    'gold',
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Preset donation amounts
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEC407A).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Color(0xFFEC407A),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Choose Amount',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
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
                                      onTap: () => _showPaymentOptions(10),
                                    ),
                                    _DonationButton(
                                      amount: '50',
                                      label: 'Buy me a Coffee',
                                      icon: Icons.coffee,
                                      color: const Color(0xFF795548),
                                      onTap: () => _showPaymentOptions(50),
                                    ),
                                    _DonationButton(
                                      amount: '100',
                                      label: 'Support Development',
                                      icon: Icons.favorite,
                                      color: const Color(0xFFE91E63),
                                      onTap: () => _showPaymentOptions(100),
                                    ),
                                    _DonationButton(
                                      amount: '500',
                                      label: 'Become a Sponsor',
                                      icon: Icons.star,
                                      color: const Color(0xFFFFC107),
                                      onTap: () => _showPaymentOptions(500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Custom amount button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showCustomAmountDialog(),
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // UPI Direct Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9933).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '🇮🇳',
                                        style: TextStyle(fontSize: 24),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'India (UPI)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Pay directly via UPI app (GPay, PhonePe, Paytm)',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showUpiOptions(context),
                                    icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                                    label: const Text(
                                      'Open UPI App',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Show UPI ID
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance,
                                        size: 18,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'UPI: $upiId',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy,
                                          size: 18,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: upiId),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('UPI ID copied!'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // International Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.language,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'International',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _launchUrl(buyMeCoffeeLink),
                                    icon: const Icon(Icons.coffee, color: Color(0xFFFFDD00)),
                                    label: const Text(
                                      'Buy Me a Coffee',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(
                                        color: const Color(0xFFFFDD00).withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _launchUrl(paypalLink),
                                    icon: const Icon(Icons.paypal, color: Colors.white),
                                    label: const Text(
                                      'PayPal',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Thank you note
                          Text(
                            '❤️ Made with love in Flutter',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
    String productId,
    String title,
    String price,
    Color color,
    String badge,
  ) {
    final product = _billingService.products
        .cast<ProductDetails?>()
        .firstWhere((p) => p?.id == productId, orElse: () => null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: _badgeIcon(badge, color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unlock $badge badge',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (product != null)
            FilledButton(
              onPressed: _isProcessing ? null : () => _buyBadge(product),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: badge == 'gold' ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Text(
              'Loading...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _badgeIcon(String badge, Color color) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 4),
        ),
      ),
    );
  }
}

class _UpiOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _UpiOption({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
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
