import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class BillingService {
  static final BillingService instance = BillingService._internal();
  BillingService._internal();

  static const List<String> _productIds = [
    'support-bronze-50',
    'support-silver-100',
    'support-gold-250',
  ];

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  firebase_auth.User? get currentUser => _auth.currentUser;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _initialized = false;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('In-app purchase not available');
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSub?.cancel(),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!_isAvailable) return;
    final response = await _iap.queryProductDetails(_productIds.toSet());
    _products = response.productDetails;
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  Future<bool> purchase(ProductDetails product) async {
    if (!_isAvailable) {
      throw Exception('In-app purchase is not available on this device');
    }
    final purchaseParam = PurchaseParam(productDetails: product);
    return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndUnlockBadge(purchase);
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error?.message}');
          break;
        case PurchaseStatus.canceled:
          debugPrint('Purchase canceled');
          break;
        case PurchaseStatus.pending:
          debugPrint('Purchase pending');
          break;
      }
    }
  }

  Future<void> _verifyAndUnlockBadge(PurchaseDetails purchase) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final badge = _badgeForProduct(purchase.productID);
    if (badge == null) return;

    await _db.collection('users').doc(uid).set({
      'badges': FieldValue.arrayUnion([badge]),
      'purchases': {
        purchase.productID: {
          'purchasedAt': FieldValue.serverTimestamp(),
          'badge': badge,
          'status': purchase.status.name,
        }
      }
    }, SetOptions(merge: true));

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  String? _badgeForProduct(String productId) {
    switch (productId) {
      case 'support-bronze-50':
        return 'bronze';
      case 'support-silver-100':
        return 'silver';
      case 'support-gold-250':
        return 'gold';
      default:
        return null;
    }
  }

  Stream<List<String>> userBadgesStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data();
      final badges = data?['badges'];
      if (badges is List) {
        return badges.whereType<String>().toList();
      }
      return [];
    });
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}
