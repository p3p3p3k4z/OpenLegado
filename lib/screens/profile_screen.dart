import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';     // Para obtener el usuario autenticado
import 'package:cloud_firestore/cloud_firestore.dart'; // Para interactuar con Firestore
import 'dart:async';                                  // Importa para StreamSubscription
import 'welcome_screen.dart';                          // Importa WelcomeScreen para la navegación al cerrar sesión
import '../models/experience.dart';                    // Importa el modelo Experience
import 'experience_detail_screen.dart';                // Para navegar a los detalles de la experiencia

/// Clase de modelo simple para una reserva.
/// Esto nos ayuda a estructurar los datos de la reserva de Firestore en un objeto Dart.
class Booking {
  final String id;
  final String userId;
  final String experienceId;
  final String experienceTitle;
  final String experienceImage; // Usamos la ruta de asset o URL de la imagen
  final DateTime bookingDate;
  final int numberOfPeople;
  final String status; // Ej. 'pending', 'confirmed', 'cancelled'
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.userId,
    required this.experienceId,
    required this.experienceTitle,
    required this.experienceImage,
    required this.bookingDate,
    required this.numberOfPeople,
    required this.status,
    required this.createdAt,
  });

  /// Constructor de fábrica para crear una instancia de Booking desde un DocumentSnapshot de Firestore.
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Booking(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      experienceId: data?['experienceId'] as String? ?? '',
      experienceTitle: data?['experienceTitle'] as String? ?? 'Experiencia Desconocida',
      experienceImage: data?['experienceImage'] as String? ?? 'assets/placeholder.jpg',
      bookingDate: (data?['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      numberOfPeople: (data?['numberOfPeople'] as num?)?.toInt() ?? 1,
      status: data?['status'] as String? ?? 'pending',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Pantalla de perfil de usuario.
/// Muestra información del usuario, estadísticas y opciones de configuración,
/// cargando datos dinámicamente desde Firebase Firestore, incluyendo intereses,
/// experiencias favoritas e historial de reservas.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Datos del usuario, se inicializan con valores por defecto y se actualizarán desde Firestore.
  String _userName = 'Cargando...';
  String _userEmail = 'Cargando...';
  List<String> _userInterests = [];
  String _userLevel = 'Explorador Cultural'; // Nivel por defecto, podría ser dinámico
  String _profileImageUrl = ''; // URL de la imagen de perfil, si la hubiera

  // StreamSubscription para escuchar cambios en el documento del usuario en Firestore.
  // Es importante cancelarlo en dispose() para evitar fugas de memoria.
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // Carga el perfil del usuario al iniciar la pantalla.
  }

  /// Carga el perfil del usuario desde Firestore y escucha cambios en tiempo real.
  ///
  /// Punto de complejidad:
  /// Utiliza un Stream para obtener actualizaciones en tiempo real de Firestore.
  /// Esto es eficiente pero requiere manejar la suscripción y su cancelación.
  void _loadUserProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Si no hay usuario, limpiar los datos o redirigir.
      setState(() {
        _userName = 'Invitado';
        _userEmail = 'No autenticado';
        _userInterests = [];
        _profileImageUrl = '';
      });
      return;
    }

    // Escucha el documento del usuario en la colección 'users'.
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots() // Obtiene un stream de snapshots en tiempo real.
        .listen((snapshot) {
      if (snapshot.exists) {
        // Si el documento existe, actualiza el estado con los datos.
        final data = snapshot.data();
        setState(() {
          _userName = data?['username'] ?? user.email?.split('@')[0] ?? 'Usuario';
          _userEmail = user.email ?? 'No disponible';
          _userInterests = List<String>.from(data?['interests'] ?? []);
          _profileImageUrl = data?['profileImageUrl'] ?? ''; // Asumiendo un campo para la URL de la imagen
          // Puedes añadir lógica para _userLevel si lo guardas en Firestore
        });
      } else {
        // Si el documento no existe (ej. usuario recién registrado y aún no guarda intereses),
        // usar datos básicos del usuario de Auth.
        setState(() {
          _userName = user.email?.split('@')[0] ?? 'Usuario';
          _userEmail = user.email ?? 'No disponible';
          _userInterests = [];
          _profileImageUrl = '';
        });
      }
    }, onError: (error) {
      // Manejo de errores en el stream.
      _showSnackBar('Error al cargar perfil: $error', Colors.red);
      print('Error loading user profile: $error'); // Para depuración
    });
  }

  /// Maneja el cierre de sesión del usuario.
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _showSnackBar('Sesión cerrada exitosamente.', Colors.green);
      // Después de cerrar sesión, redirige al usuario a la pantalla de bienvenida.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()), // WelcomeScreen ahora está importado
            (Route<dynamic> route) => false, // Elimina todas las rutas anteriores.
      );
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error al cerrar sesión: ${e.message}', Colors.red);
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado al cerrar sesión: $e', Colors.red);
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

  @override
  void dispose() {
    _userSubscription?.cancel(); // Cancela la suscripción al stream para evitar fugas.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(
            color: Color(0xFF8B4513), // Marrón Tierra.
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Botón de configuración.
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFE67E22)), // Naranja Principal.
            onPressed: () {
              // TODO: Implementar la navegación a una pantalla de configuración.
            },
          ),
        ],
      ),
      body: SingleChildScrollView( // Permite que el contenido se desplace si es demasiado largo.
        padding: const EdgeInsets.all(16), // Padding general.
        child: Column(
          children: [
            // Header del perfil
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // Estadísticas (aún fijas, se pueden hacer dinámicas después)
            _buildStatsSection(),
            const SizedBox(height: 24),

            // Experiencias favoritas (AHORA DINÁMICAS)
            _buildFavoritesSection(),
            const SizedBox(height: 24),

            // Historial de Reservas (NUEVA SECCIÓN)
            _buildBookingHistorySection(),
            const SizedBox(height: 24),

            // Opciones del perfil
            _buildProfileOptions(),
          ],
        ),
      ),
    );
  }

  /// Construye el encabezado del perfil con avatar, nombre y nivel.
  /// Ahora usa los datos dinámicos del estado.
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF8DC), // Beige claro.
            Color(0xFFF5E6D3), // Beige más oscuro.
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar del usuario.
          // Si _profileImageUrl está disponible, usa NetworkImage, de lo contrario, usa iniciales.
          _profileImageUrl.isNotEmpty
              ? CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(_profileImageUrl),
            onBackgroundImageError: (exception, stackTrace) {
              // Fallback si la imagen de red falla
              print('Error loading profile image: $exception');
            },
          )
              : Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE67E22), // Naranja Principal.
                  Color(0xFF8B4513), // Marrón Tierra.
                ],
              ),
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : '?', // Primera letra del nombre
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nombre del usuario.
          Text(
            _userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 4),
          // Nivel o rol del usuario.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _userLevel, // Nivel (placeholder o dinámico si se añade a Firestore)
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Mostrar intereses si están disponibles
          if (_userInterests.isNotEmpty)
            Wrap(
              spacing: 8.0, // Espacio horizontal entre chips
              runSpacing: 4.0, // Espacio vertical entre líneas de chips
              alignment: WrapAlignment.center,
              children: _userInterests.map((interest) => Chip(
                label: Text(interest),
                backgroundColor: const Color(0xFFF5E6D3), // Beige suave
                labelStyle: const TextStyle(color: Color(0xFF8B4513), fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              )).toList(),
            ),
        ],
      ),
    );
  }

  /// Construye la sección de estadísticas del usuario.
  ///
  /// **Punto de complejidad:**
  /// Los números de las estadísticas son fijos.
  /// En una aplicación real, estos datos deberían ser dinámicos y reflejar
  /// la actividad real del usuario, obtenidos de la base de datos.
  Widget _buildStatsSection() {
    return const Row(
      children: [
        Expanded(child: _StatCard(number: '5', label: 'Experiencias\nCompletadas', icon: Icons.check_circle)),
        SizedBox(width: 12),
        Expanded(child: _StatCard(number: '3', label: 'Comunidades\nApoyadas', icon: Icons.people)),
        SizedBox(width: 12),
        Expanded(child: _StatCard(number: '12', label: 'Artesanos\nConocidos', icon: Icons.handshake)),
      ],
    );
  }

  /// Construye la sección de experiencias favoritas.
  /// Ahora carga las experiencias favoritas desde Firestore.
  Widget _buildFavoritesSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tus favoritos.'));
    }

    // StreamBuilder para escuchar cambios en el documento del usuario y obtener los IDs de favoritos.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (userSnapshot.hasError) {
          return Center(child: Text('Error al cargar favoritos: ${userSnapshot.error}'));
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text('No se encontraron datos de usuario.'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final List<String> savedExperienceIds = List<String>.from(userData?['savedExperiences'] ?? []);

        if (savedExperienceIds.isEmpty) {
          return const Center(child: Text('Aún no tienes experiencias guardadas.'));
        }

        // FutureBuilder para obtener los detalles de las experiencias favoritas usando los IDs.
        // Se usa FutureBuilder porque la lista de IDs no cambia constantemente,
        // solo cuando el usuario guarda/desguarda.
        return FutureBuilder<List<Experience>>(
          future: FirebaseFirestore.instance
              .collection('experiences')
              .where(FieldPath.documentId, whereIn: savedExperienceIds)
              .get()
              .then((querySnapshot) => querySnapshot.docs.map((doc) => Experience.fromFirestore(doc)).toList()),
          builder: (context, experienceSnapshot) {
            if (experienceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (experienceSnapshot.hasError) {
              return Center(child: Text('Error al cargar detalles de favoritos: ${experienceSnapshot.error}'));
            }
            if (!experienceSnapshot.hasData || experienceSnapshot.data!.isEmpty) {
              return const Center(child: Text('No se encontraron experiencias guardadas.'));
            }

            final favoriteExperiences = experienceSnapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis Experiencias Favoritas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120, // Altura fija para el carrusel de favoritos.
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal, // Scroll horizontal.
                    itemCount: favoriteExperiences.length,
                    itemBuilder: (context, index) {
                      return _buildFavoriteCard(favoriteExperiences[index]); // Construye cada tarjeta de favorito.
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Construye una tarjeta individual para una experiencia favorita.
  /// Ahora recibe un objeto `Experience` completo.
  Widget _buildFavoriteCard(Experience experience) {
    return GestureDetector(
      onTap: () {
        // Navega a la pantalla de detalles de la experiencia al tocar la tarjeta.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExperienceDetailScreen(experience: experience),
          ),
        );
      },
      child: Container(
        width: 100, // Ancho fijo de la tarjeta.
        margin: const EdgeInsets.only(right: 12), // Margen a la derecha.
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
          child: Column(
            children: [
              // Sección de imagen/icono de la tarjeta.
              Expanded(
                child: Container(
                  width: double.infinity,
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
                  child: Center(
                    child: Image.asset(
                      experience.imageAsset, // Usa la imagen real de la experiencia
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _getIconForCategory(experience.category), // Fallback a icono
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Información de la tarjeta.
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      experience.title, // Título de la experiencia.
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2, // Limita a 2 líneas para evitar desbordamiento
                      overflow: TextOverflow.ellipsis, // Añade puntos suspensivos si se desborda
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          experience.rating.toStringAsFixed(1), // Calificación.
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8D6E63),
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
    );
  }

  /// Devuelve un icono de Material Design basado en el nombre de la categoría.
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Gastronomía':
        return Icons.restaurant;
      case 'Arte y Artesanía':
        return Icons.palette;
      case 'Patrimonio':
        return Icons.account_balance;
      case 'Naturaleza y Aventura':
        return Icons.terrain;
      case 'Música y Danza':
        return Icons.music_note;
      case 'Bienestar':
        return Icons.spa;
      default:
        return Icons.explore;
    }
  }

  /// Construye la sección de historial de reservas.
  /// Carga y muestra las reservas del usuario actual desde Firestore.
  Widget _buildBookingHistorySection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Inicia sesión para ver tu historial de reservas.'));
    }

    // StreamBuilder para escuchar cambios en la colección 'bookings' del usuario.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid) // Filtra por el ID del usuario actual.
          .orderBy('bookingDate', descending: true) // Ordena por fecha de reserva (más reciente primero).
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar historial: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aún no tienes reservas.'));
        }

        final bookings = snapshot.data!.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de Reservas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B4513),
              ),
            ),
            const SizedBox(height: 16),
            // Utiliza un ListView.builder para mostrar la lista de reservas.
            // Se usa ShrinkWrap y NeverScrollableScrollPhysics para que el ListView
            // se ajuste al tamaño de su contenido dentro del SingleChildScrollView principal.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                return _buildBookingCard(bookings[index]);
              },
            ),
          ],
        );
      },
    );
  }

  /// Construye una tarjeta individual para una reserva en el historial.
  Widget _buildBookingCard(Booking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen de la experiencia reservada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Image.asset(
                booking.experienceImage, // Usamos la imagen de la experiencia
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.experienceTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha: ${MaterialLocalizations.of(context).formatShortDate(booking.bookingDate)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  'Personas: ${booking.numberOfPeople}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                const SizedBox(height: 4),
                // Estado de la reserva con color
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getBookingStatusColor(booking.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getBookingStatusColor(booking.status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Icono de flecha para detalles (opcional)
          const Icon(Icons.chevron_right, color: Color(0xFF8D6E63)),
        ],
      ),
    );
  }

  /// Devuelve un color basado en el estado de la reserva.
  Color _getBookingStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Construye la sección de opciones del perfil (lista de ListTile).
  Widget _buildProfileOptions() {
    return Column(
      children: [
        _buildOptionItem(Icons.bookmark, 'Experiencias Guardadas', () {
          // Esta sección ya es dinámica, el onTap podría ser para una pantalla de "Ver todas"
        }),
        _buildOptionItem(Icons.history, 'Historial de Reservas', () {
          // Esta sección ya es dinámica, el onTap podría ser para una pantalla de "Ver todas"
        }),
        _buildOptionItem(Icons.payment, 'Métodos de Pago', () {
          // TODO: Implementar navegación a métodos de pago
        }),
        _buildOptionItem(Icons.notifications, 'Notificaciones', () {
          // TODO: Implementar navegación a notificaciones
        }),
        _buildOptionItem(Icons.help, 'Ayuda y Soporte', () {
          // TODO: Implementar navegación a ayuda y soporte
        }),
        _buildOptionItem(Icons.privacy_tip, 'Privacidad', () {
          // TODO: Implementar navegación a privacidad
        }),
        // Botón de cerrar sesión, ahora con funcionalidad Firebase Auth
        _buildOptionItem(Icons.logout, 'Cerrar Sesión', _signOut, isDestructive: true),
      ],
    );
  }

  /// Construye un `ListTile` reutilizable para las opciones del perfil.
  /// [icon]: Icono principal.
  /// [title]: Texto de la opción.
  /// [onTap]: Callback al presionar la opción.
  /// [isDestructive]: Si es true, el icono y el texto serán rojos (ej. "Cerrar Sesión").
  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFFE67E22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : const Color(0xFF5D4037),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF8D6E63),
        ),
        onTap: onTap,
      ),
    );
  }
}

// Widget auxiliar para una tarjeta de estadística individual.
class _StatCard extends StatelessWidget {
  final String number;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.number,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(
            icon,
            size: 24,
            color: const Color(0xFFE67E22),
          ),
          const SizedBox(height: 8),
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8D6E63),
            ),
          ),
        ],
      ),
    );
  }
}
