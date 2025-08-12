// lib/ad_helper_mobile.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

class AdHelper {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  VoidCallback? _onAdLoadedCallback; // Para notificar a la UI cuando el anuncio está listo

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      print("AdHelper: MobileAds inicializado para móvil.");
      // Opcional: Configuración de dispositivos de prueba
      // List<String> testDeviceIds = ['TU_ID_DE_DISPOSITIVO_DE_PRUEBA_ANDROID_IOS'];
      // RequestConfiguration configuration = RequestConfiguration(testDeviceIds: testDeviceIds);
      // await MobileAds.instance.updateRequestConfiguration(configuration);
    } catch (e) {
      print('Error al inicializar MobileAds (móvil): $e');
    }
  }

  // MÉTODO PARA EL BANNER MÓVIL
  Widget getBannerAdWidget({
    required String adMobAdUnitId,
    VoidCallback? onAdLoaded,
  }) {
    _onAdLoadedCallback = onAdLoaded;

    // Solo crea y carga un nuevo anuncio si no existe o si el anterior falló en cargar.
    if (_bannerAd == null || !_isBannerAdLoaded) {
      // Si _bannerAd no es nulo pero _isBannerAdLoaded es falso, significa que
      // el intento anterior de carga falló. Hay que disponerlo antes de reintentar.
      if (_bannerAd != null && !_isBannerAdLoaded) {
        _bannerAd?.dispose();
        _bannerAd = null; // Para asegurar que se crea uno nuevo
      }

      _bannerAd = BannerAd(
        adUnitId: adMobAdUnitId, // Usa el ID proporcionado
        size: AdSize.banner, // O AdSize.largeBanner, AdSize.adaptiveBanner, etc.
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            print('$BannerAd cargado.');
            _isBannerAdLoaded = true;
            _onAdLoadedCallback?.call(); // Llama al callback si está definido
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            print('$BannerAd falló al cargar: $error');
            ad.dispose(); // Importante disponer del anuncio que falló
            _bannerAd = null; // Resetea _bannerAd para permitir reintentos
            _isBannerAdLoaded = false;
            _onAdLoadedCallback?.call(); // Llama al callback incluso si falla, para que la UI pueda reaccionar
          },
          // Puedes manejar otros eventos como onAdOpened, onAdClosed, etc.
        ),
      )..load(); // Carga el anuncio
    }

    // Si el anuncio está cargado y disponible, muestra AdWidget
    if (_isBannerAdLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      // Si no está cargado (o aún cargando), retorna un widget vacío o un placeholder
      return const SizedBox.shrink();
    }
  }

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
    print("AdHelper: BannerAd (móvil) dispuesto.");
  }
}
