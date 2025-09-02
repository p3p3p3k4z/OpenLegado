import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/experience.dart'; // Asegúrate que ExperienceAction y ExperienceStatus estén aquí
import '../../widgets/experience_list_item.dart';
import '../submit_experience_screen.dart';
import 'package:intl/intl.dart';
// IMPORTANTE: Asegúrate que esta línea esté en tu main.dart y se ejecute initializeDateFormatting allí.
// import 'package:intl/date_symbol_data_local.dart';

class ManageExperiencesTab extends StatefulWidget {
  final String currentUserRole; // 'moderator' o 'admin'
  final String currentUserId;

  const ManageExperiencesTab({
    super.key,
    required this.currentUserRole,
    required this.currentUserId,
  });

  @override
  State<ManageExperiencesTab> createState() => _ManageExperiencesTabState();
}

// Tu función formatDate original.
// Es CRUCIAL que initializeDateFormatting('es_MX', null) se haya llamado en main.dart
String formatDate(DateTime? date) {
  if (date == null) return 'N/A';
  try {
    return DateFormat('yyyy-MM-dd – kk:mm', 'es_MX').format(date.toLocal());
  } catch (e) {
    print("Error en formatDate (es_MX no inicializado?): $e. Usando formato por defecto.");
    return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal()); // Fallback
  }
}

class _ManageExperiencesTabState extends State<ManageExperiencesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateExperienceStatus(Experience experience, ExperienceStatus newStatus, {bool? isVerified, bool? isFeatured}) async {
    if (widget.currentUserRole != 'moderator' && widget.currentUserRole != 'admin') {
      _showSnackBar('No tienes permiso para esta acción.', isError: true);
      return;
    }
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus.name,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (isVerified != null) {
        updateData['isVerified'] = isVerified;
      }
      if (isFeatured != null) {
        updateData['isFeatured'] = isFeatured;
      }

      await _firestore.collection('experiences').doc(experience.id).update(updateData);
      _showSnackBar(
        'Experiencia "${experience.title}" actualizada a ${newStatus.name}.',
      );
    } catch (e) {
      _showSnackBar('Error al actualizar la experiencia: $e', isError: true);
    }
  }

  Future<void> _deleteExperience(Experience experience) async {
    if (widget.currentUserRole != 'moderator' && widget.currentUserRole != 'admin') {
      _showSnackBar('No tienes permiso para eliminar.', isError: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${experience.title}" de forma permanente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('experiences').doc(experience.id).delete();
        _showSnackBar('Experiencia eliminada con éxito.');
      } catch (e) {
        _showSnackBar('Error al eliminar la experiencia: $e', isError: true);
      }
    }
  }

  void _navigateToEditExperience(Experience experience) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitExperienceScreen(
          experienceToEdit: experience,
          onSubmitSuccess: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // MÉTODO PARA FORMATEAR LA FECHA Y HORA DE UN SCHEDULE
  String _formatScheduleDateTime(DateTime date) {
    // Es CRUCIAL que initializeDateFormatting('es_MX', null) se haya llamado en main.dart
    try {
      return DateFormat('EEE, d MMM yyyy, hh:mm a', 'es_MX').format(date.toLocal());
    } catch (e) {
      print("Error en _formatScheduleDateTime (es_MX no inicializado?): $e. Usando formato por defecto.");
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal()); // Fallback
    }
  }

  void _handleExperienceAction(ExperienceAction action, Experience experience) {
    // Asegúrate de que widget.currentUserRole y widget.currentUserId se usan si es necesario aquí
    switch (action) {
      case ExperienceAction.edit: // Asegurarse que todos los casos de tu enum están
        _navigateToEditExperience(experience);
        break;
      case ExperienceAction.delete:
        _deleteExperience(experience);
        break;
      case ExperienceAction.approve:
        _updateExperienceStatus(experience, ExperienceStatus.approved, isVerified: true);
        break;
      case ExperienceAction.reject:
        _updateExperienceStatus(experience, ExperienceStatus.rejected, isVerified: false, isFeatured: false);
        break;
      case ExperienceAction.feature:
        if (experience.status == ExperienceStatus.approved) {
          _updateExperienceStatus(experience, ExperienceStatus.approved, isFeatured: true);
        } else {
          _showSnackBar('Solo se pueden destacar experiencias que ya han sido aprobadas.', isError: true);
        }
        break;
      case ExperienceAction.unfeature:
        _updateExperienceStatus(experience, experience.status, isFeatured: false);
        break;
      case ExperienceAction.viewDetails:
        final List<TicketSchedule> sortedSchedules = List.from(experience.schedule);
        sortedSchedules.sort((a, b) => a.date.compareTo(b.date));

        showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(experience.title),
              content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("ID: ${experience.id}"),
                      Text("Creador ID: ${experience.creatorId}"),
                      Text("Categoría: ${experience.category}"),
                      Text("Estado: ${experience.status.name}"),
                      Text("Verificada: ${experience.isVerified ? 'Sí' : 'No'}"),
                      Text("Destacada: ${experience.isFeatured ? 'Sí' : 'No'}"),
                      Text("Ubicación: ${experience.location}"),
                      Text("Precio: \$${experience.price.toStringAsFixed(2)}"),
                      Text("Enviada: ${formatDate(experience.submittedAt)}"), // Usa la función de nivel de archivo
                      Text("Actualizada: ${formatDate(experience.lastUpdatedAt)}"), // Usa la función de nivel de archivo
                      const SizedBox(height: 8),
                      Text("Descripción:", style: Theme.of(context).textTheme.titleSmall),
                      Text(experience.description),
                      const SizedBox(height: 16),
                      if (sortedSchedules.isNotEmpty) ...[
                        Text("Horarios Programados:", style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        ...sortedSchedules.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                            child: Text(
                              "• ${_formatScheduleDateTime(s.date)} - Cupo: ${s.capacity} (Reservados: ${s.bookedTickets})", // Usa el método de la clase
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        }),
                      ] else if (experience.maxCapacity > 0) ...[
                        Text("Horarios: No específicos (usa capacidad general)", style: Theme.of(context).textTheme.titleSmall),
                        Text("Capacidad Máx. General: ${experience.maxCapacity}", style: Theme.of(context).textTheme.bodySmall),
                        Text("Reservados (General): ${experience.bookedTickets}", style: Theme.of(context).textTheme.bodySmall),
                      ] else ...[
                        Text("Horarios: No programados.", style: Theme.of(context).textTheme.titleSmall),
                      ]
                    ],
                  )),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
            ));
        break;
    // Añade aquí cualquier otro caso de ExperienceAction que puedas tener
    // default:
    //   print("Acción de experiencia no manejada: $action");
    }
  }

  @override
  Widget build(BuildContext context) { // MÉTODO BUILD RESTAURADO
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar experiencias por título o categoría',
                  hintText: 'Ej: "Taller de barro" o "Gastronomía"',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FilterChip(
                      label: const Text('Todas'),
                      selected: _selectedFilter == 'all',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'all');
                      },
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                      checkmarkColor: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pendientes'),
                      selected: _selectedFilter == 'pending',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'pending');
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.orangeAccent.withOpacity(0.7), radius: 8),
                      selectedColor: Colors.orangeAccent.withOpacity(0.3),
                      checkmarkColor: Colors.deepOrange,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Aprobadas'),
                      selected: _selectedFilter == 'approved',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'approved');
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.7), radius: 8),
                      selectedColor: Colors.green.withOpacity(0.3),
                      checkmarkColor: Colors.green.shade800,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Rechazadas'),
                      selected: _selectedFilter == 'rejected',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'rejected');
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.redAccent.withOpacity(0.7), radius: 8),
                      selectedColor: Colors.redAccent.withOpacity(0.3),
                      checkmarkColor: Colors.red.shade800,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('experiences')
                .orderBy('lastUpdatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay experiencias para mostrar.'));
              }

              List<Experience> experiences = snapshot.data!.docs
                  .map((doc) => Experience.fromFirestore(doc))
                  .toList();

              if (_selectedFilter != 'all') {
                experiences = experiences
                    .where((exp) => exp.status.name == _selectedFilter)
                    .toList();
              }

              if (_searchQuery.isNotEmpty) {
                experiences = experiences
                    .where((exp) =>
                exp.title.toLowerCase().contains(_searchQuery) ||
                    exp.category.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (experiences.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No hay experiencias que coincidan con los filtros${_searchQuery.isNotEmpty ? ' y la búsqueda actual' : ''}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8, top: 8),
                itemCount: experiences.length,
                itemBuilder: (context, index) {
                  final experience = experiences[index];
                  return ExperienceListItem(
                    experience: experience,
                    // ACCESO CORRECTO A widget.currentUserRole y widget.currentUserId
                    currentUserRole: widget.currentUserRole,
                    currentUserId: widget.currentUserId,
                    onAction: _handleExperienceAction,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
