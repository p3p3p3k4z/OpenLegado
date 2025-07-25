import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  /// Obtiene una experiencia destacada de Firestore.
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
      print('Error al obtener experiencia destacada: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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

          // Experiencias destacadas
          Expanded(
            child: Container(
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
              // Imagen de la experiencia
              SizedBox(
                width: 120,
                height: 120,
                child: Image.asset(
                  experience.imageAsset,
                  fit: BoxFit.cover,
                ),
              ),
              // Detalles
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            experience.location,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${experience.price} MXN',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE67E22),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ExperienceDetailScreen(experience: experience),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Ver más',
                              style: TextStyle(fontSize: 12),
                            ),
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
