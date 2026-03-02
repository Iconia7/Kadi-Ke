import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_auth_service.dart';
import 'app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Coin bundle product IDs — must match Play Console exactly
class CoinBundle {
  final String productId;
  final int coins;
  final String label;
  const CoinBundle({required this.productId, required this.coins, required this.label});
}

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  static const List<CoinBundle> bundles = [
    CoinBundle(productId: 'kadi_coins_500',  coins: 500,  label: 'KES 50'),
    CoinBundle(productId: 'kadi_coins_1000', coins: 1000, label: 'KES 150'),
    CoinBundle(productId: 'kadi_coins_2500', coins: 2500, label: 'KES 250'),
    CoinBundle(productId: 'kadi_coins_5000', coins: 5000, label: 'KES 500'),
  ];

  static const String kadiPassProductId = 'kadi_pass_premium';
  static const String kadiPassUltraProductId = 'kadi_pass_ultra';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> _products = [];
  bool _available = false;
  bool _loading = false;

  List<ProductDetails> get products => _products;
  bool get available => _available;
  bool get loading => _loading;

  /// Called by the UI to show purchase result feedback
  Function(String message, bool success)? onPurchaseResult;

  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (e) => debugPrint('[IAP] Stream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    _loading = true;
    final ids = bundles.map((b) => b.productId).toSet();
    ids.add(kadiPassProductId);
    ids.add(kadiPassUltraProductId); // Added Ultra Pass ID
    final response = await _iap.queryProductDetails(ids);

    if (response.error != null) {
      debugPrint('[IAP] Product load error: ${response.error}');
    }

    _products = response.productDetails;
    _loading = false;
    debugPrint('[IAP] Loaded ${_products.length} products');
  }

  Future<void> purchaseCoins(String productId) async {
    if (!_available) {
      onPurchaseResult?.call('Google Play not available on this device.', false);
      return;
    }

    final matches = _products.where((p) => p.id == productId).toList();
    if (matches.isEmpty) {
      onPurchaseResult?.call('Product not available. Please try again later.', false);
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: matches.first);
    await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: false);
  }

  Future<void> purchasePass({bool ultra = false}) async {
    if (!_available) {
      onPurchaseResult?.call('Google Play not available.', false);
      return;
    }

    final id = ultra ? kadiPassUltraProductId : kadiPassProductId;
    final matches = _products.where((p) => p.id == id).toList();
    if (matches.isEmpty) {
      onPurchaseResult?.call('Battle Pass not found in store.', false);
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: matches.first);
    if (ultra) {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('[IAP] Pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
          final success = await _verifyAndCredit(purchase);
          onPurchaseResult?.call(
            success
                ? '✅ Coins added to your wallet!'
                : '❌ Verification failed. Contact support if coins are missing.',
            success,
          );
          if (purchase is GooglePlayPurchaseDetails) {
             await _iap.completePurchase(purchase);
          } else if (Platform.isIOS) {
             await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown error';
          onPurchaseResult?.call('Purchase failed: $msg', false);
          if (purchase is GooglePlayPurchaseDetails || Platform.isIOS) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.restored:
        case PurchaseStatus.canceled:
          if (purchase is GooglePlayPurchaseDetails || Platform.isIOS) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Sends purchase token to our server for verification before crediting coins.
  Future<bool> _verifyAndCredit(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return false;

      String? purchaseToken;
      if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
        purchaseToken = purchase.billingClientPurchase.purchaseToken;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/iap/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': purchase.productID,
          'purchaseToken': purchaseToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' || data['status'] == 'already_credited') {
          await CustomAuthService().fetchCloudWallet();
          return true;
        }
      }
      debugPrint('[IAP] Server verification failed: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[IAP] Verification error: $e');
      return false;
    }
  }

  void dispose() => _subscription?.cancel();
}
