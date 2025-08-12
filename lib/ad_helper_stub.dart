// lib/ad_helper_stub.dart
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web; // Necesario para HtmlElementView y platformViewRegistry
import 'dart:html' as html;   // Necesario para crear elementos HTML

class AdHelper {
  Future<void> initialize() async {
    print("AdHelper: initialize() llamado en la web (stub).");
  }

  // MÉTODO PARA EL BANNER WEB
  Widget getBannerAdWidget({required String adSenseAdSlotId}) {
    // Genera un ID de vista ÚNICO para esta instancia específica del widget de anuncio.
    // Incluir el timestamp asegura la unicidad si se llama múltiples veces incluso para el mismo slotId.
    final String viewType = 'adsense-banner-$adSenseAdSlotId-${DateTime.now().millisecondsSinceEpoch}';

    // Registra la fábrica de vistas para este viewType único.
    // No necesitamos verificar si ya está registrado porque el viewType es nuevo cada vez.
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
          (int viewId) {
        // Contenedor principal para el anuncio
        final adDiv = html.DivElement()
          ..id = 'ad-div-banner-$viewId-$adSenseAdSlotId' // ID único para el div
          ..style.width = '100%'
          ..style.height = 'auto'; // AdSense ajustará la altura

        // Elemento <ins> de AdSense
        final insElement = html.Element.tag('ins')
          ..className = 'adsbygoogle'
          ..style.display = 'block'
          ..style.width = '100%'
        // ¡¡RECUERDA CAMBIAR ESTE ID DE EDITOR POR EL TUYO REAL!!
          ..setAttribute('data-ad-client', 'ca-pub-XXXXXXXXXXXXXXX') // TU ID DE EDITOR DE ADSENSE
          ..setAttribute('data-ad-slot', adSenseAdSlotId) // El slot ID específico
          ..setAttribute('data-ad-format', 'auto') // Formato auto adaptable
          ..setAttribute('data-full-width-responsive', 'true');

        // Script para "pushear" el anuncio
        final scriptPush = html.ScriptElement()
          ..text = '(adsbygoogle = window.adsbygoogle || []).push({});';

        adDiv.append(insElement);
        adDiv.append(scriptPush);
        return adDiv;
      },
    );

    // Devuelve el widget que mostrará el anuncio
    return SizedBox(
      height: 90, // Altura deseada para el contenedor. AdSense puede ajustarla.
      width: double.infinity,
      child: HtmlElementView(
        viewType: viewType, // Usa el viewType único
      ),
    );
  }

  void disposeBannerAd() {
    // Para la web, el navegador generalmente maneja la limpieza de los elementos HTML
    // cuando el HtmlElementView se elimina del árbol de widgets.
    // Si hubieras registrado listeners globales o algo que necesite limpieza manual, lo harías aquí.
    print("AdHelper: disposeBannerAd() llamado en la web (stub).");
  }
}

