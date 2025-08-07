import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart'; // Para seleccionar imágenes
import 'package:firebase_storage/firebase_storage.dart'; // Para subir imágenes
import 'dart:io';
import 'dart:typed_data';

import 'welcome_screen.dart';
import '../models/user.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';

/// Clase de modelo simple para una reserva. Lo importo aunque ya exista
class Booking {
  final String id;
  final String userId;
  final String experienceId;
  final String experienceTitle;
  final String experienceImage;
  final DateTime bookingDate;
  final int numberOfPeople;
  final String status;
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

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Booking(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      experienceId: data?['experienceId'] as String? ?? '',
      experienceTitle: data?['experienceTitle'] as String? ?? 'Experiencia Desconocida',
      experienceImage: data?['experienceImage'] as String? ?? 'assets/images/placeholder.png',
      bookingDate: (data?['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      numberOfPeople: (data?['numberOfPeople'] as num?)?.toInt() ?? 1,
      status: data?['status'] as String? ?? 'pending',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _currentUser; // Usamos tu modelo AppUser
  bool _isLoadingProfile = true; // Para manejar el estado de carga inicial

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        setState(() {
          _currentUser = null; // No hay usuario
          _isLoadingProfile = false;
        });
      }
      return;
    }

    // Inicia la carga
    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
      });
    }

    _userSubscription = _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          setState(() {
            _currentUser = AppUser.fromFirestore(snapshot);
            _isLoadingProfile = false;
          });
        } else {
          // Si el documento no existe, podríamos crear un AppUser básico
          // o manejarlo como un estado de "perfil no encontrado/incompleto".
          // Por ahora, lo dejamos como null y mostramos un mensaje de invitado.
          setState(() {
            // Creamos un usuario temporal con datos de FirebaseAuth si el documento no existe.
            // Esto es opcional, podrías preferir _currentUser = null y manejarlo en la UI.
            _currentUser = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? 'No disponible',
              name: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Usuario',
              role: 'user', // Rol por defecto si no hay documento
            );
            _isLoadingProfile = false;
            // Opcional: Crear el documento en Firestore con valores por defecto
            // _firestore.collection('users').doc(firebaseUser.uid).set(
            //   _currentUser!.toMap(), SetOptions(merge: true) // Usar merge por si acaso
            // );
          });
        }
      }
    }, onError: (error) {
      print('Error loading user profile: $error');
      if (mounted) {
        _showSnackBar('Error al cargar perfil: ${error.toString()}', Colors.red);
        setState(() {
          _isLoadingProfile = false;
        });
      }
    });
  }

  Future<void> _signOut() async {
    try {
      await _userSubscription?.cancel(); // Cancelar suscripción antes de cerrar sesión
      _userSubscription = null;
      await _auth.signOut();
      _showSnackBar('Sesión cerrada exitosamente.', Colors.green);
      if (mounted) {
        setState(() {
          _currentUser = null; // Limpiar el usuario actual
        });
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error al cerrar sesión: ${e.message}', Colors.red);
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado al cerrar sesión: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null && _auth.currentUser != null) {
      // Caso donde el usuario de Firebase existe pero el de Firestore aún no carga
      // o no se encontró y no se creó uno temporal.
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Cargando datos del perfil...'),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _signOut, child: const Text('Cerrar sesión'))
                ],
              ),
            )
        ),
      );
    }


    // Si _currentUser sigue siendo null después de la carga (y no hay error)
    // es probable que el usuario no esté autenticado o el documento no exista y no se creó uno temporal.
    // El caso de no autenticado se maneja más arriba, aquí asumimos que el documento no existe.
    final AppUser displayUser = _currentUser ?? AppUser(
        uid: _auth.currentUser?.uid ?? 'guest',
        email: _auth.currentUser?.email ?? 'invitado@example.com',
        name: 'Invitado',
        role: 'guest'
    );


    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFE67E22)),
            onPressed: () {
              _showSnackBar('Pantalla de configuración no implementada.', Colors.blueGrey);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadUserProfile(); // Esto re-evaluará el stream
          // No es necesario setState aquí usualmente, el stream lo maneja
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(displayUser), // Pasamos el AppUser
              const SizedBox(height: 24),
              // Pasarías displayUser.experiencesSubmitted o calcularías desde las reservas
              _buildStatsSection(displayUser.experiencesSubmitted, /* otras stats */),
              const SizedBox(height: 24),
              _buildFavoritesSection(displayUser),
              const SizedBox(height: 24),
              _buildBookingHistorySection(displayUser),
              const SizedBox(height: 24),
              _buildProfileOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8DC), Color(0xFFF5E6D3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: (_auth.currentUser != null && _auth.currentUser!.uid == user.uid)
                ? _showImageSourceDialog // ¡Aquí está el cambio!
                : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  onBackgroundImageError: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty ? (exception, stackTrace) {
                    print('Error loading profile image from URL: ${user.profileImageUrl}. Error: $exception');
                  } : null,
                  child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) && user.name != null && user.name!.isNotEmpty
                      ? Text(
                    user.name![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                      : (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                      ? Icon(Icons.person, size: 45, color: Theme.of(context).colorScheme.onPrimaryContainer)
                      : null,
                ),
                if (_auth.currentUser != null && _auth.currentUser!.uid == user.uid)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name ?? user.email.split('@')[0],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor(user.role),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (user.interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: user.interests
                  .map((interest) => Chip(
                label: Text(interest),
                backgroundColor: const Color(0xFFF5E6D3).withOpacity(0.8),
                labelStyle: const TextStyle(color: Color(0xFF8B4513), fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': // Tu modelo usa 'admin'
      case 'administrador':
        return Colors.red.shade700;
      case 'moderator': // Tu modelo usa 'moderator'
      case 'moderador':
        return Colors.blue.shade700;
    // Puedes añadir más roles de tu modelo si es necesario
    // case 'creador':
    // case 'artista':
    // case 'artesano':
    // case 'residente':
    //   return Colors.purple.shade600;
      case 'user': // Tu modelo usa 'user'
      case 'usuario':
      default:
        return const Color(0xFFE67E22);
    }
  }

  // Ahora las estadísticas toman el valor de AppUser
  Widget _buildStatsSection(int experiencesSubmitted, /* otras stats que puedas tener */) {
    // TODO: Obtener "Comunidades Apoyadas" y "Artesanos Conocidos" dinámicamente si es posible
    // Podrían ser otras propiedades en AppUser o calculadas de otra colección.
    int communitiesSupported = 3; // Placeholder
    int artisansMet = 12; // Placeholder

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: _StatCard(number: experiencesSubmitted.toString(), label: 'Experiencias\nSubidas', icon: Icons.publish_outlined)), // Usar experiencesSubmitted
        const SizedBox(width: 12),
        Expanded(child: _StatCard(number: communitiesSupported.toString(), label: 'Comunidades\nApoyadas', icon: Icons.people_outline)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(number: artisansMet.toString(), label: 'Artesanos\nConocidos', icon: Icons.handshake_outlined)),
      ],
    );
  }

  Widget _buildFavoritesSection(AppUser user) {
    // Ya no necesitamos StreamBuilder para el documento del usuario aquí,
    // porque `user.savedExperiences` ya tiene los IDs.
    // Solo necesitamos el FutureBuilder para cargar los detalles de las experiencias.
    if (user.uid == 'guest') { // Si es el usuario "Invitado" que definimos
      return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'Inicia sesión para ver tus favoritos.');
    }

    if (user.savedExperiences.isEmpty) {
      return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'Aún no tienes experiencias guardadas.');
    }

    return FutureBuilder<List<Experience>>(
      key: ValueKey(user.savedExperiences.join(',')), // Para reconstruir si cambian los favoritos
      future: _fetchExperiencesByIds(user.savedExperiences),
      builder: (context, experienceSnapshot) {
        if (experienceSnapshot.connectionState == ConnectionState.waiting) {
          return _buildSectionLoadingIndicator('Mis Experiencias Favoritas');
        }
        if (experienceSnapshot.hasError) {
          return _buildSectionError('Mis Experiencias Favoritas', 'Error al cargar detalles: ${experienceSnapshot.error}');
        }
        if (!experienceSnapshot.hasData || experienceSnapshot.data!.isEmpty) {
          return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'No se encontraron detalles de las experiencias.');
        }

        final favoriteExperiences = experienceSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis Experiencias Favoritas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: favoriteExperiences.length,
                itemBuilder: (context, index) {
                  return _buildFavoriteCard(favoriteExperiences[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Experience>> _fetchExperiencesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Considera el límite de 10 para 'whereIn' si la lista de IDs puede ser muy larga.
    // Para favoritos, generalmente no es un problema.
    final querySnapshot = await _firestore.collection('experiences').where(FieldPath.documentId, whereIn: ids).get();
    return querySnapshot.docs.map((doc) => Experience.fromFirestore(doc)).toList();
  }


  Widget _buildBookingHistorySection(AppUser user) {
    if (user.uid == 'guest') {
      return _buildSectionPlaceholder('Historial de Reservas', 'Inicia sesión para ver tu historial.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('bookingDate', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildSectionLoadingIndicator('Historial de Reservas');
        }
        if (snapshot.hasError) {
          return _buildSectionError('Historial de Reservas', 'Error: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionPlaceholder('Historial de Reservas', 'Aún no tienes reservas.');
        }

        final bookings = snapshot.data!.docs
            .map((doc) => Booking.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();

        return Column(
          // ... (resto del widget _buildBookingHistorySection sin cambios, ya que usa el user.uid)
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de Reservas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                return _buildBookingCard(bookings[index]);
              },
            ),
            if (bookings.length >= 10)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      _showSnackBar('Ver todas las reservas no implementado.', Colors.blueGrey);
                    },
                    child: const Text('Ver todas las reservas'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

// Nueva función que muestra el diálogo con las opciones
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Cambiar foto de perfil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text("Subir desde galería"),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.link),
                title: Text("Usar URL de Internet"),
                onTap: () {
                  Navigator.of(context).pop();
                  _showUrlInputDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.folder_open),
                title: Text("Usar imagen local (assets)"),
                onTap: () {
                  Navigator.of(context).pop();
                  // Aquí necesitarás una lista de tus assets disponibles
                  _showLocalAssetsDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

// Nueva función para subir desde la galería (tu lógica original)
  Future<void> _uploadImageFromGallery() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || _currentUser == null || firebaseUser.uid != _currentUser!.uid) {
      _showSnackBar('No se pudo identificar al usuario.', Colors.red);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      if (mounted) _showSnackBar('Subiendo imagen...', Colors.blue);

      String fileName = 'profile_images/${firebaseUser.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child(fileName);

      UploadTask uploadTask;

      if (kIsWeb) {
        Uint8List imageData = await image.readAsBytes();
        uploadTask = storageRef.putData(imageData);
      } else {
        File imageFile = File(image.path);
        uploadTask = storageRef.putFile(imageFile);
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Actualizar la URL en Firestore
      await _firestore.collection('users').doc(firebaseUser.uid).update({'profileImageUrl': downloadUrl});

      if (mounted) {
        _showSnackBar('Foto de perfil actualizada.', Colors.green);
      }
    } catch (e) {
      print("Error al subir imagen de perfil: $e");
      if (mounted) {
        _showSnackBar('Error al subir la imagen: ${e.toString()}', Colors.red);
      }
    }
  }

// Nueva función para usar una URL de internet
  void _showUrlInputDialog() {
    final _urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Ingresar URL de imagen"),
          content: TextField(
            controller: _urlController,
            decoration: InputDecoration(hintText: "https://example.com/imagen.jpg"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Guardar"),
              onPressed: () {
                final url = _urlController.text.trim();
                if (url.isNotEmpty) {
                  _updateProfileImageUrl(url);
                  Navigator.of(context).pop();
                } else {
                  _showSnackBar('La URL no puede estar vacía.', Colors.red);
                }
              },
            ),
          ],
        );
      },
    );
  }

// Nueva función para seleccionar un asset local
  void _showLocalAssetsDialog() {
    // Asegúrate de tener una lista de tus imágenes locales aquí
    final List<String> localAssets = [
      'assets/images/user1.jpg',
      'assets/images/user2.jpg',
      // ... agrega más paths de tus assets
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Seleccionar imagen de assets"),
          content: SingleChildScrollView(
            child: Column(
              children: localAssets.map((path) => ListTile(
                leading: CircleAvatar(backgroundImage: AssetImage(path)),
                title: Text(path.split('/').last),
                onTap: () {
                  _updateProfileImageUrl(path);
                  Navigator.of(context).pop();
                },
              )).toList(),
            ),
          ),
        );
      },
    );
  }

// Función común para actualizar la URL en Firestore
  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _showSnackBar('No se pudo identificar al usuario para cambiar la foto.', Colors.red);
      return;
    }

    try {
      await _firestore.collection('users').doc(firebaseUser.uid).update({'profileImageUrl': imageUrl});
      _showSnackBar('Foto de perfil actualizada.', Colors.green);
    } catch (e) {
      _showSnackBar('Error al actualizar la foto de perfil.', Colors.red);
    }
  }

  // --- Widgets auxiliares sin cambios significativos en su lógica interna ---
  // _buildFavoriteCard, _getIconForCategory, _buildBookingCard,
  // _getBookingStatusColor, _buildProfileOptions, _buildOptionItem,
  // _buildSectionPlaceholder, _buildSectionLoadingIndicator, _buildSectionError, _StatCard
  // Estos se mantienen como en la versión anterior, solo asegúrate de que usen los datos
  // de `AppUser user` si se los pasas como parámetro donde sea necesario.

  Widget _buildFavoriteCard(Experience experience) {
    // ... (código como antes)
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExperienceDetailScreen(experience: experience),
          ),
        );
      },
      child: Container(
        width: 130, // Ancho ligeramente mayor
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.grey[200], // Fondo mientras carga o si falla la imagen
                  child: Image.asset(
                    experience.imageAsset.isNotEmpty ? experience.imageAsset : 'assets/images/placeholder.png', // Fallback a placeholder
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print("Error cargando imagen de favorito (asset): ${experience.imageAsset} - $error");
                      return Icon(
                        _getIconForCategory(experience.category),
                        size: 30,
                        color: Theme.of(context).primaryColorDark,
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        experience.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 2),
                          Text(
                            experience.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
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

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'gastronomía': return Icons.restaurant_menu;
      case 'arte y artesanía': return Icons.palette_outlined;
      case 'patrimonio': return Icons.account_balance_outlined;
      case 'naturaleza y aventura': return Icons.terrain_outlined;
      case 'música y danza': return Icons.music_note_outlined;
      case 'bienestar': return Icons.spa_outlined;
      default: return Icons.explore_outlined;
    }
  }

  Widget _buildBookingCard(Booking booking) {
    // ... (código como antes)
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( // Para efecto ripple al tocar
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showSnackBar('Detalles de reserva no implementado.', Colors.blueGrey);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: Image.asset(
                    booking.experienceImage.isNotEmpty ? booking.experienceImage : 'assets/images/placeholder.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print("Error cargando imagen de reserva (asset): ${booking.experienceImage} - $error");
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 30),
                      );
                    },
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${MaterialLocalizations.of(context).formatShortDate(booking.bookingDate)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)),
                    ),
                    Text(
                      'Personas: ${booking.numberOfPeople}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _getBookingStatusColor(booking.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _getBookingStatusColor(booking.status).withOpacity(0.5), width: 0.5)
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
              const Icon(Icons.chevron_right, color: Color(0xFF8D6E63), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBookingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade700;
      case 'confirmed': return Colors.green.shade700;
      case 'cancelled': return Colors.red.shade700;
      default: return Colors.grey.shade600;
    }
  }

  Widget _buildProfileOptions() {
    // ... (código como antes)
    return Column(
      children: [
        _buildOptionItem(Icons.bookmark_border_outlined, 'Experiencias Guardadas', () {
          _showSnackBar('Tus experiencias guardadas se muestran arriba.', Colors.blueGrey);
        }),
        _buildOptionItem(Icons.history_outlined, 'Historial de Reservas', () {
          _showSnackBar('Tu historial de reservas se muestra arriba.', Colors.blueGrey);
        }),
        _buildOptionItem(Icons.payment_outlined, 'Métodos de Pago', () {
          _showSnackBar('Métodos de pago no implementado.', Colors.blueGrey);
        }),
        _buildOptionItem(Icons.notifications_none_outlined, 'Notificaciones', () {
          _showSnackBar('Notificaciones no implementado.', Colors.blueGrey);
        }),
        _buildOptionItem(Icons.help_outline_outlined, 'Ayuda y Soporte', () {
          _showSnackBar('Ayuda y soporte no implementado.', Colors.blueGrey);
        }),
        _buildOptionItem(Icons.privacy_tip_outlined, 'Privacidad', () {
          _showSnackBar('Privacidad no implementado.', Colors.blueGrey);
        }),
        const SizedBox(height: 10),
        _buildOptionItem(Icons.logout_outlined, 'Cerrar Sesión', _signOut, isDestructive: true),
      ],
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    // ... (código como antes)
    final color = isDestructive ? Colors.red.shade700 : const Color(0xFFE67E22);
    return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              title,
              style: TextStyle(
                color: isDestructive ? Colors.red.shade700 : const Color(0xFF5D4037),
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF8D6E63), size: 20),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
    );
  }

  // Widgets auxiliares para placeholders de secciones
  Widget _buildSectionPlaceholder(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
        ),
        const SizedBox(height: 16),
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(message, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
        )),
      ],
    );
  }

  Widget _buildSectionLoadingIndicator(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
        ),
        const SizedBox(height: 16),
        const Center(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: CircularProgressIndicator(),
        )),
      ],
    );
  }

  Widget _buildSectionError(String title, String errorMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
        ),
        const SizedBox(height: 16),
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(errorMessage, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
        )),
      ],
    );
  }
} // Fin de _ProfileScreenState

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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: const Color(0xFFE67E22),
          ),
          const SizedBox(height: 8),
          Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
