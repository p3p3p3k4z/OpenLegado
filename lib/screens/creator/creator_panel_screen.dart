import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/experience.dart'; // Asegúrate que ExperienceAction, ExperienceStatus, TicketSchedule estén aquí o importados por Experience
import '../../models/user.dart'; // Para obtener el AppUser y su rol
import '../../widgets/experience_list_item.dart'; // Widget reutilizable
import '../submit_experience_screen.dart'; // Para crear/editar experiencias
import 'package:intl/intl.dart'; // Para DateFormat

class CreatorPanelScreen extends StatefulWidget {
  const CreatorPanelScreen({super.key});

  @override
  State<CreatorPanelScreen> createState() => _CreatorPanelScreenState();
}

class _CreatorPanelScreenState extends State<CreatorPanelScreen> {
  // Constante para el nombre de la colección de experiencias.
  static const String _experienceCollection = 'experiences';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  AppUser? _currentAppUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }


  Future<void> _loadCurrentUser() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentAppUser = AppUser.fromFirestore(userDoc as DocumentSnapshot<Map<String, dynamic>>);
          _isLoadingUser = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingUser = false;
          print("Error: Documento de AppUser no encontrado en Firestore para UID: ${_currentUser!.uid}");
        });
      }
    } else if (mounted) {
      setState(() {
        _isLoadingUser = false;
        print("Error: No hay usuario de FirebaseAuth logueado.");
      });
    }
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

  Future<void> _deleteExperience(Experience experience) async {
    if (_currentUser == null || experience.creatorId != _currentUser!.uid) {
      _showSnackBar('No tienes permiso para eliminar esta experiencia.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${experience.title}"? Esta acción no se puede deshacer.'),
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
        // Se actualiza el nombre de la colección aquí.
        await _firestore.collection(_experienceCollection).doc(experience.id).delete();
        _showSnackBar('Experiencia eliminada con éxito.');
      } catch (e) {
        _showSnackBar('Error al eliminar la experiencia: $e', isError: true);
      }
    }
  }

  void _navigateToSubmitExperience({Experience? experienceToEdit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitExperienceScreen(
          experienceToEdit: experienceToEdit,
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
    try {
      return DateFormat('EEE, d MMM yyyy, hh:mm a', 'es_MX').format(date.toLocal());
    } catch (e) {
      print("Error en _formatScheduleDateTime (CreatorPanelScreen - es_MX no inicializado?): $e. Usando formato por defecto.");
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal()); // Fallback
    }
  }

  // Función de utilidad para formatear fechas generales (si la necesitas aquí también)
  String _formatGeneralDate(DateTime? date) {
    if (date == null) return 'N/A';
    try {
      return DateFormat('yyyy-MM-dd – kk:mm', 'es_MX').format(date.toLocal());
    } catch (e) {
      print("Error en _formatGeneralDate (CreatorPanelScreen - es_MX no inicializado?): $e. Usando formato por defecto.");
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal()); // Fallback
    }
  }


  void _handleExperienceAction(ExperienceAction action, Experience experience) {
    switch (action) {
      case ExperienceAction.edit:
        _navigateToSubmitExperience(experienceToEdit: experience);
        break;
      case ExperienceAction.delete:
        _deleteExperience(experience);
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
                    Text("Categoría: ${experience.category}"),
                    Text("Estado: ${experience.status.name}"),
                    Text("Verificada: ${experience.isVerified ? 'Sí' : 'No'}"),
                    Text("Destacada: ${experience.isFeatured ? 'Sí' : 'No'}"),
                    Text("Ubicación: ${experience.location}"),
                    Text("Precio: \$${experience.price.toStringAsFixed(2)}"),
                    Text("Enviada: ${_formatGeneralDate(experience.submittedAt)}"),
                    Text("Actualizada: ${_formatGeneralDate(experience.lastUpdatedAt)}"),
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
                            "• ${_formatScheduleDateTime(s.date)} - Cupo: ${s.capacity} (Reservados: ${s.bookedTickets})",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }).toList(),
                    ] else if (experience.maxCapacity > 0) ...[
                      Text("Horarios: No específicos (usa capacidad general)", style: Theme.of(context).textTheme.titleSmall),
                      Text("Capacidad Máx. General: ${experience.maxCapacity}", style: Theme.of(context).textTheme.bodySmall),
                      Text("Reservados (General): ${experience.bookedTickets}", style: Theme.of(context).textTheme.bodySmall),
                    ] else ...[
                      Text("Horarios: No programados.", style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
            ));
        break;
      default:
        print("Acción no manejada para creador: $action en experiencia: ${experience.title}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(appBar: AppBar(title: const Text('Mis Experiencias')), body: const Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null || _currentAppUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Experiencias')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No has iniciado sesión o no se pudo cargar tu información de usuario. Por favor, intenta de nuevo.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_currentAppUser!.role != 'creator' && _currentAppUser!.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Experiencias')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No tienes los permisos necesarios para acceder a esta sección.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Experiencias Publicadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Crear Nueva Experiencia',
            onPressed: () => _navigateToSubmitExperience(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Se actualiza el nombre de la colección en la consulta aquí.
        stream: _firestore
            .collection(_experienceCollection)
            .where('creatorId', isEqualTo: _currentUser!.uid)
            .orderBy('lastUpdatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error en StreamBuilder (CreatorPanel): ${snapshot.error}");
            return Center(child: Text('Error al cargar experiencias: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sentiment_dissatisfied_outlined, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Aún no has publicado ninguna experiencia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Publicar mi Primera Experiencia'),
                      onPressed: () => _navigateToSubmitExperience(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white, // Color del texto e icono
                      ),
                    )
                  ],
                ),
              ),
            );
          }

          final experiences = snapshot.data!.docs.map((doc) => Experience.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80), // Espacio para el FAB
            itemCount: experiences.length,
            itemBuilder: (context, index) {
              final experience = experiences[index];
              return ExperienceListItem(
                experience: experience,
                currentUserRole: _currentAppUser!.role, // Rol del usuario actual
                currentUserId: _currentUser!.uid,     // ID del usuario actual
                onAction: (action, exp) => _handleExperienceAction(action, exp),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nueva Experiencia'),
        onPressed: () => _navigateToSubmitExperience(),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
