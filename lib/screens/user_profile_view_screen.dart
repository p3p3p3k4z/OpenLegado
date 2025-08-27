// lib/screens/user_profile_view_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart'; // Asegúrate que la ruta a tu modelo AppUser sea correcta

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  const UserProfileViewScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileViewScreenState createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  AppUser? _userToDisplay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (docSnapshot.exists && mounted) {
        setState(() {
          // Asumiendo que AppUser.fromFirestore ya maneja bio y galleryImageUrls
          _userToDisplay = AppUser.fromFirestore(docSnapshot);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
        print('Documento de usuario no encontrado para ID: ${widget.userId}');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error al obtener datos del perfil del usuario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el perfil.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userToDisplay?.username ?? 'Perfil de Usuario'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF8B4513)),
        titleTextStyle: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold, fontSize: 18),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userToDisplay == null
          ? const Center(child: Text('Usuario no encontrado o error al cargar.'))
          : _buildUserProfileContent(_userToDisplay!),
    );
  }

  Widget _buildUserProfileContent(AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUserProfileHeader(user), // Muestra foto, nombre, rol, intereses
          const SizedBox(height: 24),

          // --- SECCIÓN DE BIOGRAFÍA ---
          _buildUserBioSection(user),
          // Añadir espacio si la biografía es visible
          if (user.bio != null && user.bio!.trim().isNotEmpty)
            const SizedBox(height: 24),

          // --- SECCIÓN DE GALERÍA (solo para roles relevantes) ---
          _buildUserGallerySection(user),
          // Añadir espacio si la galería es visible
          if ((user.role.toLowerCase() == 'creator' || user.role.toLowerCase() == 'artisan') && user.galleryImageUrls.isNotEmpty)
            const SizedBox(height: 24),

          // Puedes añadir aquí otras secciones públicas, como:
          // - Lista de experiencias creadas por este usuario (si aplica y tienes cómo obtenerlas)
          // - Reseñas dejadas por este usuario (si es una funcionalidad)
        ],
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCCIÓN (Header, Bio, Gallery) ---
  // Estos deberían ser los mismos que te proporcioné antes para UserProfileViewScreen.
  // Solo me aseguro de que estén completos aquí.

  Widget _buildUserProfileHeader(AppUser user) {
    ImageProvider? backgroundImage;
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      if (user.profileImageUrl!.startsWith('http')) {
        backgroundImage = NetworkImage(user.profileImageUrl!);
      } else if (user.profileImageUrl!.startsWith('assets/')) {
        backgroundImage = AssetImage(user.profileImageUrl!);
      } else {
        backgroundImage = const AssetImage('assets/images/default_avatar.png');
      }
    } else {
      backgroundImage = const AssetImage('assets/images/default_avatar.png');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 4)) ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            backgroundImage: backgroundImage,
            onBackgroundImageError: backgroundImage is NetworkImage // Solo para NetworkImage
                ? (exception, stackTrace) {
              print('Error cargando backgroundImage en CircleAvatar (View). URL: ${user.profileImageUrl}. Error: $exception');
            }
                : null,
            child: (backgroundImage is AssetImage && (backgroundImage as AssetImage).assetName == 'assets/images/default_avatar.png' || backgroundImage == null) && (user.username != null && user.username!.isNotEmpty)
                ? Text(user.username![0].toUpperCase(), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))
                : ((backgroundImage is AssetImage && (backgroundImage as AssetImage).assetName == 'assets/images/default_avatar.png' || backgroundImage == null)
                ? Icon(Icons.account_circle, size: 50, color: Theme.of(context).colorScheme.primary)
                : null),
          ),
          const SizedBox(height: 16),
          Text(
            user.username ?? "Usuario",
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
          if (user.interests.isNotEmpty) ...[ // Mostrar intereses si es público
            const SizedBox(height: 16),
            Text('Intereses:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.brown[700])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 4.0, alignment: WrapAlignment.center,
              children: user.interests.map((interest) => Chip(
                label: Text(interest),
                backgroundColor: Colors.brown[100],
                labelStyle: TextStyle(color: Colors.brown[800], fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserBioSection(AppUser user) {
    if (user.bio == null || user.bio!.trim().isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay bio
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sobre mí', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.08), spreadRadius: 1, blurRadius: 5, offset: Offset(0, 2)) ],
          ),
          child: Text(user.bio!, style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]), textAlign: TextAlign.justify),
        ),
      ],
    );
  }

  Widget _buildUserGallerySection(AppUser user) {
    // AJUSTA EL ROL AQUÍ SEGÚN QUIÉNES DEBEN MOSTRAR GALERÍA
    // Por ejemplo, solo 'creator' o 'artisan'
    if (!(user.role.toLowerCase() == 'creator' || user.role.toLowerCase() == 'artisan') || user.galleryImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Galería de Muestra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
        const SizedBox(height: 12),
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
                imageProvider = const AssetImage('assets/images/placeholder.png'); // Asegúrate que este asset exista
              }

              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 160,
                    height: 160,
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
                        print("Error cargando imagen de galería (View): $imageUrlOrPath, $error");
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

  // --- FUNCIONES DE AYUDA (copiadas de tu ProfileScreen o similares) ---
  String _getRoleDisplayName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'admin': return 'ADMINISTRADOR';
      case 'moderator': return 'MODERADOR';
      case 'creator': return 'CREADOR'; // O 'Anfitrión', 'Artesano'
      case 'user': return 'USUARIO';
      default: return roleKey.toUpperCase();
    }
  }

  Color _getRoleColor(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'admin': return Colors.red.shade700;
      case 'moderator': return Colors.blue.shade700;
      case 'creator': return Colors.teal.shade600; // O el color que uses para anfitriones/artesanos
      case 'user': return const Color(0xFFE67E22);
      default: return Colors.grey.shade600;
    }
  }
}
