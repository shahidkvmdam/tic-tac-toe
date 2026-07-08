import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  static const String _keyId = 'rzp_test_T9VIJP9RHzV3kz';

  final Razorpay _razorpay = Razorpay();

  void openCheckout({
    required int amountInPaise,
    required String name,
    required String description,
    required String email,
    required String contact,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required Function() onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      debugPrint('Razorpay success: ${response.paymentId}');
      onSuccess(response);
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      debugPrint('Razorpay error: ${response.code} - ${response.message}');
      onFailure(response);
    });

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      debugPrint('Razorpay external wallet: ${response.walletName}');
      onExternalWallet();
    });

    try {
      final options = {
        'key': _keyId,
        'amount': amountInPaise,
        'name': name,
        'description': description,
        'prefill': {
          'email': email,
          'contact': contact,
        },
        'theme': {
          'color': '#6D28D9',
        },
        'currency': 'INR',
        'method': {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
        },
        'config': {
          'display': {
            'blocks': {
              'upi': {
                'name': 'Pay by UPI',
                'instruments': [
                  {'method': 'upi', 'flows': ['collect', 'intent']},
                ],
              },
            },
            'sequence': ['upi', 'card', 'netbanking', 'wallet'],
            'preferences': {
              'show_default_blocks': true,
            },
          },
        },
      };

      debugPrint('Razorpay options: $options');

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      onFailure(PaymentFailureResponse(0, 'Failed to open payment: $e', null));
    }
  }

  void clear() {
    _razorpay.clear();
  }
}
