import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart'; // Para formatear fechas y horas
import 'package:intl/date_symbol_data_local.dart'; // Para inicializar formatos locales

// Importa los modelos de datos modularizados
import '../models/experience.dart';
import '../models/user.dart'; // Modelo AppUser para obtener nombre de usuario
import '../models/booking.dart';
import '../models/review.dart'; // Modelo Review para la sección de comentarios

import 'widgets/experience_creator_card.dart';

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
  TicketSchedule? _selectedSchedule; // Horario seleccionado

  // Mapa
  final Completer<GoogleMapController> _mapController = Completer();
  late CameraPosition _cameraPosition;
  late Marker _experienceMarker;
  bool _isMapLoading = true;

  // Estados para las reseñas
  List<Review> _reviews = [];
  bool _isLoadingReviews = true;
  final TextEditingController _commentController = TextEditingController();
  double _currentRating = 0.0;
  AppUser? _currentUserData;
  bool _isSubmittingReview = false;

  // Para refrescar los datos de la experiencia
  late Experience _currentExperience;

  // estados del creador
  AppUser? _experienceCreator;
  bool _isLoadingCreator = true; // Empezar como true para mostrar loading

  @override
  void initState() {
    super.initState();
    // Asegúrate de inicializar los datos de formato para tu locale si aún no lo has hecho globalmente
    // Es buena práctica hacerlo en el main.dart, pero si no, aquí también funciona.
    initializeDateFormatting('es_MX', null).then((_) {
      // Una vez inicializado, puedes reconstruir el widget si es necesario
      // o simplemente confiar en que estará listo cuando se use DateFormat.
      if (mounted) {
        setState(() {
          // Esto es solo para forzar una reconstrucción si los formatos dependen de la inicialización
          // y el widget se construyó antes de que la inicialización completara.
          // En la mayoría de los casos, si la inicialización es rápida, no se notará.
        });
      }
    });

    _currentExperience = widget.experience;
    _initializeDefaultSchedule();
    _checkIfFavorite();
    _initMap();
    _fetchUserData();
    _fetchReviews();
    _fetchExperienceCreator();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  /// Inicializa el schedule por defecto si hay alguno disponible.
  void _initializeDefaultSchedule() {
    if (_currentExperience.schedule.isNotEmpty) {
      TicketSchedule? firstAvailableSchedule;
      try {
        firstAvailableSchedule = _currentExperience.schedule.firstWhere(
              (s) => s.capacity - s.bookedTickets > 0,
        );
      } catch (e) {
        // No se encontró ningún schedule con capacidad disponible
        firstAvailableSchedule = null;
      }

      if (firstAvailableSchedule != null) {
        _selectedSchedule = firstAvailableSchedule;
      } else {
        // Si no hay ninguno disponible, pero la lista de schedules no está vacía,
        // puedes optar por seleccionar el primero (y la UI lo mostrará como agotado)
        // o dejar _selectedSchedule como null.
        // Aquí seleccionamos el primero si existe, para que el dropdown muestre algo.
        _selectedSchedule = _currentExperience.schedule.first; // O null si prefieres
      }
      _selectedTickets = 1; // Resetea a 1 boleto
    } else {
      _selectedSchedule = null;
      // Si no hay schedules, la lógica de maxCapacity y bookedTickets de la experiencia principal se usa.
      _selectedTickets = 1;
    }
  }

  /// Inicializa la posición del mapa y el marcador.
  void _initMap() {
    if (_currentExperience.latitude == 0.0 && _currentExperience.longitude == 0.0) {
      if (mounted) setState(() => _isMapLoading = false);
      print("Advertencia: Coordenadas de la experiencia no válidas para el mapa.");
      return;
    }
    final latLng = LatLng(_currentExperience.latitude, _currentExperience.longitude);
    _cameraPosition = CameraPosition(target: latLng, zoom: 15);
    _experienceMarker = Marker(
      markerId: MarkerId(_currentExperience.id),
      position: latLng,
      infoWindow: InfoWindow(title: _currentExperience.title, snippet: _currentExperience.location),
    );
    if (mounted) setState(() => _isMapLoading = false);
  }

  /// Refresca los datos de la experiencia desde Firestore.
  Future<void> _refreshExperienceData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('experiences')
          .doc(widget.experience.id)
          .get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _currentExperience = Experience.fromFirestore(docSnapshot);
          // Re-evaluar el schedule seleccionado si la experiencia se actualiza
          if (_currentExperience.schedule.isNotEmpty) {
            if (_selectedSchedule != null) {
              // Intenta encontrar el mismo schedule (por fecha) en la lista actualizada
              TicketSchedule? updatedSelectedSchedule;
              try {
                updatedSelectedSchedule = _currentExperience.schedule.firstWhere(
                      (s) => s.date.isAtSameMomentAs(_selectedSchedule!.date) && s.capacity == _selectedSchedule!.capacity,
                );
              } catch (e) {
                updatedSelectedSchedule = null; // No se encontró el schedule anterior
              }


              if (updatedSelectedSchedule != null) {
                _selectedSchedule = updatedSelectedSchedule;
                final maxTicketsForSelected = updatedSelectedSchedule.capacity - updatedSelectedSchedule.bookedTickets;
                if (_selectedTickets > maxTicketsForSelected && maxTicketsForSelected > 0) {
                  _selectedTickets = maxTicketsForSelected;
                } else if (maxTicketsForSelected <= 0) {
                  // Si el schedule actual se llenó, intenta encontrar otro o inicializar
                  _selectedTickets = 1; // resetea
                  _initializeDefaultSchedule(); // Busca un nuevo schedule disponible
                }
              } else {
                // El schedule previamente seleccionado ya no existe o cambió significativamente
                _initializeDefaultSchedule(); // Re-inicializa al primer schedule disponible
              }
            } else {
              _initializeDefaultSchedule(); // Si no había ninguno seleccionado, inicializa
            }
          } else {
            // Lógica para experiencias sin schedule (legacy o configuración diferente)
            _selectedSchedule = null;
            final availableLegacy = _currentExperience.maxCapacity - _currentExperience.bookedTickets;
            if (_currentExperience.maxCapacity > 0 && _selectedTickets > availableLegacy && availableLegacy > 0) {
              _selectedTickets = availableLegacy;
            } else if (availableLegacy <= 0 && _currentExperience.maxCapacity > 0) {
              _selectedTickets = 1; // O manejar como agotado si no hay schedules y maxCapacity>0
            }
          }
        });
      }
    } catch (e) {
      print("Error al refrescar datos de la experiencia: $e");
      if(mounted) _showSnackBar("No se pudieron actualizar los datos.", Colors.orange);
    }
  }


  /// Obtiene los datos del usuario actual.
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _currentUserData = null); // Limpiar si no hay usuario
      return;
    }
    // Cancelar suscripción anterior si existe
    await _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots() // Usar snapshots para actualizaciones en tiempo real si es necesario
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() => _currentUserData = AppUser.fromFirestore(userDoc));
      } else if (mounted) {
        setState(() => _currentUserData = null); // Usuario no encontrado en Firestore
        print('Documento del usuario actual no encontrado: ${user.uid}');
      }
    }, onError: (error) {
      print('Error al obtener datos del usuario (stream): $error');
      if (mounted) setState(() => _currentUserData = null);
    });
  }

  // --- AÑADIDO: Función para obtener los datos del creador de la experiencia ---
  Future<void> _fetchExperienceCreator() async {

    final String creatorIdToFetch = widget.experience.creatorId;

    if (creatorIdToFetch.isEmpty) {
      print("ID del creador no encontrado en la experiencia (campo creatorId vacío).");
      if (mounted) {
        setState(() {
          _experienceCreator = null;
          _isLoadingCreator = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingCreator = true);

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorIdToFetch) // Usa la variable local
          .get();

      if (docSnapshot.exists && mounted) {
        setState(() {
          _experienceCreator = AppUser.fromFirestore(docSnapshot);
          _isLoadingCreator = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _experienceCreator = null;
            _isLoadingCreator = false;
          });
        }
        print('Documento del creador no encontrado para ID: $creatorIdToFetch');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _experienceCreator = null;
          _isLoadingCreator = false;
        });
      }
      print('Error al obtener datos del creador: $e');
      _showSnackBar('No se pudieron cargar los datos del anfitrión.', Colors.orange);
    }
  }

  /// Obtiene las reseñas.
  Future<void> _fetchReviews() async {
    if (!mounted) return;
    setState(() => _isLoadingReviews = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('experienceId', isEqualTo: _currentExperience.id)
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        final reviews = querySnapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
        setState(() => _reviews = reviews);
      }
    } catch (e) {
      print('Error al cargar reseñas: $e');
      if (mounted) _showSnackBar('Error al cargar reseñas.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  /// Verifica si la experiencia está en favoritos.
  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!mounted) return;
    setState(() => _isLoadingFavorite = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        final userData = AppUser.fromFirestore(userDoc);
        setState(() => _isFavorite = userData.savedExperiences.contains(_currentExperience.id));
      }
    } catch (e) {
      print('Error al verificar favoritos: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  /// Alterna el estado de favorito.
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para guardar.', Colors.amber);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingFavorite = true);
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      if (_isFavorite) {
        await userDocRef.update({'savedExperiences': FieldValue.arrayRemove([_currentExperience.id])});
        if (mounted) _showSnackBar('Eliminada de favoritos.', Colors.orange);
      } else {
        await userDocRef.update({'savedExperiences': FieldValue.arrayUnion([_currentExperience.id])});
        if (mounted) _showSnackBar('Guardada en favoritos.', Colors.green);
      }
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    } catch (e) {
      if (mounted) _showSnackBar('Error al actualizar favoritos.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  /// Realiza la reserva de boletos (adaptado para schedules).
  Future<void> _bookExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para reservar.', Colors.amber);
      return;
    }

    // Si hay schedules, se debe seleccionar uno
    if (_currentExperience.schedule.isNotEmpty && _selectedSchedule == null) {
      _showSnackBar('Por favor, selecciona un horario.', Colors.red);
      return;
    }

    if (_selectedTickets <= 0) {
      _showSnackBar('Debe seleccionar al menos un boleto.', Colors.red);
      return;
    }

    final experienceRef = FirebaseFirestore.instance.collection('experiences').doc(_currentExperience.id);
    final bookingsRef = FirebaseFirestore.instance.collection('bookings');

    if (mounted) _showSnackBar('Procesando reserva...', Colors.blue);

    try {
      String? bookingId;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final experienceSnapshot = await transaction.get(experienceRef);
        if (!experienceSnapshot.exists) throw 'La experiencia ya no está disponible.';

        final Experience currentExperienceData = Experience.fromFirestore(experienceSnapshot);
        TicketSchedule? targetScheduleData; // El schedule específico que se está reservando

        if (currentExperienceData.schedule.isNotEmpty) {
          // Si hay horarios, validar contra el schedule seleccionado
          if (_selectedSchedule == null) throw 'Error interno: No se seleccionó un horario.';

          targetScheduleData = currentExperienceData.schedule.firstWhere(
                (s) => s.date.isAtSameMomentAs(_selectedSchedule!.date) && s.capacity == _selectedSchedule!.capacity, // Asegurar que es el mismo
            orElse: () => throw 'El horario seleccionado ya no está disponible o ha cambiado.',
          );

          final availableTicketsInSchedule = targetScheduleData.capacity - targetScheduleData.bookedTickets;
          if (_selectedTickets > availableTicketsInSchedule) {
            throw 'No hay suficientes boletos para este horario. Disponibles: $availableTicketsInSchedule.';
          }

          // Actualizar bookedTickets en la copia local del schedule dentro de la lista
          final updatedScheduleList = List<Map<String, dynamic>>.from(currentExperienceData.schedule.map((s) => s.toMap()));
          final scheduleIndex = updatedScheduleList.indexWhere((sMap) => (sMap['date'] as Timestamp).toDate().isAtSameMomentAs(targetScheduleData!.date));

          if (scheduleIndex != -1) {
            updatedScheduleList[scheduleIndex]['bookedTickets'] = targetScheduleData.bookedTickets + _selectedTickets;
            transaction.update(experienceRef, {'schedule': updatedScheduleList});
          } else {
            throw 'Error al actualizar el horario en la base de datos.';
          }
        } else {
          // Lógica legacy si no hay schedules (usa maxCapacity de la experiencia)
          if (currentExperienceData.maxCapacity > 0) {
            final availableTickets = currentExperienceData.maxCapacity - currentExperienceData.bookedTickets;
            if (_selectedTickets > availableTickets) {
              throw 'No hay suficientes boletos disponibles. Quedan $availableTickets.';
            }
            final newBookedTickets = currentExperienceData.bookedTickets + _selectedTickets;
            transaction.update(experienceRef, {'bookedTickets': newBookedTickets});
          }
        }

        final newBookingRef = bookingsRef.doc();
        bookingId = newBookingRef.id;
        final newBooking = Booking(
          id: bookingId!,
          userId: user.uid,
          experienceId: _currentExperience.id,
          experienceTitle: _currentExperience.title,
          experienceImage: _currentExperience.imageAsset,
          numberOfPeople: _selectedTickets,
          bookingDate: DateTime.now(), // Fecha de creación de la reserva
          status: 'confirmed',
          createdAt: DateTime.now(),
          // Campos nuevos para el booking
          scheduleDate: _selectedSchedule?.date, // Fecha del schedule reservado
          ticketPrice: _currentExperience.price.toDouble(), // Precio por boleto
          totalAmount: _currentExperience.price.toDouble() * _selectedTickets, // Monto total
        );
        transaction.set(newBookingRef, newBooking.toMap());
      });

      if (mounted) {
        _showSnackBar('Reserva exitosa para $_selectedTickets boleto(s).', Colors.green);
        setState(() {
          _selectedTickets = 1; // Resetear
          // No necesitamos re-inicializar el schedule aquí, _refreshExperienceData lo hará
        });
        await _refreshExperienceData(); // Actualizará _currentExperience con los nuevos bookedTickets
      }
    } catch (error) {
      if (mounted) _showSnackBar('Error en la reserva: ${error.toString()}', Colors.red);
    }
  }


  /// Envía una nueva reseña.
  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUserData == null) {
      _showSnackBar('Debe iniciar sesión para dejar una reseña.', Colors.amber);
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      _showSnackBar('Por favor, escribe un comentario.', Colors.red);
      return;
    }
    if (_currentRating == 0.0) {
      _showSnackBar('Por favor, selecciona una calificación.', Colors.red);
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmittingReview = true);

    try {
      final newReviewRef = FirebaseFirestore.instance.collection('reviews').doc();
      final newReview = Review(
        id: newReviewRef.id,
        userId: user.uid,
        userName: _currentUserData?.username ?? _currentUserData?.email?.split('@')[0] ?? 'Anónimo',
        experienceId: _currentExperience.id,
        rating: _currentRating,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );
      await newReviewRef.set(newReview.toMap());

      final experienceRef = FirebaseFirestore.instance.collection('experiences').doc(_currentExperience.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(experienceRef);
        if (!freshSnapshot.exists) throw 'La experiencia no fue encontrada.';
        final freshExperience = Experience.fromFirestore(freshSnapshot);
        final currentTotalRatingPoints = freshExperience.rating * freshExperience.reviewsCount;
        final newTotalRatingPoints = currentTotalRatingPoints + _currentRating;
        final newTotalReviews = freshExperience.reviewsCount + 1;
        final newAverageRating = newTotalReviews > 0 ? newTotalRatingPoints / newTotalReviews : 0.0;
        transaction.update(experienceRef, {
          'reviewsCount': newTotalReviews,
          'rating': double.parse(newAverageRating.toStringAsFixed(1)),
        });
      });

      if (mounted) {
        _showSnackBar('Reseña enviada.', Colors.green);
        _commentController.clear();
        setState(() => _currentRating = 0.0);
        await _refreshExperienceData();
        _fetchReviews();
      }
    } catch (e) {
      print('Error al enviar reseña: $e');
      if (mounted) _showSnackBar('Error al enviar la reseña.', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determinar disponibilidad basada en si hay schedules o no
    int availableTickets = 0;
    bool isFullyBooked = true;
    String ticketsInfoText = 'No requiere reserva'; // Default

    if (_currentExperience.schedule.isNotEmpty) {
      if (_selectedSchedule != null) {
        availableTickets = _selectedSchedule!.capacity - _selectedSchedule!.bookedTickets;
        isFullyBooked = availableTickets <= 0;
        ticketsInfoText = isFullyBooked ? 'Agotados (este horario)' : 'Disponibles: $availableTickets';
      } else {
        // Si hay schedules pero ninguno está seleccionado (o no hay disponibles)
        ticketsInfoText = 'Selecciona un horario';
        isFullyBooked = true; // Considerar no reservable hasta que se seleccione horario
        availableTickets = 0;
      }
    } else {
      // Lógica legacy sin schedules
      if (_currentExperience.maxCapacity > 0) {
        availableTickets = _currentExperience.maxCapacity - _currentExperience.bookedTickets;
        isFullyBooked = availableTickets <= 0;
        ticketsInfoText = isFullyBooked ? 'Agotados' : 'Disponibles: $availableTickets';
      }
    }


    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshExperienceData();
          await _fetchReviews();
          await _checkIfFavorite();
          await _fetchExperienceCreator();
        },
        child: CustomScrollView(
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

                    // --- AÑADIDO: Sección de información del creador ---
                    // Se inserta antes de la descripción. Ajusta la posición si prefieres.
                    ExperienceCreatorInfoCard(
                      creator: _experienceCreator,
                      isLoading: _isLoadingCreator,
                    ),
                    // Añadir un SizedBox si el creador es visible y quieres espacio antes de la descripción
                    if (_experienceCreator != null || _isLoadingCreator)
                      const SizedBox(height: 24),

                    const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    const SizedBox(height: 8),
                    Text(_currentExperience.description, style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800])),
                    const SizedBox(height: 24),
                    _buildPriceAndDuration(),
                    const SizedBox(height: 24),
                    const Text('Ubicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    const SizedBox(height: 12),
                    Text(_currentExperience.location, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    _buildMapSection(),
                    const SizedBox(height: 24),
                    // SECCIÓN DE RESERVA MEJORADA
                    const Text('Reserva tu Experiencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    const SizedBox(height: 16),
                    if (_currentExperience.schedule.isNotEmpty) ...[
                      _buildScheduleSelector(),
                      const SizedBox(height: 16),
                    ],
                    _buildBookingControls(availableTickets, isFullyBooked, ticketsInfoText),
                    const SizedBox(height: 32),
                    _buildReviewsSectionHeader(),
                    const SizedBox(height: 16),
                    _buildReviewsList(),
                    _buildAddReviewSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets de la UI (SliverAppBar, Title, Highlights, Price, InfoCard, Map sin cambios significativos) ---
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: const Color(0xFF8B4513),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
        title: Text(
          _currentExperience.title,
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        background: Hero(
          tag: 'experience_image_${_currentExperience.id}',
          child: _currentExperience.imageAsset.startsWith('http')
              ? Image.network(
            _currentExperience.imageAsset,
            fit: BoxFit.cover,
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
          )
              : Image.asset(
            _currentExperience.imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
          ),
        ),
      ),
      actions: [
        if (_isLoadingFavorite)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: SizedBox(width:24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
          )
        else
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white,
              size: 28,
            ),
            tooltip: _isFavorite ? 'Eliminar de favoritos' : 'Guardar en favoritos',
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
            _currentExperience.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
          ),
        ),
        const SizedBox(width: 16),
        if (_currentExperience.rating > 0 && _currentExperience.reviewsCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFE67E22),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0,2)) ]
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 5),
                Text(
                  _currentExperience.rating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHighlights() {
    if (_currentExperience.highlights.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _currentExperience.highlights.map((highlight) {
        return Chip(
          avatar: Icon(Icons.check_circle_outline_rounded, color: Color(0xFF5D4037), size: 18),
          label: Text(highlight),
          backgroundColor: const Color(0xFFF5EFE6),
          labelStyle: const TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.brown.withOpacity(0.15))
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        );
      }).toList(),
    );
  }

  Widget _buildPriceAndDuration() {
    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.access_time_filled_rounded,
          label: 'Duración',
          value: _currentExperience.duration,
          iconColor: const Color(0xFFE67E22),
        ),
        const SizedBox(width: 16),
        _buildInfoCard(
          icon: Icons.local_offer_rounded,
          label: 'Precio',
          // El precio ahora es por boleto, y podría variar por schedule si se implementa
          value: _currentExperience.price > 0 ? '\$${_currentExperience.price.toStringAsFixed(0)} MXN' : 'Gratis',
          iconColor: Colors.green[700]!,
        ),
      ],
    );
  }

  Widget _buildInfoCard({ required IconData icon, required String label, required String value, required Color iconColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3)) ],
            border: Border.all(color: Colors.grey.shade200, width: 0.5)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    if (_currentExperience.latitude == 0.0 && _currentExperience.longitude == 0.0) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300)
        ),
        child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 40, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text("Ubicación no disponible.", style: TextStyle(color: Colors.grey[700])),
              ],
            )
        ),
      );
    }
    return _isMapLoading
        ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
        : Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)) ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: _cameraPosition,
          markers: {_experienceMarker},
          onMapCreated: (GoogleMapController controller) {
            if (!_mapController.isCompleted && mounted) { _mapController.complete(controller); }
          },
          myLocationButtonEnabled: true,
          myLocationEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: true,
          compassEnabled: true,
        ),
      ),
    );
  }

  // --- NUEVO WIDGET: Selector de Horarios ---
  Widget _buildScheduleSelector() {
    if (_currentExperience.schedule.isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay horarios
    }

    // Ordenar los schedules por fecha y hora para que aparezcan cronológicamente en el dropdown
    // Es una buena práctica hacerlo aquí, aunque ya deberían venir ordenados de Firestore si así los guardas.
    final List<TicketSchedule> sortedSchedules = List.from(_currentExperience.schedule);
    sortedSchedules.sort((a, b) => a.date.compareTo(b.date));


    // No es necesario filtrar aquí los 'availableSchedules' para el Dropdown,
    // ya que el DropdownMenuItem maneja el estado 'enabled' y visual.
    // Mostrar todos permite al usuario ver incluso los agotados.

    if (sortedSchedules.isEmpty && _selectedSchedule == null) { // Aunque el if de arriba ya lo cubre.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          "No hay horarios disponibles en este momento.",
          style: TextStyle(color: Colors.orange.shade700, fontStyle: FontStyle.italic),
        ),
      );
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona un Horario:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5D4037))),
        const SizedBox(height: 8),
        DropdownButtonFormField<TicketSchedule>(
          value: _selectedSchedule, // El schedule actualmente seleccionado
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
          ),
          hint: const Text('Elige fecha y hora'),
          // Usar los schedules ordenados
          items: sortedSchedules
              .map<DropdownMenuItem<TicketSchedule>>((TicketSchedule scheduleItem) {
            final int ticketsLeft = scheduleItem.capacity - scheduleItem.bookedTickets;
            final bool isAvailable = ticketsLeft > 0;

            // ***** CAMBIO PRINCIPAL AQUÍ *****
            // Formatear la fecha para incluir la hora. Usa tu locale 'es_MX'.
            final String formattedDateTime =
            DateFormat('EEEE, d MMM, hh:mm a', 'es_MX').format(scheduleItem.date);
            // Alternativa 24h: DateFormat('EEEE, d MMM, HH:mm', 'es_MX')

            return DropdownMenuItem<TicketSchedule>(
              value: scheduleItem,
              enabled: isAvailable, // Deshabilitar si no hay boletos
              child: Text(
                '$formattedDateTime (${isAvailable ? "$ticketsLeft disp." : "Agotado"})',
                style: TextStyle(
                  color: isAvailable ? Colors.black87 : Colors.grey,
                  // Tachar si no está disponible, pero no si es el actualmente seleccionado
                  // (para que el usuario vea su selección incluso si se agota mientras mira)
                  decoration: (!isAvailable && scheduleItem != _selectedSchedule)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            );
          }).toList(),
          onChanged: (TicketSchedule? newValue) {
            // Solo permitir cambiar si el nuevo valor es diferente y está disponible
            // (aunque el 'enabled' del DropdownMenuItem ya debería prevenir la selección de deshabilitados)
            if (newValue != null && (newValue.capacity - newValue.bookedTickets > 0)) {
              setState(() {
                _selectedSchedule = newValue;
                _selectedTickets = 1; // Resetear al cambiar de horario
              });
            } else if (newValue != null && !(newValue.capacity - newValue.bookedTickets > 0)) {
              // Si intentan seleccionar uno agotado (aunque no debería ser posible por 'enabled')
              _showSnackBar("Este horario está agotado.", Colors.orange);
            }
          },
          // Validar que se haya seleccionado un horario si hay schedules
          validator: (value) {
            if (_currentExperience.schedule.isNotEmpty && value == null) {
              return 'Por favor, selecciona un horario.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBookingControls(int availableTicketsForSelection, bool isSelectionFullyBooked, String ticketsInfoText) {
    bool canAttemptBook = FirebaseAuth.instance.currentUser != null;
    bool canFinalizeBook = false;

    if (_currentExperience.schedule.isNotEmpty) {
      // Si hay schedules, la reserva depende de haber seleccionado uno disponible
      canFinalizeBook = canAttemptBook &&
          _selectedSchedule != null &&
          !isSelectionFullyBooked && // isSelectionFullyBooked se refiere al _selectedSchedule
           _selectedTickets > 0 &&
          _selectedTickets <= availableTicketsForSelection;
    } else {
      // Lógica legacy: si no hay schedules, depende de maxCapacity general
      canFinalizeBook = canAttemptBook &&
          (_currentExperience.maxCapacity == 0 || // Si es gratis o no requiere capacidad
              (!isSelectionFullyBooked && // isSelectionFullyBooked se refiere a la capacidad general
                  _selectedTickets > 0 &&
                  _selectedTickets <= availableTicketsForSelection));
    }


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.brown[50]?.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)) ],
          border: Border.all(color: Colors.brown.shade100)
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Boletos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    const SizedBox(height: 4),
                    Text(
                      ticketsInfoText, // Usa el texto dinámico
                      style: TextStyle(
                          color: isSelectionFullyBooked && (_selectedSchedule != null || _currentExperience.maxCapacity > 0)
                              ? Colors.red.shade700
                              : Colors.green.shade800,
                          fontWeight: FontWeight.w600
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mostrar controles de cantidad solo si hay un schedule seleccionado y disponible, o si no hay schedules y hay capacidad
                    if ((_selectedSchedule != null && !isSelectionFullyBooked) || (_currentExperience.schedule.isEmpty && _currentExperience.maxCapacity > 0 && !isSelectionFullyBooked))
                      Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE67E22)),
                              iconSize: 30, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              onPressed: _selectedTickets > 1 ? () => setState(() => _selectedTickets--) : null,
                            ),
                          ),
                          // Segundo Expanded para el número de boletos, esto lo centrará
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                _selectedTickets.toString(),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF424242)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Tercer Expanded para el botón de sumar
                          Expanded(
                            child: IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFE67E22)),
                              iconSize: 30, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              onPressed: _selectedTickets < availableTicketsForSelection ? () => setState(() => _selectedTickets++) : null,
                            ),
                          ),
                        ],
                      )
                    else if (_currentExperience.schedule.isEmpty && _currentExperience.maxCapacity == 0)
                      Text('No se necesita seleccionar boletos.', style: TextStyle(color: Colors.grey[700]))
                    else if (_selectedSchedule == null && _currentExperience.schedule.isNotEmpty)
                        Text('Selecciona un horario para ver disponibilidad.', style: TextStyle(color: Colors.blueGrey[700]))
                    // else if (isSelectionFullyBooked)
                    //   SizedBox.shrink(), // No mostrar nada si está agotado y ya se indicó arriba
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  icon: Icon(FirebaseAuth.instance.currentUser == null ? Icons.login_rounded : Icons.confirmation_number_rounded, size: 20),
                  label: Text(
                    FirebaseAuth.instance.currentUser == null ? 'Inicia Sesión' :
                    (_currentExperience.schedule.isEmpty && _currentExperience.maxCapacity == 0) ? 'Asistir' : // Experiencia sin horarios y sin capacidad (gratis/abierta)
                    (_selectedSchedule == null && _currentExperience.schedule.isNotEmpty) ? 'Selecciona Horario' :
                    isSelectionFullyBooked ? 'Agotado' : 'Reservar ($_selectedTickets)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: FirebaseAuth.instance.currentUser == null
                      ? () { _showSnackBar('Por favor, inicia sesión para reservar.', Colors.amber); /* TODO: Navegar a Login */ }
                      : (canFinalizeBook ? _bookExperience : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67E22), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    disabledBackgroundColor: Colors.grey[300], disabledForegroundColor: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          if (FirebaseAuth.instance.currentUser == null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                'Debes iniciar sesión para poder reservar esta experiencia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // --- Widgets de Reseñas (Header, List, Item, AddReview) sin cambios significativos ---
  Widget _buildReviewsSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comentarios y Reseñas',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
        ),
        if (_currentExperience.reviewsCount > 0) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _currentExperience.rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE67E22)),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.star_rounded, color: Color(0xFFE67E22), size: 26),
              const SizedBox(width: 10),
              Text(
                '(${_currentExperience.reviewsCount} reseña${_currentExperience.reviewsCount == 1 ? "" : "s"})',
                style: TextStyle(color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ] else ... [
          const SizedBox(height: 8),
          Text(
            _isLoadingReviews ? 'Cargando reseñas...' : 'Aún no hay reseñas. ¡Sé el primero!',
            style: TextStyle(color: Colors.grey[600], fontSize: 15, fontStyle: FontStyle.italic),
          ),
        ]
      ],
    );
  }

  Widget _buildReviewsList() {
    if (_isLoadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_reviews.isEmpty && !_isLoadingReviews) {
      return const SizedBox.shrink(); // Ya manejado por el header
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        return _buildReviewItem(_reviews[index]);
      },
    );
  }

  Widget _buildReviewItem(Review review) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037)),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy, hh:mm a', 'es').format(review.createdAt), // Formato de fecha mejorado
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    )
                ),
                Row(
                  children: List.generate(5, (starIndex) {
                    return Icon(
                      starIndex < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: TextStyle(fontSize: 14.5, height: 1.4, color: Colors.grey[850]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReviewSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
        child: Center(
          child: Column(
            children: [
              Text(
                'Inicia sesión para dejar tu reseña.',
                style: TextStyle(color: Colors.grey[700], fontSize: 15),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('Ir a Iniciar Sesión'),
                onPressed: () {
                  // TODO: Implementar navegación a la pantalla de login.
                  // Navigator.of(context).push(MaterialPageRoute(builder: (context) => LoginScreen()));
                  _showSnackBar('Funcionalidad de "Ir a Iniciar Sesión" no implementada.', Colors.blueGrey);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              )
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deja tu reseña',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    _currentRating >= index + 1 ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _currentRating = (index + 1).toDouble();
                      });
                    }
                  },
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe tu comentario aquí...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFE67E22), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _isSubmittingReview
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar Reseña'),
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67E22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
