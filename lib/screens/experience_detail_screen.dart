import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';     // Para obtener el usuario autenticado
import 'package:cloud_firestore/cloud_firestore.dart'; // Para interactuar con Firestore
import '../models/experience.dart';

/// Pantalla de detalles de una experiencia.
/// Muestra información completa sobre una experiencia cultural específica.
/// Ahora incluye la funcionalidad de marcar/desmarcar como favorita y
/// de realizar una reserva, persistiendo el estado en Firebase Firestore.
class ExperienceDetailScreen extends StatefulWidget {
  final Experience experience;

  const ExperienceDetailScreen({Key? key, required this.experience}) : super(key: key);

  @override
  _ExperienceDetailScreenState createState() => _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen> {
  bool _isFavorite = false; // Estado local para la UI del botón de favorito.
  bool _isLoadingFavorite = false; // Para mostrar un indicador de carga en el botón de favorito.
  bool _isBooking = false; // Nuevo estado para controlar el indicador de carga del botón de reserva.

  // Controladores para el formulario de reserva
  DateTime? _selectedDate;
  final TextEditingController _peopleController = TextEditingController(text: '1'); // Valor inicial de 1 persona

  @override
  void initState() {
    super.initState();
    _checkIfFavorite(); // Verifica el estado inicial del favorito desde Firestore.
  }

  /// Verifica si la experiencia actual ya está marcada como favorita por el usuario.
  ///
  /// Punto de complejidad:
  /// Realiza una lectura de Firestore para determinar el estado inicial del favorito.
  /// Esto es importante para que el icono de corazón refleje el estado correcto
  /// cuando el usuario abre la pantalla de detalles.
  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // No hay usuario, no se puede verificar favoritos.

    setState(() {
      _isLoadingFavorite = true; // Muestra carga al verificar.
    });

    try {
      // Obtiene el documento del usuario desde la colección 'users'.
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        // Verifica si la lista 'savedExperiences' existe y contiene el ID de la experiencia actual.
        final savedExperiences = List<String>.from(data?['savedExperiences'] ?? []);
        setState(() {
          _isFavorite = savedExperiences.contains(widget.experience.id);
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
      // Podrías mostrar un SnackBar de error aquí si lo deseas.
    } finally {
      setState(() {
        _isLoadingFavorite = false; // Oculta carga.
      });
    }
  }

  /// Alterna el estado de favorito de la experiencia y lo guarda en Firestore.
  ///
  /// Punto de complejidad:
  /// Realiza una operación de escritura (actualización de array) en Firestore.
  /// Es crucial usar `FieldValue.arrayUnion` y `FieldValue.arrayRemove`
  /// para añadir/eliminar elementos de un array de forma atómica y segura.
  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para guardar experiencias.', Colors.orange);
      return;
    }

    setState(() {
      _isLoadingFavorite = true; // Muestra carga al alternar.
    });

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (_isFavorite) {
        // Si ya es favorito, lo eliminamos.
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayRemove([widget.experience.id]),
        });
        _showSnackBar('Experiencia eliminada de favoritos.', Colors.grey);
      } else {
        // Si no es favorito, lo añadimos.
        await userDocRef.update({
          'savedExperiences': FieldValue.arrayUnion([widget.experience.id]),
        });
        _showSnackBar('Experiencia guardada en favoritos.', Colors.green);
      }
      // Actualiza el estado local después de una operación exitosa en Firestore.
      setState(() {
        _isFavorite = !_isFavorite;
      });
    } on FirebaseException catch (e) {
      _showSnackBar('Error al actualizar favoritos: ${e.message}', Colors.red);
      print('Firebase Error toggling favorite: $e');
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
      print('General Error toggling favorite: $e');
    } finally {
      setState(() {
        _isLoadingFavorite = false; // Oculta carga.
      });
    }
  }

  /// Muestra un SnackBar con un mensaje y un color de fondo.
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Muestra un diálogo para que el usuario seleccione una fecha de reserva.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2), // Permite reservas hasta 2 años en el futuro.
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFE67E22), // Color de encabezado y botones
              onPrimary: Colors.white, // Color del texto en el encabezado
              onSurface: const Color(0xFF5D4037), // Color del texto del calendario
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE67E22), // Color de los botones de texto
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Muestra un diálogo de formulario de reserva.
  ///
  /// Punto de complejidad:
  /// Este diálogo recolecta los datos de reserva del usuario.
  /// Es importante validar la entrada del usuario y manejar el proceso
  /// de guardado en Firestore.
  void _showBookingForm() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para realizar una reserva.', Colors.orange);
      return;
    }

    // Reinicia los valores del formulario cada vez que se abre el diálogo
    _selectedDate = null;
    _peopleController.text = '1';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // StatefulBuilder para que el diálogo pueda actualizar su estado interno
        builder: (BuildContext context, StateSetter setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                // Selector de fecha
                ListTile(
                  title: Text(
                    _selectedDate == null
                        ? 'Seleccionar fecha'
                        : 'Fecha: ${MaterialLocalizations.of(context).formatShortDate(_selectedDate!)}',
                    style: TextStyle(
                      color: _selectedDate == null ? Colors.grey[600] : const Color(0xFF5D4037),
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFFE67E22)),
                  onTap: () async {
                    await _selectDate(context);
                    setModalState(() {}); // Actualiza el estado del diálogo después de seleccionar la fecha
                  },
                ),
                const SizedBox(height: 16),
                // Selector de número de personas
                TextField(
                  controller: _peopleController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Número de personas',
                    hintText: 'Ej. 2',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF8D6E63)),
                ),
              ),
              ElevatedButton(
                onPressed: _isBooking ? null : () => _createBooking(context), // Llama a la función de crear reserva
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  foregroundColor: Colors.white,
                ),
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

  /// Crea una nueva reserva en la colección 'bookings' de Firestore.
  Future<void> _createBooking(BuildContext dialogContext) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para realizar una reserva.', Colors.orange);
      Navigator.pop(dialogContext); // Cierra el diálogo si no hay usuario
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Por favor, selecciona una fecha para la reserva.', Colors.red);
      return;
    }

    final int? numberOfPeople = int.tryParse(_peopleController.text.trim());
    if (numberOfPeople == null || numberOfPeople <= 0) {
      _showSnackBar('Por favor, ingresa un número válido de personas.', Colors.red);
      return;
    }

    setState(() {
      _isBooking = true; // Activa el indicador de carga del botón de reserva
    });

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user.uid,
        'experienceId': widget.experience.id,
        'experienceTitle': widget.experience.title, // Denormalización
        'experienceImage': widget.experience.imageAsset, // Denormalización
        'bookingDate': Timestamp.fromDate(_selectedDate!),
        'numberOfPeople': numberOfPeople,
        'status': 'pending', // Estado inicial de la reserva
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Muestra el diálogo de confirmación de reserva (tu diálogo original)
      Navigator.pop(dialogContext); // Cierra el diálogo del formulario
      _showBookingConfirmationDialog(); // Muestra el diálogo de confirmación

    } on FirebaseException catch (e) {
      _showSnackBar('Error al crear reserva: ${e.message}', Colors.red);
      print('Firebase Error creating booking: $e');
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado al crear reserva: $e', Colors.red);
      print('General Error creating booking: $e');
    } finally {
      setState(() {
        _isBooking = false; // Desactiva el indicador de carga
      });
    }
  }

  /// Muestra el diálogo de confirmación de reserva (tu diálogo original).
  void _showBookingConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '¡Reserva Confirmada!',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu reserva para "${widget.experience.title}" ha sido confirmada.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Color(0xFFE67E22)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _peopleController.dispose(); // Libera el controlador de texto
    super.dispose();
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
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  // TODO: Implementar la funcionalidad de compartir.
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.experience.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFE67E22),
                            Color(0xFF8B4513),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.experience.isVerified)
                          _buildBadge('Verificado', const Color(0xFF4CAF50), Icons.verified),
                        if (widget.experience.isFeatured)
                          _buildBadge('Destacado', const Color(0xFFFF9800), Icons.star),
                      ],
                    ),
                  ),
                ],
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

                  // Botón de reserva, ahora llama a _showBookingForm
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

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
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
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: Color(0xFF8D6E63)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.experience.location,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8D6E63),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildRatingStars(),
            const SizedBox(width: 8),
            Text(
              '${widget.experience.rating}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE67E22).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.experience.category,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE67E22),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingStars() {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < widget.experience.rating.floor()
              ? Icons.star
              : index < widget.experience.rating
              ? Icons.star_half
              : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.experience.description,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF5D4037),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights() {
    if (widget.experience.highlights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lo que incluye',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.experience.highlights.map((highlight) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                size: 20,
                color: Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  highlight,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: const Color(0xFFE67E22).withOpacity(0.1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map,
                  size: 48,
                  color: Color(0xFFE67E22),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mapa Interactivo',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B4513),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lat: ${widget.experience.latitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  'Lng: ${widget.experience.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceAndDuration() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 32,
                  color: Color(0xFFE67E22),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Duración',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  '${widget.experience.duration}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.attach_money,
                  size: 32,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Precio',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  '\$${widget.experience.price}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const Text(
                  'MXN',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Construye el botón de reserva, ahora llama a _showBookingForm.
  Widget _buildBookingButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _showBookingForm, // Llama al formulario de reserva
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE67E22),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 20),
            SizedBox(width: 8),
            Text(
              'Reservar Experiencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
