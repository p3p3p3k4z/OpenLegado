import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/experience.dart';
import '../models/user.dart';

/// Pantalla que muestra los detalles completos de una experiencia.
class ExperienceDetailScreen extends StatefulWidget {
  final Experience experience;

  const ExperienceDetailScreen({Key? key, required this.experience})
      : super(key: key);

  @override
  _ExperienceDetailScreenState createState() =>
      _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  late CameraPosition _cameraPosition;
  late Marker _experienceMarker;

  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  bool _isBooking = false;
  int _selectedTickets = 1;

  final TextEditingController _peopleController =
  TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();

    // Inicializar el mapa con la ubicación de la experiencia
    final latLng =
    LatLng(widget.experience.latitude, widget.experience.longitude);

    _cameraPosition = CameraPosition(
      target: latLng,
      zoom: 15,
    );

    _experienceMarker = Marker(
      markerId: MarkerId(widget.experience.id),
      position: latLng,
      infoWindow: InfoWindow(
        title: widget.experience.title,
        snippet: widget.experience.artisanName,
      ),
    );
  }

  @override
  void dispose() {
    _peopleController.dispose();
    super.dispose();
  }

  /// Comprueba si la experiencia está en la lista de favoritos del usuario.
  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoadingFavorite = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final savedExperiences = (userDoc.data()?['savedExperiences'] as List<dynamic>?)?.cast<String>() ?? [];
      setState(() {
        _isFavorite = savedExperiences.contains(widget.experience.id);
      });
    } catch (e) {
      _showSnackBar('Error al verificar favoritos.', Colors.red);
    } finally {
      setState(() => _isLoadingFavorite = false);
    }
  }

  /// Añade o quita la experiencia de la lista de favoritos del usuario.
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para guardar favoritos.', Colors.red);
      return;
    }
    setState(() => _isLoadingFavorite = true);
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      if (_isFavorite) {
        // Quitar de favoritos
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayRemove([widget.experience.id]),
        });
        _showSnackBar('Experiencia eliminada de favoritos.', Colors.green);
      } else {
        // Añadir a favoritos
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayUnion([widget.experience.id]),
        });
        _showSnackBar('Experiencia guardada en favoritos.', Colors.green);
      }
      setState(() => _isFavorite = !_isFavorite);
    } catch (e) {
      _showSnackBar('Error al actualizar favoritos: $e', Colors.red);
    } finally {
      setState(() => _isLoadingFavorite = false);
    }
  }

  /// Muestra un SnackBar con un mensaje.
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Realiza la reserva de boletos usando una transacción de Firestore.
  /// Las transacciones son fundamentales para evitar condiciones de carrera
  /// cuando varios usuarios intentan reservar al mismo tiempo.
  Future<void> _bookExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para reservar.', Colors.red);
      return;
    }

    if (_selectedTickets <= 0) {
      _showSnackBar('Seleccione al menos un boleto.', Colors.red);
      return;
    }

    // Referencia al documento de la experiencia.
    final experienceRef = FirebaseFirestore.instance.collection('experiences').doc(widget.experience.id);

    setState(() => _isBooking = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Obtener el documento más reciente de la experiencia dentro de la transacción.
        final experienceSnapshot = await transaction.get(experienceRef);
        final currentExperience = Experience.fromFirestore(experienceSnapshot);

        final availableTickets = currentExperience.maxCapacity - currentExperience.bookedTickets;

        if (_selectedTickets > availableTickets) {
          throw 'No hay suficientes boletos disponibles. Quedan solo $availableTickets boletos.';
        }

        // 1. Actualizar el contador de boletos reservados en la experiencia.
        transaction.update(experienceRef, {
          'bookedTickets': FieldValue.increment(_selectedTickets),
        });

        // 2. Crear un nuevo documento de reserva.
        final newBookingRef = FirebaseFirestore.instance.collection('bookings').doc();
        transaction.set(newBookingRef, {
          'userId': user.uid,
          'experienceId': currentExperience.id,
          'experienceTitle': currentExperience.title,
          'experienceImage': currentExperience.imageAsset,
          'numberOfPeople': _selectedTickets,
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _showSnackBar('¡Reserva realizada con éxito para $_selectedTickets personas!', Colors.green);
      Navigator.of(context).pop(); // Cierra el modal de reserva.

    } catch (e) {
      _showSnackBar('Error al reservar: $e', Colors.red);
    } finally {
      setState(() => _isBooking = false);
    }
  }

  /// Muestra el formulario de reserva en un modal.
  void _showBookingForm(BuildContext context, int availableTickets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reservar Boletos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                Text('Boletos disponibles: $availableTickets'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Cantidad: ', style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _selectedTickets > 1 ? () => setState(() => _selectedTickets--) : null,
                    ),
                    Text('$_selectedTickets', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _selectedTickets < availableTickets ? () => setState(() => _selectedTickets++) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isBooking || _selectedTickets > availableTickets ? null : _bookExperience,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67E22),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isBooking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    _selectedTickets > availableTickets
                        ? 'Cupo no disponible'
                        : 'Reservar para $_selectedTickets',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Navega a la ubicación actual del usuario en el mapa.
  Future<void> _goToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 15,
      )));
    } catch (e) {
      _showSnackBar('No se pudo obtener la ubicación actual.', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('experiences').doc(widget.experience.id).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Experiencia no encontrada.'));
          }

          final updatedExperience = Experience.fromFirestore(snapshot.data!);
          final availableTickets = updatedExperience.maxCapacity - updatedExperience.bookedTickets;
          final isFullyBooked = availableTickets <= 0;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, updatedExperience),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildHeaderSection(updatedExperience),
                      const SizedBox(height: 16),
                      _buildMapSection(updatedExperience.latitude, updatedExperience.longitude),
                      const SizedBox(height: 16),
                      Text(
                        'Lo más destacado',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildHighlightsList(updatedExperience.highlights),
                      const SizedBox(height: 24),
                      Text(
                        'Descripción',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        updatedExperience.description,
                        style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF5D4037)),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: isFullyBooked ? null : () => _showBookingForm(context, availableTickets),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE67E22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          isFullyBooked ? 'Sin boletos disponibles' : 'Reservar experiencia',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Experience experience) {
    return SliverAppBar(
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          experience.imageAsset,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          },
          errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.white)),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _isLoadingFavorite ? null : _toggleFavorite,
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(Experience experience) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          experience.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              '${experience.rating.toStringAsFixed(1)} (${experience.reviews} reseñas)',
              style: const TextStyle(fontSize: 16, color: Color(0xFF8D6E63)),
            ),
            const Spacer(),
            Text(
              '\$${experience.price.toStringAsFixed(2)} MXN',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE67E22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildInfoChip(
              icon: Icons.access_time,
              label: experience.duration,
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              icon: Icons.people,
              label: 'Capacidad: ${experience.maxCapacity}',
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              icon: Icons.bookmark,
              label: 'Boletos reservados: ${experience.bookedTickets}',
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHighlightsList(List<String> highlights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: highlights.map((highlight) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Row(
          children: [
            const Icon(Icons.check, color: Color(0xFFE67E22), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                highlight,
                style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037)),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildMapSection(double lat, double lng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Container(
            height: 250,
            color: Colors.grey[200],
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _cameraPosition,
              markers: {_experienceMarker},
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
              myLocationEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _goToCurrentLocation,
            icon: const Icon(Icons.my_location, color: Color(0xFFE67E22)),
            label: const Text('Ir a mi ubicación',
                style: TextStyle(color: Color(0xFFE67E22), fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: const TextStyle(color: Color(0xFF5D4037))),
      backgroundColor: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

