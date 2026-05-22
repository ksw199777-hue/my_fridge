import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'api_service.dart';

class AdService {
  static const String _bannerAdUnitId = 'id ca-app-pub-6637922570610397/3410500654';
  
  static BannerAd? _bannerAd;
  static bool _isBannerAdLoaded = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static Future<BannerAd?> loadBannerAd() async {
    // 프리미엄 이상이면 광고 안 보여줌
    if (ApiService.subscriptionType != 'free') return null;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAdLoaded = true;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdLoaded = false;
        },
      ),
    );

    await _bannerAd!.load();
    return _isBannerAdLoaded ? _bannerAd : null;
  }

  static void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
  }
}