// lib/screens/explore_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/experience.dart'; // <<< TU MODELO EXPERIENCE
import '../models/themed_collection.dart'; // <<< TU MODELO THEMEDCOLLECTION
import 'experience_detail_screen.dart'; // <<< TU PANTALLA DE DETALLE DE EXPERIENCIA
import 'themed_collection_screen.dart'; // <<< PANTALLA PARA LA COLECCIÓN SELECCIONADA

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart'; // Para habilitar/deshabilitar anuncios

// Paleta de colores
const Color kAppBackgroundColor = Color(0xFFFFF0E0);
const Color kAppAccentColor = Color(0xFF4E1E0A);
const Color kAppTextColor = Color(0xFF311F14);
const String kAppFontFamily = 'Montserrat';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // --- Google Maps ---
  final Completer<GoogleMapController> _mapController = Completer();
  static const LatLng _initialTarget = LatLng(19.4326, -99.1332);
  static const double _initialZoom = 10;
  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('default_marker'),
      position: _initialTarget,
      infoWindow: InfoWindow(title: 'Punto de Interés'),
    ),
  };

  // --- Futuros para los datos ---
  late Future<List<ThemedCollection>> _featuredCollectionsFuture;
  late Future<List<Experience>> _featuredExperiencesFuture; // <<< PARA EXPERIENCIAS DESTACADAS

  // --- AdMob ---
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _bannerAdUnitId = kIsWeb
      ? 'ca-pub-3940256099942544/6300978111'
      : (defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716');

  @override
  void initState() {
    super.initState();
    _featuredCollectionsFuture = _fetchFeaturedThemedCollections();
    _featuredExperiencesFuture = _fetchFeaturedExperiences(); // <<< INICIALIZAR FUTURO
    if (AppConfig.adsEnabled) {
      _loadBannerAd();
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _featuredCollectionsFuture = _fetchFeaturedThemedCollections();
      _featuredExperiencesFuture = _fetchFeaturedExperiences(); // <<< RECARGAR AMBOS
    });
  }

  Future<List<ThemedCollection>> _fetchFeaturedThemedCollections() async {
    print("EXPLORE_SCREEN: Cargando colecciones temáticas...");
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('experience_collections')
          .where('isFeaturedOnExplore', isEqualTo: true)
          .orderBy('order', descending: false)
          .limit(10)
          .get();
      print("EXPLORE_SCREEN: Documentos de colecciones obtenidos: ${querySnapshot.docs.length}");
      if (querySnapshot.docs.isEmpty) return [];

      List<ThemedCollection> collections = [];
      for (var doc in querySnapshot.docs) {
        try {
          collections.add(ThemedCollection.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
        } catch (e) {
          print("EXPLORE_SCREEN: Error deserializando colección ID: ${doc.id}. Error: $e");
        }
      }
      return collections;
    } catch (e) {
      print('EXPLORE_SCREEN: ERROR FATAL obteniendo colecciones temáticas: $e');
      return [];
    }
  }

  // --- NUEVO MÉTODO PARA CARGAR EXPERIENCIAS DESTACADAS ---
  Future<List<Experience>> _fetchFeaturedExperiences() async {
    print("EXPLORE_SCREEN: Cargando experiencias destacadas...");
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('experiences')
          .where('isFeatured', isEqualTo: true) // Usando tu campo 'isFeatured'
          .where('status', isEqualTo: 'approved')
      // Puedes añadir un .orderBy() si quieres, ej. por fecha o rating
      // .orderBy('createdAt', descending: true)
          .limit(5) // Limita cuántas experiencias destacadas mostrar
          .get();
      print("EXPLORE_SCREEN: Documentos de experiencias destacadas obtenidos: ${querySnapshot.docs.length}");
      if (querySnapshot.docs.isEmpty) return [];

      List<Experience> experiences = [];
      for (var doc in querySnapshot.docs) {
        try {
          experiences.add(Experience.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
        } catch (e) {
          print("EXPLORE_SCREEN: Error deserializando experiencia destacada ID: ${doc.id}. Error: $e");
        }
      }
      return experiences;
    } catch (e) {
      print('EXPLORE_SCREEN: ERROR FATAL obteniendo experiencias destacadas: $e');
      return [];
    }
  }
  // --- FIN DE NUEVO MÉTODO ---

  void _loadBannerAd() {
    // ... (sin cambios respecto a la versión anterior)
    if (kIsWeb || !AppConfig.adsEnabled || !AppConfig.areAdsActiveForCurrentPlatform) {
      print("EXPLORE_SCREEN: Anuncios AdMob no se cargarán.");
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('EXPLORE_SCREEN: BannerAd falló al cargar: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: kAppAccentColor,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 220.0,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('Explorar', style: TextStyle(color: kAppTextColor, fontWeight: FontWeight.bold, fontFamily: kAppFontFamily, fontSize: 18)),
                centerTitle: true,
                background: _buildIntegratedMap(),
              ),
            ),

            // --- Sección: Colecciones Temáticas Curadas ---
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
                child: Text("Colecciones Curadas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAppAccentColor, fontFamily: kAppFontFamily)),
              ),
            ),
            FutureBuilder<List<ThemedCollection>>(
              future: _featuredCollectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: kAppAccentColor))));
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(child: Container(height: 100, padding: const EdgeInsets.symmetric(horizontal: 16.0), alignment: Alignment.center, child: Text('Error al cargar colecciones.', style: TextStyle(color: Colors.red[600], fontFamily: kAppFontFamily))));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox(height: 100, child: Center(child: Text('No hay colecciones curadas por ahora.', style: TextStyle(color: Colors.grey, fontFamily: kAppFontFamily)))));
                }
                final collections = snapshot.data!;
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        return _buildThemedCollectionShortcutCard(collections[index]);
                      },
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Sección: Experiencias Destacadas ---
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0), // Ajustado padding superior
                child: Text(
                  'Experiencias Destacadas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAppAccentColor, fontFamily: kAppFontFamily),
                ),
              ),
            ),
            FutureBuilder<List<Experience>>( // <<< CAMBIADO A LIST<EXPERIENCE>
              future: _featuredExperiencesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Mostrar un shimmer o varias tarjetas de placeholder si lo prefieres
                  return const SliverToBoxAdapter(child: SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: kAppAccentColor))));
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar destacadas: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)))));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverToBoxAdapter(child: Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                    child: Text('No hay experiencias destacadas en este momento.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontFamily: kAppFontFamily)),
                  )));
                }
                // Si llegamos aquí, snapshot.data! es una List<Experience>
                final featuredExperiences = snapshot.data!;
                return SliverList( // <<< USAR SLIVERLIST PARA MÚLTIPLES ITEMS VERTICALES
                  delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                      return Padding( // Padding alrededor de cada tarjeta destacada
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: _buildFeaturedExperienceCard(context, featuredExperiences[index]),
                      );
                    },
                    childCount: featuredExperiences.length,
                  ),
                );
              },
            ),
            // --- FIN DE SECCIÓN EXPERIENCIAS DESTACADAS ---

            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: _buildAdBannerContainer()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegratedMap() {
    // ... (sin cambios)
    return SizedBox(
      height: double.infinity,
      width: double.infinity,
      child: GoogleMap(
        initialCameraPosition: const CameraPosition(target: _initialTarget, zoom: _initialZoom),
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          if (!_mapController.isCompleted) _mapController.complete(controller);
        },
        zoomControlsEnabled: false, myLocationButtonEnabled: false, mapToolbarEnabled: false,
        scrollGesturesEnabled: false, zoomGesturesEnabled: false,
      ),
    );
  }

  Widget _buildThemedCollectionShortcutCard(ThemedCollection collection) {
    // ... (sin cambios, usa collection.coverImageUrl y collection.title)
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ThemedCollectionScreen(collection: collection)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: collection.coverImageUrl.isNotEmpty
                    ? Image.network(
                  collection.coverImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kAppAccentColor)),
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey)),
                )
                    : Container(color: kAppAccentColor.withOpacity(0.08), alignment: Alignment.center, child: Icon(Icons.photo_library_outlined, size: 30, color: kAppAccentColor.withOpacity(0.6))),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  collection.title,
                  style: const TextStyle(color: kAppTextColor, fontWeight: FontWeight.bold, fontSize: 13.5, fontFamily: kAppFontFamily),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para CADA experiencia destacada individual
  Widget _buildFeaturedExperienceCard(BuildContext context, Experience experience) {
    // Usa experience.imageAsset como lo definimos antes
    Widget imageWidget;
    if (experience.imageAsset.isNotEmpty) {
      if (experience.imageAsset.startsWith('http')) {
        imageWidget = Image.network(
          experience.imageAsset, width: 120, height: 120, fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null, color: kAppAccentColor)),
          errorBuilder: (ctx, error, stack) => Container(width: 120, height: 120, color: Colors.grey[300], child: Icon(Icons.broken_image, color: Colors.grey[600], size: 40)),
        );
      } else {
        imageWidget = Image.asset(
          experience.imageAsset, width: 120, height: 120, fit: BoxFit.cover,
          errorBuilder: (ctx, error, stack) => Container(width: 120, height: 120, color: Colors.grey[300], child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[600], size: 40)),
        );
      }
    } else {
      imageWidget = Image.asset(
        'assets/images/placeholder.png', width: 120, height: 120, fit: BoxFit.cover,
        errorBuilder: (ctx, error, stack) => Container(width: 120, height: 120, color: Colors.grey[300], child: Icon(Icons.broken_image, color: Colors.grey[600], size: 40)),
      );
    }

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExperienceDetailScreen(experience: experience))),
        child: SizedBox( // Contenedor con altura fija para la tarjeta
          height: 120,
          child: Row(
            children: [
              SizedBox(width: 120, height: 120, child: imageWidget), // Imagen
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(experience.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: kAppFontFamily)),
                      const SizedBox(height: 4),
                      Text(experience.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: kAppFontFamily)),
                      const SizedBox(height: 6),
                      Text('\$${experience.price.toStringAsFixed(2)} MXN', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kAppAccentColor, fontFamily: kAppFontFamily)),
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

  Widget _buildAdBannerContainer() {
    // ... (sin cambios)
    if (!AppConfig.adsEnabled || !AppConfig.areAdsActiveForCurrentPlatform || _bannerAd == null || !_isBannerAdLoaded) {
      return const SizedBox.shrink();
    }
    if (kIsWeb) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        height: 50,
        color: Colors.blueGrey[50],
        alignment: Alignment.center,
        child: Text('Espacio para AdSense (Web)', style: TextStyle(color: Colors.blueGrey[700], fontFamily: kAppFontFamily)),
      );
    }
    return Container(
      height: _bannerAd!.size.height.toDouble(),
      width: _bannerAd!.size.width.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}