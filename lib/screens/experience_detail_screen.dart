import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// Importa los modelos de datos modularizados que creamos
import '../models/experience.dart';
import '../models/user.dart';
import '../models/booking.dart';

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
  // Estado para gestionar si la experiencia está guardada por el usuario
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  // Estado y lógica para la reserva
  int _selectedTickets = 1;

  // Mapa
  final Completer<GoogleMapController> _mapController = Completer();
  late CameraPosition _cameraPosition;
  late Marker _experienceMarker;
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
    _initMap();
  }

  /// Inicializa la posición del mapa y el marcador con los datos de la experiencia.
  void _initMap() {
    final latLng = LatLng(widget.experience.latitude, widget.experience.longitude);

    _cameraPosition = CameraPosition(
      target: latLng,
      zoom: 15,
    );

    _experienceMarker = Marker(
      markerId: MarkerId(widget.experience.id),
      position: latLng,
      infoWindow: InfoWindow(
        title: widget.experience.title,
        snippet: widget.experience.location,
      ),
    );

    setState(() {
      _isMapLoading = false;
    });
  }

  /// Verifica si la experiencia actual está en la lista de guardados del usuario.
  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingFavorite = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = AppUser.fromFirestore(userDoc);
        setState(() {
          _isFavorite = userData.savedExperiences.contains(widget.experience.id);
        });
      }
    } catch (e) {
      print('Error al verificar favoritos: $e');
    } finally {
      setState(() {
        _isLoadingFavorite = false;
      });
    }
  }

  /// Maneja la adición o eliminación de la experiencia de la lista de favoritos.
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para guardar experiencias.', Colors.red);
      return;
    }

    setState(() {
      _isLoadingFavorite = true;
    });

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      if (_isFavorite) {
        // Elimina la experiencia de la lista
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayRemove([widget.experience.id]),
        });
        _showSnackBar('Experiencia eliminada de favoritos.', Colors.orange);
      } else {
        // Añade la experiencia a la lista
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayUnion([widget.experience.id]),
        });
        _showSnackBar('Experiencia guardada en favoritos.', Colors.green);
      }
      // Actualiza el estado de la UI
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } catch (e) {
      _showSnackBar('Error al actualizar favoritos: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingFavorite = false;
      });
    }
  }

  /// Realiza la reserva de boletos usando una transacción de Firestore.
  Future<void> _bookExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para reservar.', Colors.red);
      return;
    }

    if (_selectedTickets <= 0) {
      _showSnackBar('Debe seleccionar al menos un boleto.', Colors.red);
      return;
    }

    final experienceRef = FirebaseFirestore.instance
        .collection('experiences')
        .doc(widget.experience.id);
    final bookingsRef = FirebaseFirestore.instance
        .collection('bookings');

    // Usamos una transacción para garantizar la atomicidad de la operación
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final experienceSnapshot = await transaction.get(experienceRef);
      final currentBookedTickets =
          (experienceSnapshot.data()?['bookedTickets'] as int?) ?? 0;
      final maxCapacity =
          (experienceSnapshot.data()?['maxCapacity'] as int?) ?? 0;

      final availableTickets = maxCapacity - currentBookedTickets;

      if (_selectedTickets > availableTickets) {
        throw 'No hay suficientes boletos disponibles. Quedan $availableTickets.';
      }

      // Actualiza el número de boletos reservados
      final newBookedTickets = currentBookedTickets + _selectedTickets;
      transaction.update(experienceRef, {'bookedTickets': newBookedTickets});

      // Crea un nuevo documento de reserva
      final newBooking = Booking(
        id: '', // Firestore generará el ID automáticamente
        userId: user.uid,
        experienceId: widget.experience.id,
        experienceTitle: widget.experience.title,
        experienceImage: widget.experience.imageAsset, // Corregido: 'experienceImage'
        numberOfPeople: _selectedTickets, // Corregido: 'numberOfPeople'
        bookingDate: DateTime.now(),
        status: 'pending', // Añadido: el parámetro 'status' requerido
        createdAt: DateTime.now(), // Corregido: usar DateTime en lugar de Timestamp
      );
      // Ahora usamos el método toMap() para guardar los datos en Firestore.
      transaction.set(bookingsRef.doc(), newBooking.toMap());
    }).then((_) {
      _showSnackBar('Reserva exitosa para $_selectedTickets boletos.', Colors.green);
      setState(() {
        // Reinicia la selección de tickets
        _selectedTickets = 1;
      });
    }).catchError((error) {
      _showSnackBar('Error en la reserva: $error', Colors.red);
    });
  }

  /// Muestra una Snackbar para notificaciones al usuario.
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcula la capacidad disponible en tiempo real
    final availableTickets = widget.experience.maxCapacity - widget.experience.bookedTickets;
    final isFullyBooked = availableTickets <= 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleAndRating(),
                  const SizedBox(height: 16),
                  _buildHighlights(),
                  const SizedBox(height: 24),
                  const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.experience.description),
                  const SizedBox(height: 24),
                  _buildPriceAndDuration(),
                  const SizedBox(height: 24),
                  const Text('Ubicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.experience.location),
                  const SizedBox(height: 12),
                  _buildMapSection(),
                  const SizedBox(height: 24),
                  const Text('Reserva tu Experiencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildBookingControls(availableTickets, isFullyBooked),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets de la UI ---

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: const Color(0xFF8B4513),
      flexibleSpace: FlexibleSpaceBar(
        background: Image.asset(
          widget.experience.imageAsset,
          fit: BoxFit.cover,
        ),
      ),
      actions: [
        if (_isLoadingFavorite)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: Colors.white),
          )
        else
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
              size: 30,
            ),
            onPressed: _toggleFavorite,
          ),
      ],
    );
  }

  Widget _buildTitleAndRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.experience.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE67E22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.experience.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: widget.experience.highlights.map((highlight) {
        return Chip(
          label: Text(highlight),
          backgroundColor: Colors.brown[50],
          labelStyle: const TextStyle(color: Color(0xFF5D4037)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceAndDuration() {
    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.access_time,
          label: 'Duración',
          value: widget.experience.duration,
          iconColor: const Color(0xFFE67E22),
        ),
        const SizedBox(width: 16),
        _buildInfoCard(
          icon: Icons.attach_money,
          label: 'Precio',
          value: '\$${widget.experience.price} MXN',
          iconColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return _isMapLoading
        ? const Center(child: CircularProgressIndicator())
        : Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
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
    );
  }

  Widget _buildBookingControls(int availableTickets, bool isFullyBooked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Boletos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  isFullyBooked ? 'Sin boletos disponibles' : 'Disponibles: $availableTickets',
                  style: TextStyle(
                    color: isFullyBooked ? Colors.red : Colors.green[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFE67E22)),
                      onPressed: _selectedTickets > 1 ? () => setState(() => _selectedTickets--) : null,
                    ),
                    Text(
                      _selectedTickets.toString(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE67E22)),
                      onPressed: _selectedTickets < availableTickets
                          ? () => setState(() => _selectedTickets++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isFullyBooked || _selectedTickets > availableTickets
                  ? null
                  : _bookExperience,
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
                isFullyBooked ? 'Agotado' : 'Reservar ($_selectedTickets)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
