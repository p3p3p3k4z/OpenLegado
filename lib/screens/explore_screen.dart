import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
// --------- IMPORTACIONES PARA ANUNCIOS ---------
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart'; // Para verificar si los anuncios están habilitados

// Paleta
const Color kBackgroundColor = Color(0xFFFFF0E0);
const Color kAccentColor = Color(0xFF4E1E0A);
const Color kTextColor = Color(0xFF311F14);

// Fuente
const String kFontFamily = 'Montserrat';
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _initialTarget = LatLng(
      19.4326, -99.1332); // Ejemplo: CDMX
  static const double _initialZoom = 10;

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('marker_1'),
      position: LatLng(19.4326, -99.1332), // CDMX
      infoWindow: InfoWindow(title: 'Experiencia Ejemplo en CDMX'),
    ),
  };

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // IDs de prueba de AdMob para desarrollo:
  // Android: ca-app-pub-3940256099942544/6300978111
  // iOS: ca-app-pub-3940256099942544/2934735716

  final String _bannerAdUnitId = kIsWeb
      ? 'ca-pub-8671328151922776'
      : (defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/6300978111' // ID de prueba Android
      : 'ca-app-pub-3940256099942544/2934735716'); // ID de prueba iOS

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    if (kIsWeb || !AppConfig.areAdsActiveForCurrentPlatform) {
      print(
          "ExploreScreen: Anuncios AdMob no se cargarán (Plataforma Web o deshabilitados en AppConfig).");
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          print('ExploreScreen: BannerAd cargado exitosamente.');
          if (mounted) { // Verificar si el widget sigue montado
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('ExploreScreen: BannerAd falló al cargar: $error');
          ad.dispose();
        },
        onAdOpened: (Ad ad) => print('ExploreScreen: BannerAd abierto.'),
        onAdClosed: (Ad ad) => print('ExploreScreen: BannerAd cerrado.'),
        onAdImpression: (Ad ad) =>
            print('ExploreScreen: BannerAd impresión registrada.'),
      ),
    )
      ..load();
  }

  Future<Experience?> _getFeaturedExperience() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('experiences')
          .where('isFeatured', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Experience.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('ExploreScreen: Error al obtener experiencia destacada: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Explorar',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.w700,
            fontFamily: kFontFamily,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: SingleChildScrollView( // <--- MODIFICACIÓN: Envuelve la Column principal
        child: Column(
          children: [
            // Mapa integrado
            Container(
              height: 300,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _initialTarget,
                        zoom: _initialZoom,
                      ),
                      markers: _markers,
                      onMapCreated: (GoogleMapController controller) {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(controller);
                        }
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapControl(Icons.layers_outlined, () {
                            print('Control de capas del mapa presionado.');
                          }),
                          const SizedBox(height: 8),
                          _buildMapControl(Icons.filter_list_alt, () {
                            print('Control de filtros del mapa presionado.');
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Experiencias destacadas
            Padding( // <--- MODIFICACIÓN: Padding para la sección
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0, top: 8.0),
                    child: Text(
                      'Experiencias Destacadas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                  ),
                  FutureBuilder<Experience?>(
                    future: _getFeaturedExperience(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(
                            color: Color(0xFFE67E22)));
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error al cargar: ${snapshot.error}',
                                style: const TextStyle(
                                    color: Colors.redAccent)));
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Center(
                            child: Text(
                                'No hay experiencias destacadas por ahora.',
                                style: TextStyle(color: Colors.grey)));
                      }
                      final featuredExperience = snapshot.data!;
                      return _buildFeaturedExperienceCard(
                          context, featuredExperience);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // <--- MODIFICACIÓN: Espacio antes del banner

            // --------- CONTENEDOR DEL ANUNCIO BANNER ---------
            if (AppConfig.areAdsActiveForCurrentPlatform)
              if (kIsWeb)
                Container(
                  height: 50,
                  width: double.infinity,
                  color: Colors.blueGrey[50],
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: Text(
                    'Espacio reservado para anuncio web (AdSense)',
                    style: TextStyle(color: Colors.blueGrey[700], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                if (_isBannerAdLoaded && _bannerAd != null)
                  Container(
                    height: _bannerAd!.size.height.toDouble(),
                    width: _bannerAd!.size.width.toDouble(),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    alignment: Alignment.center,
                    child: AdWidget(ad: _bannerAd!),
                  )
                else
                  Container(
                    height: 50,
                    width: double.infinity,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Cargando publicidad...',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 16),
            // <--- MODIFICACIÓN: Espacio después del banner
          ],
        ),
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8.0),
      shadowColor: Colors.black.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: const Color(0xFFE67E22)),
        ),
      ),
    );
  }

  Widget _buildFeaturedExperienceCard(BuildContext context,
      Experience experience) {
    // Widget para la imagen, se determinará si es de red o asset
    Widget imageWidget;

    // Depuración: imprime el valor de imageAsset
    print("ExploreScreen Card - imageAsset: ${experience.imageAsset}");

    // Lógica para determinar si es una URL o un asset local
    if (experience.imageAsset.startsWith('http://') ||
        experience.imageAsset.startsWith('https://')) {
      // Es una URL, usa Image.network()
      imageWidget = Image.network(
        experience.imageAsset, // La URL de la imagen
        width: 120,
        // Mantenemos el tamaño original del SizedBox
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            return child; // Imagen cargada
          }
          return Center( // Muestra un indicador de progreso mientras carga
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
              color: const Color(0xFFE67E22), // Puedes usar un color temático
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // En caso de error al cargar desde la red, muestra un placeholder
          print("ExploreScreen Card - Error cargando imagen de RED: ${experience
              .imageAsset}, Error: $error");
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600], size: 40),
          );
        },
      );
    } else {
      // No es una URL, asume que es un asset local, usa Image.asset()
      // Determina la ruta del asset, usando un placeholder si imageAsset está vacío
      final String assetPath = experience.imageAsset.isNotEmpty ? experience
          .imageAsset : 'assets/placeholder_image.png';
      imageWidget = Image.asset(
        assetPath,
        width: 120, // Mantenemos el tamaño original del SizedBox
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // En caso de error al cargar el asset, muestra un placeholder
          print(
              "ExploreScreen Card - Error cargando imagen ASSET: $assetPath, Error: $error");
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600], size: 40),
          );
        },
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: SizedBox( // Contenedor con altura fija para la tarjeta de experiencia
          height: 120, // Altura de la tarjeta
          child: Row(
            children: [
              // Aquí usamos el imageWidget que hemos definido (sea Image.network o Image.asset)
              // Ya no necesitamos el SizedBox explícito aquí porque imageWidget ya tiene width/height
              imageWidget,
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  // Padding interno para los detalles
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    // Distribuye el espacio verticalmente
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title,
                            maxLines: 2,
                            // Limita a 2 líneas para el título
                            overflow: TextOverflow.ellipsis,
                            // Añade "..." si el texto es muy largo
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037), // Marrón oscuro
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            experience.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63), // Marrón medio
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          // Alinea al final
                          children: [
                            Flexible(
                              child: Text(
                                '\$${experience.price.toStringAsFixed(2)} MXN',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE67E22), // Naranja
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ExperienceDetailScreen(
                                            experience: experience),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE67E22),
                                // Naranja
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                textStyle: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                                minimumSize: const Size(70, 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                elevation: 2,
                              ),
                              child: const Text('Ver más'),
                            ),
                          ],
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