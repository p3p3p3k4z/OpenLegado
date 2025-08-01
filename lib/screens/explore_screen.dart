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
  static const LatLng _initialTarget = LatLng(19.4326, -99.1332); // CDMX
  static const double _initialZoom = 10;
  final Set<Marker> _markers = {};
  List<Experience> _experiences = [];
  Experience? _featuredExperience;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchExperiences(),
      _getFeaturedExperience(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  /// Obtiene un stream de experiencias aprobadas desde Firestore.
  Future<void> _fetchExperiences() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('experiences')
          .where('status', isEqualTo: 'approved')
          .get();

      final experiences = querySnapshot.docs
          .map((doc) => Experience.fromFirestore(doc))
          .toList();

      setState(() {
        _experiences = experiences;
        _markers.clear();
        for (var experience in experiences) {
          _markers.add(
            Marker(
              markerId: MarkerId(experience.id),
              position: LatLng(experience.latitude, experience.longitude),
              infoWindow: InfoWindow(
                title: experience.title,
                snippet: experience.location,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExperienceDetailScreen(experience: experience),
                  ),
                );
              },
            ),
          );
        }
      });
    } catch (e) {
      print('Error al cargar experiencias: $e');
    }
  }

  /// Obtiene una experiencia destacada de Firestore.
  Future<void> _getFeaturedExperience() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('experiences')
          .where('isFeatured', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _featuredExperience = Experience.fromFirestore(querySnapshot.docs.first);
        });
      }
    } catch (e) {
      print('Error al cargar la experiencia destacada: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            _buildFeaturedExperience(),
            _buildExperiencesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF8B4513),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
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
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Explora\nexperiencias\nlocales',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: _goToCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.my_location, color: Color(0xFF8B4513)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedExperience() {
    if (_featuredExperience == null) {
      return const SizedBox.shrink();
    }
    final experience = _featuredExperience!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Experiencia Destacada',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExperienceDetailScreen(experience: experience),
                ),
              );
            },
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      experience.imageAsset,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.network(
                        'https://placehold.co/600x400/E67E22/ffffff?text=Imagen+No+Disponible',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            experience.location,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$${experience.price.toStringAsFixed(2)} MXN',
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperiencesList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Todas las experiencias',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _experiences.length,
            itemBuilder: (context, index) {
              final experience = _experiences[index];
              return _buildExperienceCard(experience);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceCard(Experience experience) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExperienceDetailScreen(experience: experience),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: Image.network(
                experience.imageAsset,
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.network(
                  'https://placehold.co/120x120/E67E22/ffffff?text=Imagen',
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          experience.location,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${experience.price.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE67E22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Los servicios de ubicación están deshabilitados.', Colors.red);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permiso de ubicación denegado.', Colors.red);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Los permisos de ubicación están denegados permanentemente.', Colors.red);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 15,
    )));
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController.future.then((controller) => controller.dispose());
    super.dispose();
  }
}
