import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ExperienceDetailScreen extends StatefulWidget {
  final Experience experience;

  const ExperienceDetailScreen({Key? key, required this.experience})
      : super(key: key);

  @override
  _ExperienceDetailScreenState createState() =>
      _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  bool _isBooking = false;

  final Completer<GoogleMapController> _mapController = Completer();
  late CameraPosition _cameraPosition;
  late Marker _experienceMarker;

  // Controladores para la reserva
  DateTime? _selectedDate;
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
      infoWindow: InfoWindow(title: widget.experience.title),
    );
  }

  /// Obtener ubicación actual y centrar el mapa
  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Activa el GPS para ver tu ubicación.', Colors.orange);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permiso de ubicación denegado.', Colors.red);
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude), 15));
  }

  /// Verifica si la experiencia está en favoritos
  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingFavorite = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final savedExperiences =
            List<String>.from(data?['savedExperiences'] ?? []);
        setState(() {
          _isFavorite = savedExperiences.contains(widget.experience.id);
        });
      }
    } catch (e) {
      print('Error checking favorite: $e');
    } finally {
      setState(() => _isLoadingFavorite = false);
    }
  }

  /// Alternar favoritos
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(
          'Debes iniciar sesión para guardar experiencias.', Colors.orange);
      return;
    }

    setState(() => _isLoadingFavorite = true);
    try {
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (_isFavorite) {
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayRemove([widget.experience.id])
        });
        _showSnackBar('Eliminado de favoritos.', Colors.grey);
      } else {
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayUnion([widget.experience.id])
        });
        _showSnackBar('Añadido a favoritos.', Colors.green);
      }
      setState(() => _isFavorite = !_isFavorite);
    } catch (e) {
      _showSnackBar('Error al actualizar favoritos: $e', Colors.red);
    } finally {
      setState(() => _isLoadingFavorite = false);
    }
  }

  /// Mostrar snackbar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  /// Formulario de reserva
  void _showBookingForm() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para reservar.', Colors.orange);
      return;
    }

    _selectedDate = null;
    _peopleController.text = '1';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Reservar ${widget.experience.title}',
              style: const TextStyle(
                color: Color(0xFF8B4513),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    _selectedDate == null
                        ? 'Seleccionar fecha'
                        : 'Fecha: ${MaterialLocalizations.of(context).formatShortDate(_selectedDate!)}',
                  ),
                  trailing:
                      const Icon(Icons.calendar_today, color: Color(0xFFE67E22)),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (picked != null) {
                      setModalState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _peopleController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Número de personas',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: _isBooking
                    ? null
                    : () => _createBooking(context), // Crear reserva
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67E22)),
                child: _isBooking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirmar Reserva'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Crear reserva en Firestore
  Future<void> _createBooking(BuildContext dialogContext) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedDate == null) {
      _showSnackBar('Selecciona una fecha.', Colors.red);
      return;
    }

    final numberOfPeople = int.tryParse(_peopleController.text.trim());
    if (numberOfPeople == null || numberOfPeople <= 0) {
      _showSnackBar('Número de personas no válido.', Colors.red);
      return;
    }

    setState(() => _isBooking = true);
    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user.uid,
        'experienceId': widget.experience.id,
        'experienceTitle': widget.experience.title,
        'experienceImage': widget.experience.imageAsset,
        'bookingDate': Timestamp.fromDate(_selectedDate!),
        'numberOfPeople': numberOfPeople,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(dialogContext);
      _showSnackBar('Reserva creada con éxito.', Colors.green);
    } catch (e) {
      _showSnackBar('Error al crear reserva: $e', Colors.red);
    } finally {
      setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF8B4513),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              _isLoadingFavorite
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: _toggleFavorite,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.asset(
                widget.experience.imageAsset,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  _buildHighlights(),
                  const SizedBox(height: 24),
                  _buildLocation(),
                  const SizedBox(height: 24),
                  _buildPriceAndDuration(),
                  const SizedBox(height: 32),
                  _buildBookingButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.experience.title,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: Color(0xFF8D6E63)),
            const SizedBox(width: 4),
            Text(widget.experience.location,
                style:
                    const TextStyle(fontSize: 16, color: Color(0xFF8D6E63))),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Descripción',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513))),
          const SizedBox(height: 12),
          Text(widget.experience.description,
              style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      );

  Widget _buildHighlights() {
    if (widget.experience.highlights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lo que incluye',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B4513))),
        const SizedBox(height: 12),
        ...widget.experience.highlights.map((h) => Text('- $h')),
      ],
    );
  }

  Widget _buildLocation() {
    final lat = widget.experience.latitude.toStringAsFixed(4);
    final lng = widget.experience.longitude.toStringAsFixed(4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ubicación',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B4513))),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: GoogleMap(
              initialCameraPosition: _cameraPosition,
              markers: {_experienceMarker},
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
              myLocationEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _goToCurrentLocation,
          icon: const Icon(Icons.my_location, color: Color(0xFFE67E22)),
          label: const Text('Ir a mi ubicación',
              style: TextStyle(color: Color(0xFFE67E22))),
        ),
        Text('Lat: $lat, Lng: $lng',
            style: const TextStyle(color: Color(0xFF8D6E63))),
      ],
    );
  }

  Widget _buildPriceAndDuration() => Row(
        children: [
          Expanded(
              child: Column(children: [
            const Icon(Icons.access_time, color: Color(0xFFE67E22)),
            Text('Duración: ${widget.experience.duration}'),
          ])),
          Expanded(
              child: Column(children: [
            const Icon(Icons.attach_money, color: Color(0xFF4CAF50)),
            Text('Precio: \$${widget.experience.price} MXN'),
          ])),
        ],
      );

  Widget _buildBookingButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _showBookingForm,
          style:
              ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67E22)),
          child: const Text('Reservar Experiencia'),
        ),
      );

  @override
  void dispose() {
    _peopleController.dispose();
    super.dispose();
  }
}
