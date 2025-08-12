import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart'; // Ajusta la ruta si es necesario
import 'experience_detail_screen.dart'; // Ajusta la ruta si es necesario
import 'package:google_maps_flutter/google_maps_flutter.dart';
// La importación de geolocator no se usa en este archivo base, la mantenemos comentada.
// import 'package:geolocator/geolocator.dart';

// --- NUEVO: Importaciones para anuncios ---
import 'package:flutter/foundation.dart' show kIsWeb;
// Asegúrate de que la ruta a ad_helper.dart sea correcta desde la carpeta 'screens'
// Si ad_helper.dart está en lib/, entonces '../ad_helper.dart' es correcto.
import '../ad_helper.dart';
// --- FIN NUEVO ---


class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _initialTarget = LatLng(19.4326, -99.1332); // Ejemplo: CDMX
  static const double _initialZoom = 10;

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('marker_1'),
      position: LatLng(19.4326, -99.1332),
      infoWindow: InfoWindow(title: 'Experiencia Ejemplo'),
    ),
  };

  // --- NUEVO: Integración de Anuncios ---
  final AdHelper _adHelper = AdHelper();
  Widget? _bannerAdWidget;

  // ¡¡RECUERDA USAR TUS PROPIOS IDs DE PRODUCCIÓN AL LANZAR!!
  // Y TU ID DE EDITOR DE ADSENSE EN ad_helper_stub.dart ('ca-pub-XXXXXXXXXXXXXXX')
  final String _adSenseAdSlotIdForExploreScreen = "9713335269"; // CAMBIA ESTE SLOT ID DE ADSENSE SI ES NECESARIO
  final String _adMobAdUnitIdForExploreScreen = "ca-app-pub-3940256099942544/6300978111"; // ID DE PRUEBA DE ADMOB BANNER

  @override
  void initState() {
    super.initState();
    // Inicializa AdHelper (puede ser asíncrono si es necesario para alguna plataforma)
    _adHelper.initialize().then((_) {
      // Carga el banner después de que AdHelper esté inicializado
      _loadBannerAd();
    });
  }

  // En ExploreScreen.dart _ExploreScreenState

  void _loadBannerAd() {
    /* // Temporalmente comenta la parte web
      if (kIsWeb) {
        print("ExploreScreen (Web): Cargando AdSense Banner.");
        _bannerAdWidget = _adHelper.getBannerAdWidget(adSenseAdSlotId: _adSenseAdSlotIdForExploreScreen);
        if (mounted) {
          setState(() {});
        }
      } else*/ { // Móvil
      print("ExploreScreen (Móvil): Intentando cargar AdMob Banner.");
      try {
        _bannerAdWidget = _adHelper.getBannerAdWidget(
          adMobAdUnitId: _adMobAdUnitIdForExploreScreen, // El nombre DEBE COINCIDIR
          onAdLoaded: () {                              // El nombre DEBE COINCIDIR
            print("ExploreScreen (Móvil): Callback de onAdLoaded recibido.");
            if (mounted) {
              setState(() {});
            }
          },
        );
        print("ExploreScreen (Móvil): Llamada a getBannerAdWidget (móvil) completada sin error de firma.");
      } catch (e) {
        print("ExploreScreen (Móvil): ERROR al llamar getBannerAdWidget (móvil): $e");
        // Si el error es sobre la firma, se imprimirá aquí.
      }
      if (mounted) {
        setState(() {});
      }
    }
  }
  @override
  void dispose() {
    _adHelper.disposeBannerAd(); // Limpia el anuncio
    super.dispose();
  }
  // --- FIN NUEVO ---


  Future<Experience?> _getFeaturedExperience() async {
    // ... (sin cambios)
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
      print('Error al obtener experiencia destacada: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ... (sin cambios)
        title: const Text(
          'Explorar',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFE67E22)),
            onPressed: () {
              // TODO: Implementar filtros.
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Mapa integrado
          Container(
            // ... (sin cambios)
            height: 300,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
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
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        _buildMapControl(Icons.list, () {}),
                        const SizedBox(height: 8),
                        _buildMapControl(Icons.sort, () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- NUEVO: Widget del Anuncio Banner ---
          if (_bannerAdWidget != null)
            Container(
              alignment: Alignment.center,
              // La altura es gestionada por el SizedBox en ad_helper_stub (para web)
              // o por AdSize en ad_helper_mobile.
              margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              child: _bannerAdWidget,
            )
          else
          // Placeholder opcional mientras carga o si no hay anuncio.
          // Para AdMob, el SizedBox.shrink() en ad_helper_mobile maneja el estado inicial.
          // Para AdSense, el HtmlElementView se renderiza directamente.
          // Este SizedBox es más un fallback visual si _bannerAdWidget es nulo por alguna razón.
            const SizedBox(height: 50), // Puedes ajustar o quitar este placeholder
          // --- FIN NUEVO ---


          // Experiencias destacadas
          Expanded(
            child: Container(
              // ... (sin cambios)
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Experiencias Destacadas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Experience?>(
                    future: _getFeaturedExperience(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Center(child: Text('No se encontró experiencia destacada.'));
                      }

                      final featuredExperience = snapshot.data!;
                      return _buildFeaturedExperienceCard(context, featuredExperience);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    // ... (sin cambios)
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFFE67E22)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildFeaturedExperienceCard(BuildContext context, Experience experience) {
    // ... (sin cambios)
    // Asegúrate de que tu modelo Experience tenga los campos imageAsset, title, location, price.
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Image.asset( // Asumiendo que experience.imageAsset es una ruta de asset local
                  experience.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: Colors.grey[300], alignment: Alignment.center, child: Icon(Icons.broken_image, color: Colors.grey[600]));
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            experience.location,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${experience.price} MXN',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE67E22)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExperienceDetailScreen(experience: experience),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Ver más', style: TextStyle(fontSize: 12)),
                          ),
                        ],
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
