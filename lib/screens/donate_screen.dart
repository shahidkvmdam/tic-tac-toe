import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme_utils.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  // TODO: Replace with your actual UPI ID
  static const String upiId = 'shahid.kvmdam-1@okaxis';
  static const String payeeName = 'Tic Tac Toe Developer';
  
  // PayPal for international users
  static const String paypalLink = 'https://paypal.me/sentinelll';

  Future<void> _launchUPI(BuildContext context, {String? amount}) async {
    HapticFeedback.mediumImpact();

    // Format amount with 2 decimal places for UPI compatibility
    final formattedAmount = amount != null ? '${amount}.00' : null;

    final uri = Uri.parse(
      'upi://pay'
      '?pa=$upiId'
      '&pn=${Uri.encodeComponent(payeeName)}'
      '&tn=${Uri.encodeComponent("Support Tic Tac Toe Development")}'
      '&cu=INR'
      '${formattedAmount != null ? '&am=$formattedAmount' : ''}',
    );

    debugPrint('Launching UPI URI: $uri');

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('UPI Launch Error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open UPI app. Please make sure Google Pay, PhonePe, or Paytm is installed.',
            ),
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

  void _showUpiOptions(BuildContext context) {
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
              'Pay via UPI',
              style: TextStyle(
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
                _launchUPI(context);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.phone_android,
              title: 'PhonePe',
              color: const Color(0xFF673AB7),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.payment,
              title: 'Paytm',
              color: const Color(0xFF00BCD4),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context);
              },
            ),
            const SizedBox(height: 12),
            _UpiOption(
              icon: Icons.apps,
              title: 'Any UPI App',
              color: const Color(0xFF6750A4),
              onTap: () {
                Navigator.of(ctx).pop();
                _launchUPI(context);
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
                      
                      // India - UPI Section
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
                            const SizedBox(height: 16),
                            // Preset donation amounts
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
                                  onTap: () => _launchUPI(context, amount: '10'),
                                ),
                                _DonationButton(
                                  amount: '50',
                                  label: 'Buy me a Coffee',
                                  icon: Icons.coffee,
                                  color: const Color(0xFF795548),
                                  onTap: () => _launchUPI(context, amount: '50'),
                                ),
                                _DonationButton(
                                  amount: '100',
                                  label: 'Support Development',
                                  icon: Icons.favorite,
                                  color: const Color(0xFFE91E63),
                                  onTap: () => _launchUPI(context, amount: '100'),
                                ),
                                _DonationButton(
                                  amount: '500',
                                  label: 'Become a Sponsor',
                                  icon: Icons.star,
                                  color: const Color(0xFFFFC107),
                                  onTap: () => _launchUPI(context, amount: '500'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
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
