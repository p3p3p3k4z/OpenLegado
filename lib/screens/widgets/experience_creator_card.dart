// lib/widgets/experience_creator_card.dart
import 'package:flutter/material.dart';
import '../../models/user.dart'; // Asegúrate que la ruta a tu modelo AppUser sea correcta
import '../../screens/user_profile_view_screen.dart'; // Importar la nueva pantalla de visualización

class ExperienceCreatorInfoCard extends StatelessWidget {
  final AppUser? creator;
  final bool isLoading;

  const ExperienceCreatorInfoCard({
    Key? key,
    required this.creator,
    this.isLoading = false,
  }) : super(key: key);

  String _getRoleDisplayName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'admin': return 'ADMINISTRADOR';
      case 'moderator': return 'MODERADOR';
      case 'creator': return 'CREADOR';
      case 'user': return 'USUARIO';
    // No deberías ver 'guest' aquí si la navegación es correcta
      default: return roleKey.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (creator == null) {
      return const SizedBox.shrink();
      // Alternativa si quieres mostrar un mensaje:
      // return Padding(
      //   padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      //   child: Text(
      //     'Información del anfitrión no disponible.',
      //     style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
      //   ),
      // );
    }

    ImageProvider creatorImageProvider;
    if (creator!.profileImageUrl != null && creator!.profileImageUrl!.isNotEmpty) {
      if (creator!.profileImageUrl!.startsWith('http')) {
        creatorImageProvider = NetworkImage(creator!.profileImageUrl!);
      } else if (creator!.profileImageUrl!.startsWith('assets/')) {
        creatorImageProvider = AssetImage(creator!.profileImageUrl!);
      } else {
        // Fallback si el path/URL no es reconocido o es una cadena inesperada
        print("Advertencia: Formato de profileImageUrl no reconocido para el creador: ${creator!.profileImageUrl}");
        creatorImageProvider = const AssetImage('assets/images/default_avatar.png'); // Asegúrate que este asset exista
      }
    } else {
      // Fallback si no hay profileImageUrl
      creatorImageProvider = const AssetImage('assets/images/default_avatar.png'); // Asegúrate que este asset exista
    }

    String sectionTitle = "Creado por";
    // Ajusta el rol según tu lógica para anfitriones/creadores
    if (creator!.role.toLowerCase() == 'artisan' || creator!.role.toLowerCase() == 'creator') {
      sectionTitle = "Anfitrión";
    }


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Padding para la tarjeta en la pantalla
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileViewScreen(userId: creator!.uid), // PASANDO EL UID DEL CREADOR
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Padding interno de la tarjeta
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30, // Tamaño del avatar
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  backgroundImage: creatorImageProvider,
                  onBackgroundImageError: (exception, stackTrace) {
                    // Este error se logueará si NetworkImage o AssetImage fallan.
                    // El CircleAvatar intentará mostrar su child si la imagen de fondo falla.
                    print('Error cargando imagen de perfil en ExperienceCreatorInfoCard: ${creator!.profileImageUrl}. Error: $exception');
                  },
                  // Child se muestra si backgroundImage es null o falla la carga
                  child: (creator!.profileImageUrl == null || creator!.profileImageUrl!.isEmpty || creatorImageProvider is AssetImage && (creatorImageProvider as AssetImage).assetName == 'assets/images/default_avatar.png')
                      ? Text(
                      creator!.username != null && creator!.username!.isNotEmpty
                          ? creator!.username![0].toUpperCase()
                          : '?', // Fallback para la inicial si no hay username
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)
                  )
                      : null, // No muestra child si backgroundImage está presente y se espera que cargue
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator!.username ?? "Anfitrión Desconocido", // Fallback si el username es null
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037) // Un color temático
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // Muestra el rol de forma más amigable
                        _getRoleDisplayName(creator!.role),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700], // Un color más sutil para el rol
                        ),
                      ),
                      // --- AÑADIDO OPCIONAL: Snippet de la Biografía ---
                      if (creator!.bio != null && creator!.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          creator!.bio!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2, // Mostrar solo 2 líneas
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // --- FIN DE AÑADIDO OPCIONAL ---
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey[600]), // Icono de "ir a"
              ],
            ),
          ),
        ),
      ),
    );
  }
}
