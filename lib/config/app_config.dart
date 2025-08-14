// lib/config/app_config.dart
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // --- Configuración Global de Anuncios ---
  static const bool adsEnabled = true; // Interruptor maestro para todos los anuncios

  // --- Configuración Específica por Plataforma (solo aplica si adsEnabled es true) ---
  static const bool adsEnabledAndroid = true; // Habilitar para Android (AdMob)
  static const bool adsEnabledIOS = true; // Habilitar para iOS (AdMob) - añade si es necesario
  static const bool adsEnabledWeb = true; // Habilitar para Web (AdSense)

  // Determina si los anuncios están activos para la plataforma actual
  static bool get areAdsActiveForCurrentPlatform {
    if (!adsEnabled) return false; // Globalmente deshabilitados

    if (kIsWeb) {
      return adsEnabledWeb;
    } else {
      // Para plataformas móviles (Android/iOS)
      // Puedes usar Platform.isAndroid y Platform.isIOS si necesitas lógica más específica
      // import 'dart:io' show Platform;
      // if (Platform.isAndroid) return adsEnabledAndroid;
      // if (Platform.isIOS) return adsEnabledIOS;
      // Por ahora, asumimos que si no es web, es móvil y usa la misma lógica de AdMob
      return adsEnabledAndroid; // O una combinación si tienes adsEnabledIOS
    }
  }

// Opcional: IDs de aplicación de AdMob (¡Usa tus IDs reales de AdMob!)
// Estos NO son los IDs de las unidades de anuncios, sino el ID de la app.
// Encuéntralos en tu dashboard de AdMob.
// static const String admobAppIdAndroid = "ca-app-pub-3940256099942544~3347511713"; // EJEMPLO
// static const String admobAppIdIOS = "ca-app-pub-3940256099942544~1458002511"; // EJEMPLO

// Asegúrate de haber añadido estos IDs en:
// Android: android/app/src/main/AndroidManifest.xml
// <meta-data
//     android:name="com.google.android.gms.ads.APPLICATION_ID"
//     android:value="YOUR_ADMOB_APP_ID"/>
//
// iOS: ios/Runner/Info.plist
// <key>GADApplicationIdentifier</key>
// <string>YOUR_ADMOB_APP_ID</string>
}
