import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages rewarded ads (post-match double coins, free daily coins)
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Test IDs (safe to use before AdMob approval) ──────────────────────────
  // TODO: Replace these with real unit IDs once your AdMob app is approved
  static const String _rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'   // Google test ID
      : 'ca-app-pub-2572570007063815/8893007295';         // ← Replace with production ID

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Call once at app start (in main.dart after WidgetsFlutterBinding.ensureInitialized)
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    AdService().loadRewardedAd();
  }

  void loadRewardedAd() {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;

    debugPrint('[AdService] Loading rewarded ad with Unit ID: $_rewardedAdUnitId');

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          debugPrint('[AdService] Rewarded ad loaded SUCCESSFULLY');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('[AdService] FAILED to load ad: $error');
          debugPrint('[AdService] Error code: ${error.code}');
          debugPrint('[AdService] Domain: ${error.domain}');
          
          if (error.code == 3) {
            debugPrint('[AdService] Tip: Code 3 (No Fill) often means the app is new or needs "app-ads.txt" verification.');
          }
          
          // Retry after 60 seconds
          Future.delayed(const Duration(seconds: 60), loadRewardedAd);
        },
      ),
    );
  }

  /// Shows the rewarded ad. [onRewarded] is called ONLY if the user
  /// watches the full ad. [onFailed] is called if no ad is available.
  Future<void> showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onFailed,
  }) async {
    if (_rewardedAd == null) {
      debugPrint('[AdService] No ad ready');
      loadRewardedAd(); // pre-load for next time
      onFailed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Pre-load next ad immediately
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onFailed?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        onRewarded();
      },
    );
  }

  bool get isAdReady => _rewardedAd != null;

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
