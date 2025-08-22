import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';

import 'welcome_screen.dart';
import '../models/user.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';
import './edit_profile_screen.dart';

// Clase Booking (sin cambios respecto a tu original)
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  static const String _guestUid = 'guest_mode_uid';
  static const String _defaultGuestProfileImage = 'assets/images/default_avatar_guest.png'; // Asegúrate que este asset exista

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
          // MODIFICADO: Se utiliza el constructor de AppUser que ya tiene los defaults
          // para communitiesSupported y artisansMet.
          _currentUser = AppUser(
            uid: _guestUid,
            email: 'invitado@example.com',
            username: 'Invitado',
            role: 'guest',
            profileImageUrl: _defaultGuestProfileImage,
            // interests y savedExperiences serán listas vacías por defecto.
            // experiencesSubmitted, communitiesSupported, artisansMet serán 0 por defecto.
          );
          _isLoadingProfile = false;
        });
        print("Perfil: Modo Invitado (no auth). UID: ${_currentUser?.uid}, Rol: ${_currentUser?.role}");
      }
      return;
    }

    if (mounted) setState(() => _isLoadingProfile = true);

    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          try {
            // AppUser.fromFirestore ya maneja los nuevos campos y sus defaults si faltan.
            final user = AppUser.fromFirestore(snapshot);
            setState(() {
              _currentUser = user;
              _isLoadingProfile = false;
            });
            print("Perfil: Usuario '${_currentUser?.username}' (Rol: ${_currentUser?.role}) cargado desde Firestore.");
          } catch (e) {
            print("Error al deserializar AppUser.fromFirestore: $e. Data: ${snapshot.data()}");
            _showSnackBar('Error al procesar datos del perfil.', Colors.red);
            setState(() {
              _isLoadingProfile = false;
              // MODIFICADO: Fallback en caso de error de deserialización, usa constructor con defaults.
              _currentUser = AppUser(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? 'Error de datos',
                username: 'Error de datos',
                role: 'user', // Rol por defecto
              );
            });
          }
        } else {
          print("Perfil: Documento de usuario no encontrado para ${firebaseUser.uid}. Creando perfil temporal con rol 'user'.");
          setState(() {
            // MODIFICADO: Perfil temporal para usuario sin documento en Firestore.
            // AppUser constructor se encarga de los defaults para los nuevos campos.
            _currentUser = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? 'No disponible',
              username: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Usuario Nuevo',
              role: 'user', // Rol por defecto para nuevos usuarios sin perfil en Firestore
              // Los demás campos (interests, savedExperiences, experiencesSubmitted,
              // communitiesSupported, artisansMet) usarán los defaults de AppUser.
            );
            _isLoadingProfile = false;
            // Opcional: Crear el documento en Firestore si es un nuevo registro
            // if (_currentUser != null) {
            //   _firestore.collection('users').doc(firebaseUser.uid)
            //     .set(_currentUser!.toMap(forCreation: true)) // forCreation maneja createdAt
            //     .then((_) => print("Perfil base creado en Firestore para ${firebaseUser.uid}"))
            //     .catchError((e) => print("Error al crear perfil base en Firestore: $e"));
            // }
          });
        }
      }
    }, onError: (error) {
      print('Error al cargar perfil de usuario (stream): $error');
      if (mounted) {
        _showSnackBar('Error al cargar perfil: ${error.toString()}', Colors.red);
        setState(() {
          _isLoadingProfile = false;
          // MODIFICADO: Fallback en caso de error de stream, usa constructor con defaults.
          _currentUser = AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? 'Error',
            username: 'Error al cargar',
            role: 'user',
          );
        });
      }
    });
  }

  Future<void> _signOut() async {
    try {
      await _userSubscription?.cancel();
      _userSubscription = null;
      await _auth.signOut();

      if (mounted) {
        _showSnackBar('Sesión cerrada exitosamente.', Colors.green);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnackBar('Error al cerrar sesión: ${e.message}', Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
    }
  }

  bool _isGuestMode(AppUser? user) {
    return user?.uid == _guestUid || user?.role == 'guest';
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

  void _showImageSourceDialog() {
    if (_isGuestMode(_currentUser)) return;

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

  Future<void> _uploadImageFromGallery() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || _isGuestMode(_currentUser)) {
      _showSnackBar('Acción no permitida.', Colors.red);
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
        uploadTask = storageRef.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        File imageFile = File(image.path);
        uploadTask = storageRef.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      await _updateProfileImageUrl(downloadUrl);
    } catch (e) {
      print("Error al subir imagen de perfil: $e");
      if (mounted) _showSnackBar('Error al subir la imagen: ${e.toString()}', Colors.red);
    }
  }

  void _showUrlInputDialog() {
    if (_isGuestMode(_currentUser)) return;
    final urlController = TextEditingController();
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
                  Navigator.of(context).pop();
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

  Future<void> _showLocalAssetsDialog() async {
    if (_isGuestMode(_currentUser)) return;
    final List<String> localProfileAssets = [
      'assets/images/avatars/avatar1.png', // Asegúrate que estos archivos existan y estén en pubspec.yaml
      'assets/images/avatars/avatar2.png',
      'assets/images/avatars/avatar3.png',
      'assets/images/placeholder.png',
      _defaultGuestProfileImage, // Puedes incluir el de invitado si quieres
    ];

    if (localProfileAssets.isEmpty) {
      _showSnackBar('No hay imágenes locales predefinidas.', Colors.blueGrey);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Seleccionar imagen de assets"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: localProfileAssets.map((path) {
                String displayName = path.split('/').last;
                if (displayName.contains('.')) displayName = displayName.substring(0, displayName.lastIndexOf('.'));
                displayName = displayName.replaceAll('_', ' ').replaceAll('-', ' ');
                if (displayName.isNotEmpty) displayName = displayName[0].toUpperCase() + displayName.substring(1);
                else displayName = "Imagen Local";

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: AssetImage(path),
                    onBackgroundImageError: (e,s) => print("Error asset en dialogo: $path, $e"),
                  ),
                  title: Text(displayName),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateProfileImageUrl(path);
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || _isGuestMode(_currentUser)) {
      _showSnackBar('Actualización no permitida.', Colors.red);
      return;
    }

    if (mounted) _showSnackBar('Actualizando foto de perfil...', Colors.blue);
    try {
      await _firestore.collection('users').doc(firebaseUser.uid).update({'profileImageUrl': imageUrl});
      if (mounted) {
        _showSnackBar('Foto de perfil actualizada.', Colors.green);
        // El stream de _loadUserProfile debería actualizar _currentUser y la UI.
      }
    } catch (e) {
      print("Error al actualizar profileImageUrl en Firestore: $e");
      if (mounted) _showSnackBar('Error al actualizar la foto: ${e.toString()}', Colors.red);
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null && _isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(title: Text('Mi perfil', style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // MODIFICADO: displayUser siempre tendrá un valor, usando _currentUser si no es null,
    // o un AppUser de invitado si _currentUser es null (lo cual sucede si _loadUserProfile
    // lo establece a invitado o si hay un error no manejado que lo deja null).
    // El constructor de AppUser se encarga de los defaults para los nuevos campos.
    final AppUser displayUser = _currentUser ?? AppUser(
        uid: _auth.currentUser?.uid ?? _guestUid,
        email: _auth.currentUser?.email ?? 'invitado@example.com',
        username: 'Invitado',
        role: 'guest',
        profileImageUrl: _defaultGuestProfileImage
      // communitiesSupported y artisansMet serán 0 por defecto desde el constructor de AppUser.
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil', style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isGuestMode(displayUser))
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFFE67E22)),
              onPressed: () {
                _showSnackBar('Pantalla de configuración no implementada.', Colors.blueGrey);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadUserProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(displayUser), // Tu cabecera existente
              const SizedBox(height: 24),

              // --- AÑADIDO: Sección de Biografía ---
              _buildBioSection(displayUser),
              // Añadir un SizedBox si ambos (bio y stats) son visibles y quieres espacio
              if (displayUser.bio != null && displayUser.bio!.trim().isNotEmpty)
                const SizedBox(height: 24),


              if (!_isGuestMode(displayUser)) ...[
                _buildStatsSection(displayUser),
                const SizedBox(height: 24),
              ],

              // --- AÑADIDO: Sección de Galería ---
              // (Ajusta la condición de 'role' en _buildGallerySection según tus necesidades)
              _buildGallerySection(displayUser),
              // Añadir un SizedBox si la galería es visible y quieres espacio antes de favoritos
              if ((displayUser.role.toLowerCase() == 'artisan' || displayUser.role.toLowerCase() == 'creator') && displayUser.galleryImageUrls.isNotEmpty)
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

  Widget _buildProfileHeader(AppUser user) {
    ImageProvider? backgroundImage;
    bool isActuallyGuest = _isGuestMode(user);

    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      if (user.profileImageUrl!.startsWith('http')) {
        backgroundImage = NetworkImage(user.profileImageUrl!);
      } else if (user.profileImageUrl!.startsWith('assets/')) {
        backgroundImage = AssetImage(user.profileImageUrl!);
      }
    }
    // Si backgroundImage sigue siendo null aquí, es porque no hay URL/path válido
    // o profileImageUrl era null/vacío.

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: (isActuallyGuest) ? null : _showImageSourceDialog,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  backgroundImage: backgroundImage, // Puede ser null
                  // MODIFICADO: Solo pasa onBackgroundImageError si backgroundImage NO es null
                  onBackgroundImageError: backgroundImage != null
                      ? (exception, stackTrace) {
                    print(
                        'Error cargando backgroundImage en CircleAvatar. URL/Path: ${user.profileImageUrl}. Error: $exception');
                    // El CircleAvatar intentará mostrar su 'child' automáticamente en caso de error.
                    // Si necesitas forzar una actualización de estado aquí para cambiar 'backgroundImage' a null
                    // y mostrar el child explícitamente, podrías hacerlo, pero usualmente no es necesario
                    // ya que el widget maneja la falla internamente para mostrar el child.
                    // Ejemplo: if (mounted) setState(() { /* Lógica para limpiar la imagen si falla */ });
                  }
                      : null, // Si backgroundImage es null, onBackgroundImageError DEBE SER NULL
                  child: (backgroundImage == null) // El child se muestra si no hay imagen inicial o si falla la carga de backgroundImage
                      ? (user.username != null &&
                      user.username!.isNotEmpty &&
                      !_isGuestMode(user) &&
                      user.username!.toLowerCase() != "invitado" && // Evita iniciales para "Invitado"
                      user.username != user.email?.split('@').first) // Evita iniciales si el username es solo el email
                      ? Text(
                    user.username![0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                  )
                      : Icon(
                      isActuallyGuest ? Icons.account_circle_outlined : Icons.account_circle,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary)
                      : null, // No muestra child si backgroundImage está presente (incluso si luego falla y onBackgroundImageError se activa, el child se gestiona internamente)
                ),
                if (!isActuallyGuest)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5)),
                      child: const Icon(Icons.edit, size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.username ?? (isActuallyGuest ? "Invitado" : (user.email?.split('@').first ?? "Usuario")),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          if (user.role.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRoleDisplayName(user.role),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          if (user.interests.isNotEmpty && !isActuallyGuest) ...[
            const SizedBox(height: 16),
            Text('Intereses:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.brown[700])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: user.interests
                  .map((interest) => Chip(
                label: Text(interest),
                backgroundColor: Colors.brown[100],
                labelStyle: TextStyle(color: Colors.brown[800], fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }


  String _getRoleDisplayName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'admin': return 'ADMINISTRADOR';
      case 'moderator': return 'MODERADOR';
      case 'creator': return 'CREADOR';
      case 'user': return 'USUARIO';
      case 'guest': return 'INVITADO';
      default: return roleKey.toUpperCase();
    }
  }

  Color _getRoleColor(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'admin': return Colors.red.shade700;
      case 'moderator': return Colors.blue.shade700;
      case 'creator': return Colors.teal.shade600;
      case 'user': return const Color(0xFFE67E22);
      case 'guest':
      default: return Colors.grey.shade600;
    }
  }

// NUEVO WIDGET: Para mostrar la biografía
  Widget _buildBioSection(AppUser user) {
    // Solo mostrar si la bio existe y no está vacía
    if (user.bio == null || user.bio!.trim().isEmpty) {
      // Si eres el dueño del perfil y no es modo invitado, podrías mostrar un placeholder para editar
      if (!_isGuestMode(user) && user.uid == _auth.currentUser?.uid) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sobre mí',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () {
                  // TODO: Navegar a la pantalla de Editar Perfil, sección biografía
                  _showSnackBar('Editar biografía (no implementado).', Colors.blueGrey);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_outlined, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text('Añade una breve descripción sobre ti', style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return SizedBox.shrink(); // No mostrar nada si no hay bio y no es el perfil propio
    }

    // Si hay bio, mostrarla
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sobre mí',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white, // O un color de fondo sutil
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Text(
            user.bio!,
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
            textAlign: TextAlign.justify, // O TextAlign.start
          ),
        ),
      ],
    );
  }

// NUEVO WIDGET: Para mostrar la galería de imágenes de muestra
  Widget _buildGallerySection(AppUser user) {
    // Solo mostrar para roles específicos (ej. 'artisan') y si hay imágenes
    // AJUSTA EL ROL SEGÚN TU LÓGICA ('creator', 'artisan', etc.)
    if (user.role.toLowerCase() != 'artisan' && user.role.toLowerCase() != 'creator') {
      return SizedBox.shrink(); // No mostrar para usuarios normales o invitados (a menos que quieras)
    }

    if (user.galleryImageUrls.isEmpty) {
      // Si es el perfil del artesano y no hay imágenes, mostrar un placeholder para añadir
      if (!_isGuestMode(user) && user.uid == _auth.currentUser?.uid) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi Galería de Muestra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () {
                  // TODO: Navegar a la pantalla de Editar Perfil, sección galería
                  _showSnackBar('Editar galería (no implementado).', Colors.blueGrey);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text('Añade imágenes de muestra de tu trabajo', style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return SizedBox.shrink(); // No mostrar si no es artesano o no hay imágenes y no es el perfil propio
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mi Galería de Muestra',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513)),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 160, // Ajusta la altura según necesites
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: user.galleryImageUrls.length,
            itemBuilder: (context, index) {
              String imageUrlOrPath = user.galleryImageUrls[index];
              ImageProvider imageProvider;

              if (imageUrlOrPath.startsWith('http')) {
                imageProvider = NetworkImage(imageUrlOrPath);
              } else if (imageUrlOrPath.startsWith('assets/')) {
                imageProvider = AssetImage(imageUrlOrPath);
              } else {
                // Placeholder si la URL/path no es reconocido (o añade una imagen de error por defecto)
                imageProvider = AssetImage('assets/images/placeholder.png'); // Asegúrate que este asset exista
              }

              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Card( // Envuelve en una Card para un mejor efecto visual
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias, // Importante para que el ClipRRect dentro funcione bien con la Card
                  child: SizedBox( // SizedBox para forzar dimensiones si la imagen es pequeña
                    width: 160, // Ancho de cada item de la galería
                    height: 160, // Alto de cada item de la galería
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print("Error cargando imagen de galería: $imageUrlOrPath, $error");
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey[400]),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // _buildStatsSection ya usa los campos del modelo AppUser que vienen con defaults.
  // No se necesitan cambios aquí si AppUser está bien definido.
  Widget _buildStatsSection(AppUser user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(child: _StatCard(number: user.experiencesSubmitted.toString(), label: 'Experiencias\nSubidas', icon: Icons.publish_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(number: user.communitiesSupported.toString(), label: 'Comunidades\nApoyadas', icon: Icons.people_outline)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(number: user.artisansMet.toString(), label: 'Artesanos\nConocidos', icon: Icons.handshake_outlined)),
      ],
    );
  }

  Widget _buildFavoritesSection(AppUser user) {
    if (_isGuestMode(user)) {
      return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'Inicia sesión para ver tus favoritos.');
    }
    if (user.savedExperiences.isEmpty) {
      return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'Aún no tienes experiencias guardadas.');
    }
    return FutureBuilder<List<Experience>>(
      key: ValueKey('favorites_${user.uid}_${user.savedExperiences.join('_')}'),
      future: _fetchExperiencesByIds(user.savedExperiences),
      builder: (context, experienceSnapshot) {
        if (experienceSnapshot.connectionState == ConnectionState.waiting) {
          return _buildSectionLoadingIndicator('Mis Experiencias Favoritas');
        }
        if (experienceSnapshot.hasError) {
          print("Error en FutureBuilder (Favoritos): ${experienceSnapshot.error}");
          return _buildSectionError('Mis Experiencias Favoritas', 'Error al cargar favoritos.');
        }
        if (!experienceSnapshot.hasData || experienceSnapshot.data!.isEmpty) {
          return _buildSectionPlaceholder('Mis Experiencias Favoritas', 'No se encontraron tus experiencias favoritas.');
        }
        final favoriteExperiences = experienceSnapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Experiencias Favoritas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: favoriteExperiences.length,
                itemBuilder: (context, index) => _buildFavoriteCard(favoriteExperiences[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Experience>> _fetchExperiencesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    List<Experience> experiences = [];
    List<List<String>> chunks = [];
    for (int i = 0; i < ids.length; i += 10) { // Firestore 'in' query limit
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    for (var chunk in chunks) {
      if (chunk.isNotEmpty) {
        try {
          final querySnapshot = await _firestore.collection('experiences').where(FieldPath.documentId, whereIn: chunk).get();
          experiences.addAll(querySnapshot.docs.where((doc) => doc.exists).map((doc) => Experience.fromFirestore(doc)));
        } catch (e) {
          print("Error fetching experiences chunk: $e");
        }
      }
    }
    return experiences;
  }

  Widget _buildBookingHistorySection(AppUser user) {
    if (_isGuestMode(user)) {
      return _buildSectionPlaceholder('Historial de Reservas', 'Inicia sesión para ver tu historial.');
    }
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('bookingDate', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildSectionLoadingIndicator('Historial de Reservas');
        }
        if (snapshot.hasError) {
          print("Error en StreamBuilder (Reservas): ${snapshot.error}");
          return _buildSectionError('Historial de Reservas', 'Error al cargar historial.');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionPlaceholder('Historial de Reservas', 'Aún no tienes reservas.');
        }
        final bookings = snapshot.data!.docs.map((doc) => Booking.fromFirestore(doc)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Últimas Reservas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
            ),
            if (bookings.length >= 5)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: TextButton(
                    onPressed: () => _showSnackBar('Ver todas las reservas no implementado.', Colors.blueGrey),
                    child: const Text('Ver todas mis reservas', style: TextStyle(color: Color(0xFFE67E22), fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFavoriteCard(Experience experience) {
    ImageProvider favImageProvider;
    if (experience.imageAsset.startsWith('http')) favImageProvider = NetworkImage(experience.imageAsset);
    else if (experience.imageAsset.startsWith('assets/')) favImageProvider = AssetImage(experience.imageAsset);
    else favImageProvider = const AssetImage('assets/images/placeholder.png');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExperienceDetailScreen(experience: experience))),
      child: Container(
        width: 140, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: Image(image: favImageProvider, fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(color: Colors.grey[200], child: Icon(_getIconForCategory(experience.category), size: 40, color: Theme.of(context).primaryColorDark.withOpacity(0.3))))),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(experience.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.start, children: [ Icon(Icons.star, size: 14, color: Colors.amber.shade700), const SizedBox(width: 2), Text(experience.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)))]),
              ]))),
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
      case 'naturaleza y aventura': return Icons.hiking_outlined;
      case 'talleres y aprendizaje': return Icons.school_outlined;
      case 'eventos y festivales': return Icons.celebration_outlined;
      default: return Icons.category_outlined;
    }
  }

  Widget _buildBookingCard(Booking booking) {
    ImageProvider bookImageProvider;
    if (booking.experienceImage.startsWith('http')) bookImageProvider = NetworkImage(booking.experienceImage);
    else if (booking.experienceImage.startsWith('assets/')) bookImageProvider = AssetImage(booking.experienceImage);
    else bookImageProvider = const AssetImage('assets/images/placeholder.png');

    return Card(
        elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
            leading: ClipRRect( borderRadius: BorderRadius.circular(8),
              child: Image( image: bookImageProvider, width: 50, height: 50, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 24)),
              ),),
          title: Text(booking.experienceTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5D4037))),
          subtitle: Text(
            'Fecha: ${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}\n'
                'Personas: ${booking.numberOfPeople} - Estado: ${booking.status.toUpperCase()}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.brown[300]),
          onTap: () {
            // TODO: Navegar a los detalles de la reserva si es necesario.
            _showSnackBar('Detalles de reserva para "${booking.experienceTitle}" (no implementado).', Colors.blueGrey);
          },
        ),
    );
  }

  Widget _buildProfileOptions(AppUser user) {
    bool isActuallyGuest = _isGuestMode(user);
    final firebaseUser = _auth.currentUser;
    bool isViewingOwnProfile = (firebaseUser != null && user.uid == firebaseUser.uid && !isActuallyGuest);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 4), ) ],
      ),
      child: Column(
        children: [
          if (isViewingOwnProfile) ...[ // Solo mostrar si es el perfil propio y no es invitado
            _ProfileOptionTile(
              title: 'Editar Perfil',
              icon: Icons.edit_outlined, // Cambiado el icono para más claridad
              onTap: () {
                // Asegurarnos de que _currentUser (que es 'user' aquí) no sea null
                // y que tengamos los datos cargados antes de navegar.
                if (_currentUser != null) {
                  Navigator.push<bool>( // Especificamos <bool> porque esperamos un booleano de EditProfileScreen
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        currentUserData: _currentUser!, // Pasamos los datos actuales del usuario
                      ),
                    ),
                  ).then((changesWereSaved) {
                    // EditProfileScreen devolverá true si se guardaron cambios.
                    // El StreamSubscription (_userSubscription) debería actualizar la UI automáticamente
                    // cuando los datos en Firestore cambian.
                    // Así que una llamada a _loadUserProfile() podría no ser estrictamente necesaria aquí,
                    // pero no está de más si quieres forzar una recarga o mostrar un feedback inmediato.
                    if (changesWereSaved == true && mounted) {
                      // Opcional: _loadUserProfile(); // Descomentar si notas que la UI no se refresca sola
                      _showSnackBar('Perfil actualizado. Los cambios se reflejarán en breve.', Colors.green);
                    }
                  });
                } else {
                  // Esto no debería suceder si isViewingOwnProfile es true y _currentUser está cargado.
                  _showSnackBar('No se pueden cargar los datos para editar el perfil.', Colors.orange);
                }
              },
              iconColor: Colors.blueAccent.shade700,
            ),
            const Divider(height: 1, indent: 50),
            _ProfileOptionTile(
              title: 'Notificaciones',
              icon: Icons.notifications_none_outlined,
              onTap: () => _showSnackBar('Configuración de notificaciones (no implementado).', Colors.blueGrey),
              iconColor: Colors.orangeAccent.shade700,
            ),
            const Divider(height: 1, indent: 50),
          ],
          _ProfileOptionTile(
            title: 'Ayuda y Soporte',
            icon: Icons.help_outline_outlined,
            onTap: () => _showSnackBar('Ayuda y soporte (no implementado).', Colors.blueGrey),
            iconColor: Colors.green.shade600,
          ),
          const Divider(height: 1, indent: 50),
          _ProfileOptionTile(
            title: 'Términos y Condiciones',
            icon: Icons.description_outlined,
            onTap: () => _showSnackBar('Términos y condiciones (no implementado).', Colors.blueGrey),
            iconColor: Colors.grey.shade600,
          ),
          if (!isActuallyGuest) ...[
            const Divider(height: 1, indent: 50),
            _ProfileOptionTile(
              title: 'Cerrar Sesión',
              icon: Icons.logout_outlined,
              onTap: _signOut, // Ya implementado
              iconColor: Colors.redAccent.shade400,
              textColor: Colors.redAccent.shade400,
            ),
          ] else ...[
            const Divider(height: 1, indent: 50),
            _ProfileOptionTile(
              title: 'Iniciar Sesión / Registrarse',
              icon: Icons.login_outlined,
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()), // O tu pantalla de login/registro
                      (Route<dynamic> route) => false,
                );
              },
              iconColor: Theme.of(context).primaryColor,
              textColor: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  // Widgets auxiliares para la UI (placeholders, loading, error, stat card, option tile)

  Widget _buildSectionPlaceholder(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!)
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 40, color: Colors.grey[500]),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 15)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLoadingIndicator(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildSectionError(String title, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red[200]!)
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red[700]),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 15)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String number;
  final String label;
  final IconData icon;

  const _StatCard({required this.number, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), // Más padding vertical
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15), // Color más sutil
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary), // Icono más grande
          const SizedBox(height: 8),
          Text(
            number,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), // Color más suave
          ),
        ],
      ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileOptionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title, style: TextStyle(color: textColor ?? Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Ajustar padding
    );
  }
}


