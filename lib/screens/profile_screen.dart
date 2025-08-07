import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; // Para kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // Para File, si no es kIsWeb
import 'dart:typed_data'; // Para Uint8List, si es kIsWeb
import 'dart:convert'; // Para json.decode en _showLocalAssetsDialog
import 'package:flutter/services.dart' show rootBundle; // Para rootBundle en _showLocalAssetsDialog


import 'welcome_screen.dart';
import '../models/user.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';

// ... (Tu clase Booking se mantiene igual)
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
  AppUser? _currentUser;
  bool _isLoadingProfile = true;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  static const String _guestUid = 'guest_mode_uid'; // UID único para invitados en la UI
  static const String _defaultGuestProfileImage = 'assets/images/default_avatar_guest.png'; // Define esta imagen en tus assets

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      // CASO 1: Usuario no autenticado (Invitado puro)
      if (mounted) {
        setState(() {
          _currentUser = AppUser( // Creamos un AppUser específico para el invitado
            uid: _guestUid,
            email: 'invitado@example.com',
            name: 'Invitado',
            role: 'guest',
            profileImageUrl: _defaultGuestProfileImage, // Imagen por defecto para invitado
            // Listas vacías y 0 para contadores ya están por defecto en el constructor de AppUser
          );
          _isLoadingProfile = false;
        });
        print("Perfil: Modo Invitado. UID: ${_currentUser?.uid}");
      }
      return;
    }

    // CASO 2: Usuario autenticado, intentamos cargar desde Firestore
    if (mounted) {
      setState(() {
        _isLoadingProfile = true; // Mostrar carga mientras se obtiene de Firestore
      });
    }

    _userSubscription?.cancel(); // Cancelar suscripción anterior si existe
    _userSubscription = _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          // Usuario autenticado con perfil en Firestore
          setState(() {
            _currentUser = AppUser.fromFirestore(snapshot);
            _isLoadingProfile = false;
          });
          print("Perfil: Usuario '${_currentUser?.name}' cargado desde Firestore.");
        } else {
          // Usuario autenticado PERO SIN perfil en Firestore (ej. nuevo registro)
          // Creamos un AppUser temporal con datos de FirebaseAuth
          print("Perfil: Documento de usuario no encontrado para ${firebaseUser.uid}. Creando perfil temporal.");
          setState(() {
            _currentUser = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? 'No disponible',
              name: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0], // Nombre temporal
              // role ya tiene 'user' por defecto
              // profileImageUrl será null por defecto, lo cual está bien (mostrará iniciales o icono)
            );
            _isLoadingProfile = false;
            // Opcional: Podrías crear el documento en Firestore aquí si lo deseas
            // como un perfil base, aunque a veces es mejor que el usuario lo complete.
            // _firestore.collection('users').doc(firebaseUser.uid).set(_currentUser!.toMap());
          });
        }
      }
    }, onError: (error) {
      print('Error al cargar perfil de usuario: $error');
      if (mounted) {
        _showSnackBar('Error al cargar perfil: ${error.toString()}', Colors.red);
        setState(() {
          _isLoadingProfile = false;
          // En caso de error, podríamos volver a un estado de invitado o mostrar un mensaje
          // Aquí optamos por dejar _currentUser como podría haber quedado (potencialmente null o el último valor)
          // O podrías forzar un estado de error más explícito si lo deseas.
          _currentUser = AppUser(
            uid: firebaseUser.uid, // Mantenemos el uid del usuario autenticado
            email: firebaseUser.email ?? 'Error',
            name: 'Error al cargar',
            role: 'user',
          );
        });
      }
    });
  }

  // ----- FUNCIÓN MODIFICADA: _signOut (para limpiar el estado del perfil) -----
  Future<void> _signOut() async {
    try {
      await _userSubscription?.cancel();
      _userSubscription = null;
      await _auth.signOut();

      if (mounted) {
        _showSnackBar('Sesión cerrada exitosamente.', Colors.green);
        // Al cerrar sesión, volvemos al estado de invitado o a la pantalla de bienvenida
        // Forzamos la recarga del perfil que ahora resultará en el modo invitado
        // o navegamos directamente.
        setState(() {
          _currentUser = null; // Limpiar usuario
          _isLoadingProfile = true; // Para forzar un ciclo de recarga o mostrar loader
        });
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()), // O tu pantalla de login/invitado
              (Route<dynamic> route) => false,
        );
        // Si no navegas, y quieres que esta misma pantalla muestre el modo invitado:
        // _loadUserProfile(); // Esto cargaría el perfil de invitado
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnackBar('Error al cerrar sesión: ${e.message}', Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
    }
  }

  // ----- NUEVA FUNCIÓN AUXILIAR: _isGuestMode -----
  // Para verificar fácilmente si estamos en modo invitado.
  bool _isGuestMode(AppUser? user) {
    return user?.uid == _guestUid;
  }

  // --- INICIO DE FUNCIONES INTEGRADAS PARA CAMBIO DE IMAGEN ---
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3), // Añadido para consistencia
        ),
      );
    }
  }

  // Muestra el diálogo con las opciones de carga
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Cambiar foto de perfil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Subir desde galería"),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text("Usar URL de Internet"),
                onTap: () {
                  Navigator.of(context).pop();
                  _showUrlInputDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text("Usar imagen local (assets)"),
                onTap: () {
                  Navigator.of(context).pop();
                  _showLocalAssetsDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Lógica para subir desde la galería
  Future<void> _uploadImageFromGallery() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
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
        uploadTask = storageRef.putData(imageData, SettableMetadata(contentType: 'image/jpeg')); // Es buena práctica setear el contentType
      } else {
        File imageFile = File(image.path);
        uploadTask = storageRef.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg')); // Es buena práctica setear el contentType
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Se actualiza Firestore, y el StreamBuilder/Subscription se encarga del resto.
      await _updateProfileImageUrl(downloadUrl);

      // No es necesario llamar a _showSnackBar aquí si _updateProfileImageUrl ya lo hace en éxito/error.
      // Pero si quieres un mensaje específico para la subida, puedes mantenerlo.
      // if (mounted) {
      //   _showSnackBar('Imagen subida. Actualizando perfil...', Colors.green);
      // }
    } catch (e) {
      print("Error al subir imagen de perfil: $e");
      if (mounted) {
        _showSnackBar('Error al subir la imagen: ${e.toString()}', Colors.red);
      }
    }
  }

  // Diálogo para ingresar una URL
  void _showUrlInputDialog() {
    final urlController = TextEditingController(); // Renombrado para evitar conflicto si se usa _
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ingresar URL de imagen"),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(hintText: "https://example.com/imagen.jpg"),
            keyboardType: TextInputType.url,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Guardar"),
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                  Navigator.of(context).pop(); // Cerrar el diálogo primero
                  _updateProfileImageUrl(url);
                } else {
                  _showSnackBar('Por favor, ingresa una URL válida.', Colors.red);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Diálogo para seleccionar un asset local dinámicamente
  Future<void> _showLocalAssetsDialog() async {
    // Asegúrate de que las imágenes estén en tu pubspec.yaml y en la carpeta assets
    // Ejemplo de pubspec.yaml:
    // flutter:
    //   assets:
    //     - assets/images/profile_defaults/ # Si tienes una carpeta
    //     - assets/images/user_avatar1.png
    //     - assets/images/user_avatar2.jpg

    // Lista de assets predefinidos (más simple y seguro que AssetManifest para este caso)
    // Adapta esta lista a tus archivos de assets reales.
    final List<String> localProfileAssets = [
      'assets/images/placeholder.png', // Un placeholder genérico
      // 'assets/images/profile_defaults/avatar1.png',
      // 'assets/images/profile_defaults/avatar2.png',
      // Agrega aquí los paths a tus imágenes de perfil por defecto
    ];

    if (localProfileAssets.isEmpty) {
      _showSnackBar('No hay imágenes locales predefinidas.', Colors.blueGrey);
      return;
    }

    // Alternativamente, si quieres seguir usando AssetManifest.json:
    // try {
    //   final manifestContent = await rootBundle.loadString('AssetManifest.json');
    //   final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    //   final List<String> allAssets = manifestMap.keys.toList();
    //   // Filtra solo los que quieras ofrecer como avatares, ej:
    //   localProfileAssets = allAssets.where((String key) => key.startsWith('assets/images/profile_defaults/')).toList();
    //   if (localProfileAssets.isEmpty) {
    //     _showSnackBar('No se encontraron imágenes de perfil en los assets.', Colors.blueGrey);
    //     return;
    //   }
    // } catch (e) {
    //   print("Error cargando AssetManifest.json: $e");
    //   _showSnackBar('Error al cargar lista de imágenes locales.', Colors.red);
    //   return;
    // }


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Seleccionar imagen de assets"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Para que el Column no se expanda innecesariamente
              children: localProfileAssets.map((path) {
                // Extraer un nombre más legible si es posible
                String displayName = path.split('/').last;
                if (displayName.contains('.')) {
                  displayName = displayName.substring(0, displayName.lastIndexOf('.'));
                }
                displayName = displayName.replaceAll('_', ' ').replaceAll('-', ' ');
                // Capitalizar primera letra
                if (displayName.isNotEmpty) {
                  displayName = displayName[0].toUpperCase() + displayName.substring(1);
                }


                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: AssetImage(path),
                    onBackgroundImageError: (exception, stackTrace) {
                      print('Error cargando asset en diálogo: $path, $exception');
                      // Puedes poner un icono de error aquí en el CircleAvatar si quieres
                    },
                  ),
                  title: Text(displayName),
                  onTap: () {
                    Navigator.of(context).pop(); // Cerrar diálogo primero
                    // Para assets, la 'URL' es simplemente el path del asset.
                    // NetworkImage y Image.asset manejan esto de forma diferente.
                    // Firestore almacenará el path del asset.
                    // Deberás manejar esto en _buildProfileHeader (ya lo haces con NetworkImage vs AssetImage).
                    _updateProfileImageUrl(path);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      },
    );
  }

  // Función unificada para actualizar el campo en Firestore
  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _showSnackBar('No se pudo identificar al usuario para cambiar la foto.', Colors.red);
      return;
    }

    // Antes de actualizar, podrías querer verificar si la URL es de Firebase Storage
    // o un path de asset, para no intentar subir un path de asset a Storage de nuevo.
    // En este caso, imageUrl ya es la URL final o el path del asset.

    if (mounted) _showSnackBar('Actualizando foto de perfil...', Colors.blue);

    try {
      await _firestore.collection('users').doc(firebaseUser.uid).update({'profileImageUrl': imageUrl});
      // El StreamSubscription se encargará de actualizar _currentUser y la UI.
      if (mounted) _showSnackBar('Foto de perfil actualizada.', Colors.green);
    } catch (e) {
      print("Error al actualizar profileImageUrl en Firestore: $e");
      if (mounted) _showSnackBar('Error al actualizar la foto de perfil: ${e.toString()}', Colors.red);
    }
  }
  // --- FIN DE FUNCIONES INTEGRADAS ---

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      // ... (tu código de loading se mantiene igual)
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Caso donde firebaseUser existe pero _currentUser (de Firestore) aún no ha cargado completamente o no existe
    if (_currentUser == null && _auth.currentUser != null) {
      // ... (tu código para este caso se mantiene igual)
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

    // Usuario por defecto si _currentUser es null (ej. no autenticado o error no manejado en _loadUserProfile)
    // O si el documento no existe y no se creó uno temporal en _loadUserProfile.
    final AppUser displayUser = _currentUser ?? AppUser(
        uid: _auth.currentUser?.uid ?? 'guest_fallback', // uid diferente para depuración
        email: _auth.currentUser?.email ?? 'invitado@example.com',
        name: 'Invitado', // Nombre por defecto
        role: 'guest'
    );

    return Scaffold(
      appBar: AppBar(
        // ... (tu AppBar se mantiene igual)
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
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Aquí pasamos el displayUser que ya tiene la información correcta
              _buildProfileHeader(displayUser),
              const SizedBox(height: 24),
              _buildStatsSection(displayUser.experiencesSubmitted),
              const SizedBox(height: 24),
              _buildFavoritesSection(displayUser),
              const SizedBox(height: 24),
              _buildBookingHistorySection(displayUser),
              const SizedBox(height: 24),
              _buildProfileOptions(displayUser),
            ],
          ),
        ),
      ),
    );
  }

// ----- FUNCIÓN MODIFICADA: _buildProfileHeader -----
  Widget _buildProfileHeader(AppUser user) {
    ImageProvider? backgroundImage;
    bool isGuest = _isGuestMode(user);

    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      if (user.profileImageUrl!.startsWith('http://') || user.profileImageUrl!.startsWith('https://')) {
        backgroundImage = NetworkImage(user.profileImageUrl!);
      } else if (user.profileImageUrl!.startsWith('assets/')) {
        backgroundImage = AssetImage(user.profileImageUrl!);
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      // Si tienes una decoración con ancho específico, eso podría afectar.
      // Por ahora, asumimos que el Container se expande o se centra por su padre.
      decoration: BoxDecoration(
        // Ejemplo de decoración, asegúrate que no restrinja el centrado
        // color: Colors.brown.withOpacity(0.1),
        // borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        // ----- MODIFICACIÓN AQUÍ -----
        crossAxisAlignment: CrossAxisAlignment.center, // <--- AÑADE O MODIFICA ESTA LÍNEA
        // ----- FIN DE LA MODIFICACIÓN -----
        children: [
          GestureDetector(
            onTap: (isGuest || _auth.currentUser == null || _auth.currentUser!.uid != user.uid)
                ? null
                : _showImageSourceDialog,
            child: Stack(
              alignment: Alignment.bottomRight, // Esto es para el ícono de editar sobre el avatar
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: backgroundImage,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('Error cargando imagen de perfil. URL/Path: ${user.profileImageUrl}. Error: $exception');
                  },
                  child: (backgroundImage == null)
                      ? (user.name != null && user.name!.isNotEmpty && user.name != "Invitado" && user.name != user.email?.split('@')[0])
                      ? Text(
                    user.name![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                      : Icon(
                      isGuest ? Icons.person_outline : Icons.person,
                      size: 45,
                      color: Theme.of(context).colorScheme.onPrimaryContainer
                  )
                      : null,
                ),
                if (!isGuest && _auth.currentUser != null && _auth.currentUser!.uid == user.uid)
                  Positioned( // Ejemplo de cómo posicionar el ícono de editar
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name ?? (isGuest ? "Invitado" : (user.email.split('@')[0])),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
            textAlign: TextAlign.center, // El texto en sí ya está centrado
          ),
          const SizedBox(height: 6),
          Container( // El contenedor del ROL
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
          if (user.interests.isNotEmpty && !isGuest) ...[
            const SizedBox(height: 16),
            Text('Intereses:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.brown[700])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center, // También centra los ítems del Wrap
              children: user.interests.map((interest) => Chip(
                label: Text(interest),
                backgroundColor: Colors.brown[100],
                labelStyle: TextStyle(color: Colors.brown[800]),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }


  Color _getRoleColor(String role) {
    // ... (tu _getRoleColor se mantiene igual)
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrador':
        return Colors.red.shade700;
      case 'moderator':
      case 'moderador':
        return Colors.blue.shade700;
      case 'user':
      case 'usuario':
      default:
        return const Color(0xFFE67E22);
    }
  }

  Widget _buildStatsSection(int experiencesSubmitted) {
    // ... (tu _buildStatsSection se mantiene igual)
    int communitiesSupported = 3;
    int artisansMet = 12;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: _StatCard(number: experiencesSubmitted.toString(), label: 'Experiencias\nSubidas', icon: Icons.publish_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(number: communitiesSupported.toString(), label: 'Comunidades\nApoyadas', icon: Icons.people_outline)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(number: artisansMet.toString(), label: 'Artesanos\nConocidos', icon: Icons.handshake_outlined)),
      ],
    );
  }

  Widget _buildFavoritesSection(AppUser user) {
    // ... (tu _buildFavoritesSection se mantiene igual)
    if (user.uid == 'guest_fallback' || user.uid == 'guest') {
      return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'Inicia sesión para ver tus favoritos.');
    }

    if (user.savedExperiences.isEmpty) {
      return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'Aún no tienes experiencias guardadas.');
    }

    return FutureBuilder<List<Experience>>(
      key: ValueKey('favorites_${user.savedExperiences.join('_')}'),
      future: _fetchExperiencesByIds(user.savedExperiences),
      builder: (context, experienceSnapshot) {
        if (experienceSnapshot.connectionState == ConnectionState.waiting) {
          return _buildSectionLoadingIndicator('Mis Experiencias Favoritas');
        }
        if (experienceSnapshot.hasError) {
          return _buildSectionError('Mis Experiencias Favoritas', 'Error al cargar: ${experienceSnapshot.error}');
        }
        if (!experienceSnapshot.hasData || experienceSnapshot.data!.isEmpty) {
          return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'No se encontraron experiencias.');
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
              height: 160, // Ajusta según el tamaño de _buildFavoriteCard
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
    // ... (tu _fetchExperiencesByIds se mantiene igual)
    if (ids.isEmpty) return [];
    final querySnapshot = await _firestore.collection('experiences').where(FieldPath.documentId, whereIn: ids).get();
    return querySnapshot.docs.map((doc) => Experience.fromFirestore(doc)).toList();
  }

  Widget _buildBookingHistorySection(AppUser user) {
    // ... (tu _buildBookingHistorySection se mantiene igual)
    if (user.uid == 'guest_fallback' || user.uid == 'guest') {
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
  // ... (código anterior hasta _buildFavoriteCard)

  Widget _buildFavoriteCard(Experience experience) {
    bool isNetworkImage = experience.imageAsset.startsWith('http://') || experience.imageAsset.startsWith('https://');
    bool isLocalAsset = experience.imageAsset.startsWith('assets/');

    ImageProvider favImageProvider;
    if (isNetworkImage) {
      favImageProvider = NetworkImage(experience.imageAsset);
    } else if (isLocalAsset) {
      favImageProvider = AssetImage(experience.imageAsset);
    } else {
      // Fallback si no es ni http ni assets, o si está vacía
      favImageProvider = const AssetImage('assets/images/placeholder.png'); // Asegúrate que este placeholder exista
    }

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
        width: 130,
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
                child: Image(
                  image: favImageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error cargando imagen de favorito: ${experience.imageAsset} - $error");
                    // Fallback visual en caso de error de carga de imagen
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(
                        _getIconForCategory(experience.category), // Usar el icono de categoría como fallback
                        size: 30,
                        color: Theme.of(context).primaryColorDark.withOpacity(0.5),
                      ),
                    );
                  },
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
    bool isNetworkImage = booking.experienceImage.startsWith('http://') || booking.experienceImage.startsWith('https://');
    bool isLocalAsset = booking.experienceImage.startsWith('assets/');

    ImageProvider bookingImageProvider;
    if (isNetworkImage) {
      bookingImageProvider = NetworkImage(booking.experienceImage);
    } else if (isLocalAsset) {
      bookingImageProvider = AssetImage(booking.experienceImage);
    } else {
      bookingImageProvider = const AssetImage('assets/images/placeholder.png'); // Asegúrate que este placeholder exista
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showSnackBar('Detalles de reserva no implementado.', Colors.blueGrey);
          // Podrías navegar a una pantalla de detalle de reserva si la tienes
          // Navigator.push(context, MaterialPageRoute(builder: (context) => BookingDetailScreen(bookingId: booking.id)));
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
                  child: Image(
                    image: bookingImageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print("Error cargando imagen de reserva: ${booking.experienceImage} - $error");
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
      case 'pending':
      case 'pendiente':
        return Colors.orange.shade700;
      case 'confirmed':
      case 'confirmada':
        return Colors.green.shade700;
      case 'cancelled':
      case 'cancelada':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

// ----- FUNCIÓN MODIFICADA: _buildProfileOptions -----
  Widget _buildProfileOptions(AppUser user) { // Acepta AppUser como parámetro
    bool isCurrentlyGuest = _isGuestMode(user);

    if (isCurrentlyGuest) {
      // Opciones para el MODO INVITADO
      return Column(
        children: [
          _buildOptionItem(Icons.login_outlined, 'Iniciar Sesión / Registrarse', () {
            // Navegar a la pantalla de bienvenida/login
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()), // O tu pantalla de login específica
                  (Route<dynamic> route) => false,
            );
          }),
          _buildOptionItem(Icons.policy_outlined, 'Términos y Condiciones', () {
            _showSnackBar('Términos y Condiciones no implementado.', Colors.blueGrey);
            // TODO: Implementar navegación o mostrar diálogo con términos
          }),
          _buildOptionItem(Icons.help_outline_outlined, 'Ayuda y Soporte', () {
            _showSnackBar('Ayuda y soporte no implementado.', Colors.blueGrey);
            // TODO: Implementar navegación a pantalla de ayuda o FAQ
          }),
          // Puedes añadir más opciones relevantes para invitados si es necesario
        ],
      );
    } else {
      // Opciones para el USUARIO AUTENTICADO
      return Column(
        children: [
          _buildOptionItem(Icons.bookmark_border_outlined, 'Experiencias Guardadas', () {
            _showSnackBar('Tus experiencias guardadas se muestran arriba.', Colors.blueGrey);
            // Si tienes una pantalla específica, navega allí:
            // Navigator.push(context, MaterialPageRoute(builder: (context) => SavedExperiencesScreen()));
          }),
          _buildOptionItem(Icons.history_outlined, 'Historial de Reservas', () {
            _showSnackBar('Tu historial de reservas se muestra arriba.', Colors.blueGrey);
            // Si tienes una pantalla específica, navega allí:
            // Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen()));
          }),
          _buildOptionItem(Icons.edit_outlined, 'Editar Perfil', () {
            // Podrías tener una pantalla específica para editar más detalles del perfil
            // o reutilizar _showImageSourceDialog si solo es para la foto.
            // Por ahora, si es solo la foto, el usuario ya puede hacerlo desde el header.
            // Si tienes más campos (nombre, intereses, etc.) para editar:
            // Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)));
            _showSnackBar('Editar perfil no implementado (aparte de la foto).', Colors.blueGrey);
          }),
          _buildOptionItem(Icons.payment_outlined, 'Métodos de Pago', () {
            _showSnackBar('Métodos de pago no implementado.', Colors.blueGrey);
            // Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentMethodsScreen()));
          }),
          _buildOptionItem(Icons.notifications_none_outlined, 'Notificaciones', () {
            _showSnackBar('Configuración de notificaciones no implementado.', Colors.blueGrey);
            // Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationSettingsScreen()));
          }),
          _buildOptionItem(Icons.security_outlined, 'Seguridad de la Cuenta', () {
            _showSnackBar('Seguridad de la cuenta no implementado (ej. cambiar contraseña).', Colors.blueGrey);
            // Navigator.push(context, MaterialPageRoute(builder: (context) => AccountSecurityScreen()));
          }),
          _buildOptionItem(Icons.help_outline_outlined, 'Ayuda y Soporte', () {
            _showSnackBar('Ayuda y soporte no implementado.', Colors.blueGrey);
          }),
          _buildOptionItem(Icons.privacy_tip_outlined, 'Privacidad y Términos', () {
            _showSnackBar('Privacidad y Términos no implementado.', Colors.blueGrey);
          }),
          const SizedBox(height: 10),
          _buildOptionItem(Icons.logout_outlined, 'Cerrar Sesión', _signOut, isDestructive: true),
        ],
      );
    }
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Para el efecto ripple
      ),
    );
  }

  Widget _buildSectionPlaceholder(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
        ),
        const SizedBox(height: 16),
        Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
            )
        ),
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
        Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Text(errorMessage, style: TextStyle(color: Colors.red[700], fontSize: 14), textAlign: TextAlign.center),
            )
        ),
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
    super.key, // Añadido super.key
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
