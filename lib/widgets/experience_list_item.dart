import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear fechas si es necesario
import '../models/experience.dart'; // Ajusta la ruta a tu modelo
import '../screens/submit_experience_screen.dart'; // Para la navegación a edición

// Enum para definir las acciones disponibles para un item de experiencia
enum ExperienceAction { edit, delete, approve, reject, feature, unfeature, viewDetails }

class ExperienceListItem extends StatelessWidget {
  final Experience experience;
  final String currentUserRole; // 'creator', 'moderator', 'admin'
  final String? currentUserId; // Necesario para el creador
  final Function(ExperienceAction, Experience) onAction;

  const ExperienceListItem({
    super.key,
    required this.experience,
    required this.currentUserRole,
    this.currentUserId,
    required this.onAction,
  });

  String _getStatusText(ExperienceStatus status) {
    switch (status) {
      case ExperienceStatus.pending:
        return 'Pendiente';
      case ExperienceStatus.approved:
        return 'Aprobada';
      case ExperienceStatus.rejected:
        return 'Rechazada';
      default:
        return 'Desconocido';
    }
  }

  Color _getStatusColor(ExperienceStatus status) {
    switch (status) {
      case ExperienceStatus.pending:
        return Colors.orangeAccent;
      case ExperienceStatus.approved:
        return Colors.green;
      case ExperienceStatus.rejected:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = (currentUserRole == 'admin' ||
        currentUserRole == 'moderator' ||
        (currentUserRole == 'creator' && experience.creatorId == currentUserId));

    final bool canDelete = canEdit; // Misma lógica para eliminar por ahora

    final bool canManageStatus = currentUserRole == 'admin' || currentUserRole == 'moderator';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          // Podrías navegar a una pantalla de detalles de la experiencia si la tienes
          onAction(ExperienceAction.viewDetails, experience);
          print("Ver detalles de: ${experience.title}");
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: experience.imageAsset.isNotEmpty && experience.imageAsset != 'assets/placeholder.jpg'
                        ? FadeInImage.assetNetwork(
                      placeholder: 'assets/placeholder.jpg', // Asegúrate de tener este asset
                      image: experience.imageAsset,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) =>
                          Image.asset('assets/placeholder.jpg', width: 80, height: 80, fit: BoxFit.cover),
                    )
                        : Image.asset('assets/placeholder.jpg', width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          experience.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          experience.category,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(_getStatusText(experience.status), style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: _getStatusColor(experience.status),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Acciones para Moderador/Admin
                  if (canManageStatus) ...[
                    if (experience.status == ExperienceStatus.pending) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        label: const Text('Aprobar', style: TextStyle(color: Colors.green)),
                        onPressed: () => onAction(ExperienceAction.approve, experience),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                        label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                        onPressed: () => onAction(ExperienceAction.reject, experience),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ],
                    if (experience.status == ExperienceStatus.approved) ...[
                      // Botón para Destacar / Quitar destacado
                      TextButton.icon(
                        icon: Icon(
                          experience.isFeatured ? Icons.star_border : Icons.star,
                          color: experience.isFeatured ? Colors.grey : Colors.amber,
                          size: 20,
                        ),
                        label: Text(
                          experience.isFeatured ? 'No Destacar' : 'Destacar',
                          style: TextStyle(color: experience.isFeatured ? Colors.grey : Colors.amber),
                        ),
                        onPressed: () => onAction(
                            experience.isFeatured ? ExperienceAction.unfeature : ExperienceAction.feature, experience),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ],
                  ],

                  // Acciones comunes (Editar, Eliminar)
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                      tooltip: 'Editar',
                      onPressed: () => onAction(ExperienceAction.edit, experience),
                    ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      tooltip: 'Eliminar',
                      onPressed: () => onAction(ExperienceAction.delete, experience),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
