import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Solo para obtener el rol actual
import '../../models/experience.dart';
import '../../models/user.dart'; // Para AppUser
import '../../widgets/experience_list_item.dart';
import '../submit_experience_screen.dart';
import 'package:intl/intl.dart';

class ManageExperiencesTab extends StatefulWidget {
  final String currentUserRole; // 'moderator' o 'admin'
  final String currentUserId;   // Para referencia, aunque no se use mucho aquí

  const ManageExperiencesTab({
    super.key,
    required this.currentUserRole,
    required this.currentUserId,
  });

  @override
  State<ManageExperiencesTab> createState() => _ManageExperiencesTabState();
}

String formatDate(DateTime? date) {
  if (date == null) return 'N/A';
  // Elige el formato que prefieras. Ej: 'dd/MM/yyyy HH:mm'
  return DateFormat('yyyy-MM-dd – kk:mm', 'es_MX').format(date.toLocal()); // 'es_MX' o tu locale
}

class _ManageExperiencesTabState extends State<ManageExperiencesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
        'status': newStatus.toString().split('.').last,
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
        'Experiencia "${experience.title}" actualizada a ${newStatus.toString().split('.').last}.',
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
        builder: (context) => SubmitExperienceScreen(experienceToEdit: experience),
      ),
    ).then((_) => setState(() {})); // Refrescar si hay cambios
  }

  void _handleExperienceAction(ExperienceAction action, Experience experience) {
    switch (action) {
      case ExperienceAction.edit:
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
        _updateExperienceStatus(experience, experience.status, isFeatured: true);
        break;
      case ExperienceAction.unfeature:
        _updateExperienceStatus(experience, experience.status, isFeatured: false);
        break;
      case ExperienceAction.viewDetails:
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
                      Text("Estado: ${experience.status.toString().split('.').last}"),
                      Text("Verificada: ${experience.isVerified ? 'Sí' : 'No'}"),
                      Text("Destacada: ${experience.isFeatured ? 'Sí' : 'No'}"),
                      Text("Ubicación: ${experience.location}"),
                      Text("Precio: \$${experience.price}"),
                      Text("Enviada: ${formatDate(experience.submittedAt)}"),
                      Text("Actualizada: ${formatDate(experience.lastUpdatedAt)}"),
                    ],
                  )
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
            ));
        break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // --- Barra de Búsqueda ---
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
              // --- Filtros ---
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
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pendientes'),
                      selected: _selectedFilter == 'pending',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'pending');
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.orangeAccent.withOpacity(0.5),radius: 8),
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Aprobadas'),
                      selected: _selectedFilter == 'approved',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'approved');
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.5),radius: 8),
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Rechazadas'),
                      selected: _selectedFilter == 'rejected',
                      onSelected: (bool selected) {
                        if (selected) setState(() => _selectedFilter = 'rejected');
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.redAccent.withOpacity(0.5), radius: 8),
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
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

              // Aplicar filtro de estado
              if (_selectedFilter != 'all') {
                experiences = experiences
                    .where((exp) => exp.status.toString().split('.').last == _selectedFilter)
                    .toList();
              }

              // Aplicar filtro de búsqueda
              if (_searchQuery.isNotEmpty) {
                experiences = experiences
                    .where((exp) =>
                exp.title.toLowerCase().contains(_searchQuery) ||
                    exp.category.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (experiences.isEmpty) {
                return Center(
                  child: Text(
                    'No hay experiencias que coincidan con los filtros${_searchQuery.isNotEmpty ? ' y la búsqueda' : ''}.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: experiences.length,
                itemBuilder: (context, index) {
                  final experience = experiences[index];
                  return ExperienceListItem(
                    experience: experience,
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
