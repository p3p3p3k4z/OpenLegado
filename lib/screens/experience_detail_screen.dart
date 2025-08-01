import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/experience.dart';
import '../models/booking.dart';
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

  // Nuevo estado para la reserva de tickets
  DateTime? _selectedDate;
  int _selectedTickets = 1;

  final Completer<GoogleMapController> _mapController = Completer();
  late CameraPosition _cameraPosition;
  late Marker _experienceMarker;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();

    // Inicializar el mapa con la ubicación de la experiencia
    final latLng = LatLng(widget.experience.latitude, widget.experience.longitude);

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

  void _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data.containsKey('savedExperiences') && data['savedExperiences'].contains(widget.experience.id)) {
        setState(() {
          _isFavorite = true;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para guardar favoritos.', Colors.red);
      return;
    }

    setState(() {
      _isLoadingFavorite = true;
    });

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (_isFavorite) {
        // Eliminar de favoritos
        await userRef.update({
          'savedExperiences': FieldValue.arrayRemove([widget.experience.id]),
        });
        _showSnackBar('Eliminado de favoritos.', Colors.grey);
      } else {
        // Añadir a favoritos
        await userRef.update({
          'savedExperiences': FieldValue.arrayUnion([widget.experience.id]),
        });
        _showSnackBar('Añadido a favoritos.', Colors.green);
      }
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

  /// Muestra un formulario para reservar la experiencia.
  void _showBookingForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final availableTickets = _selectedDate != null
                ? widget.experience.schedule
                .firstWhere(
                  (s) => s.date.isAtSameMomentAs(_selectedDate!),
              orElse: () => TicketSchedule(date: _selectedDate!, capacity: 0),
            )
                .capacity
                : 0;

            final isFullyBooked = availableTickets <= 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reservar Experiencia',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  // NUEVO: Selector de fecha
                  _buildDateSelector(setState),
                  const SizedBox(height: 24),
                  // Controles de boletos y botón de reserva
                  Row(
                    children: [
                      // Boletos
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: _selectedTickets > 1
                                  ? () => setState(() => _selectedTickets--)
                                  : null,
                            ),
                            Text(
                              '$_selectedTickets',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: _selectedTickets < availableTickets
                                  ? () => setState(() => _selectedTickets++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Botón de reserva
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isFullyBooked || _selectedDate == null || _selectedTickets > availableTickets
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
                            isFullyBooked
                                ? 'Sin boletos disponibles'
                                : 'Reservar ($_selectedTickets)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Widget para seleccionar la fecha de la reserva.
  Widget _buildDateSelector(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona una fecha:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.experience.schedule.length,
            itemBuilder: (context, index) {
              final scheduleItem = widget.experience.schedule[index];
              final isSelected = _selectedDate?.isAtSameMomentAs(scheduleItem.date) ?? false;
              final isFull = scheduleItem.capacity <= 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    DateFormat('E, d MMM').format(scheduleItem.date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isFull
                      ? null
                      : (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDate = scheduleItem.date;
                      } else {
                        _selectedDate = null;
                      }
                      _selectedTickets = 1; // Reiniciar los tickets al cambiar de fecha.
                    });
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: const Color(0xFFE67E22),
                  disabledColor: Colors.red[100],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Realiza la reserva de boletos usando una transacción de Firestore.
  Future<void> _bookExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para reservar.', Colors.red);
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Por favor, selecciona una fecha.', Colors.red);
      return;
    }

    // Referencia al documento de la experiencia
    final experienceRef = FirebaseFirestore.instance.collection('experiences').doc(widget.experience.id);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Obtener la experiencia más reciente dentro de la transacción.
        final freshExperienceDoc = await transaction.get(experienceRef);
        final freshExperience = Experience.fromFirestore(freshExperienceDoc);

        // 2. Encontrar el cupo para la fecha seleccionada.
        final scheduleIndex = freshExperience.schedule.indexWhere(
              (s) => s.date.isAtSameMomentAs(_selectedDate!),
        );

        if (scheduleIndex == -1) {
          throw Exception('La fecha seleccionada no está disponible.');
        }

        final currentCapacity = freshExperience.schedule[scheduleIndex].capacity;

        if (currentCapacity < _selectedTickets) {
          throw Exception('No hay suficientes boletos disponibles para esta fecha.');
        }

        // 3. Crear el nuevo objeto de schedule con el cupo actualizado.
        final newSchedule = List<TicketSchedule>.from(freshExperience.schedule);
        newSchedule[scheduleIndex] = TicketSchedule(
          date: _selectedDate!,
          capacity: currentCapacity - _selectedTickets,
        );

        // 4. Actualizar el documento de la experiencia con el nuevo schedule.
        transaction.update(experienceRef, {
          'schedule': newSchedule.map((s) => s.toMap()).toList(),
        });

        // 5. Crear el documento de la reserva.
        final bookingData = {
          'userId': user.uid,
          'experienceId': widget.experience.id,
          'experienceTitle': widget.experience.title,
          'experienceImage': widget.experience.imageAsset,
          'bookingDate': Timestamp.fromDate(_selectedDate!),
          'numberOfPeople': _selectedTickets,
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
        };
        transaction.set(FirebaseFirestore.instance.collection('bookings').doc(), bookingData);
      });

      _showSnackBar('Reserva exitosa para $_selectedTickets persona(s).', Colors.green);
      // Actualizar la UI para reflejar el cambio en el cupo.
      setState(() {
        final scheduleIndex = widget.experience.schedule.indexWhere(
              (s) => s.date.isAtSameMomentAs(_selectedDate!),
        );
        if (scheduleIndex != -1) {
          widget.experience.schedule[scheduleIndex] = TicketSchedule(
            date: _selectedDate!,
            capacity: widget.experience.schedule[scheduleIndex].capacity - _selectedTickets,
          );
        }
      });
      Navigator.pop(context); // Cierra el modal después de la reserva.
    } catch (e) {
      _showSnackBar('Error al reservar: $e', Colors.red);
      print('Error al reservar: $e'); // Para depuración
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Experiencia', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF8B4513),
        actions: [
          _isLoadingFavorite
              ? const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: Colors.white),
          )
              : IconButton(
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  widget.experience.imageAsset,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.network(
                    'https://placehold.co/600x400/E67E22/ffffff?text=Imagen+No+Disponible',
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B4513).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.experience.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.experience.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.experience.rating} (${widget.experience.reviews} reseñas)',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Por: ${widget.experience.artisanName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF8D6E63),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Acerca de la experiencia'),
                  Text(widget.experience.description),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Puntos destacados'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.experience.highlights
                        .map((highlight) => Chip(
                      label: Text(highlight),
                      backgroundColor: const Color(0xFFE67E22).withOpacity(0.1),
                      labelStyle: const TextStyle(color: Color(0xFFE67E22)),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Ubicación'),
                  _buildMap(widget.experience.latitude, widget.experience.longitude),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Detalles'),
                  _buildPriceAndDuration(),
                  const SizedBox(height: 24),
                  _buildBookingButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5D4037),
        ),
      ),
    );
  }

  Widget _buildMap(double lat, double lng) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200,
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
      onPressed: widget.experience.schedule.isNotEmpty ? _showBookingForm : null,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67E22)),
      child: Text(
        widget.experience.schedule.isNotEmpty
            ? 'Reservar Experiencia'
            : 'Sin Fechas Disponibles',
      ),
    ),
  );

  @override
  void dispose() {
    // Es buena práctica liberar el controlador del mapa.
    _mapController.future.then((controller) => controller.dispose());
    super.dispose();
  }
}
