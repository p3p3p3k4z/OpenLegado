import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/experience.dart';
import '../../models/user.dart'; // Para obtener el AppUser y su rol
import '../../widgets/experience_list_item.dart'; // Widget reutilizable
import '../submit_experience_screen.dart'; // Para crear/editar experiencias

class CreatorPanelScreen extends StatefulWidget {
  const CreatorPanelScreen({super.key});

  @override
  State<CreatorPanelScreen> createState() => _CreatorPanelScreenState();
}

class _CreatorPanelScreenState extends State<CreatorPanelScreen> {
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
          // Asegúrate de que el casteo sea seguro
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
        await _firestore.collection('experiences').doc(experience.id).delete();
        _showSnackBar('Experiencia eliminada con éxito.');
        // No es necesario setState aquí si el StreamBuilder maneja la actualización de la lista
      } catch (e) {
        _showSnackBar('Error al eliminar la experiencia: $e', isError: true);
      }
    }
  }

  // MODIFICADO AQUÍ
  void _navigateToSubmitExperience({Experience? experienceToEdit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitExperienceScreen(
          experienceToEdit: experienceToEdit,
          onSubmitSuccess: () {
            // Cuando SubmitExperienceScreen llama a este callback,
            // simplemente cerramos SubmitExperienceScreen.
            // El .then() de Navigator.push se encargará de refrescar.
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    ).then((_) {
      // Este .then se ejecuta cuando se regresa de SubmitExperienceScreen
      // (ya sea por el pop que acabamos de agregar en onSubmitSuccess o si el usuario usa el botón "atrás").
      // Refresca la lista de experiencias en el panel.
      if (mounted) {
        setState(() {});
      }
    });
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
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(experience.title),
              content: SingleChildScrollView(
                child: Text("Categoría: ${experience.category}\n"
                    "Estado: ${experience.status.toString().split('.').last}\n"
                    "Ubicación: ${experience.location}\n"
                  // Agrega más detalles si quieres
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
            ));
        break;
      default:
        print("Acción no manejada para creador: $action");
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

    // Simplificamos la verificación de rol, ya que este panel es para creadores.
    // Si un admin llega aquí, puede ser una lógica intencional o un error de navegación.
    // Por ahora, solo nos aseguramos de que sea 'creator' o 'admin' (si admin puede ver esto)
    // Sin embargo, el panel de "Mis experiencias" suele ser más específico del creadorId.
    if (_currentAppUser!.role != 'creator' && _currentAppUser!.role != 'admin' ) { // He añadido admin aquí por si acaso, pero el query es por creatorId
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
            onPressed: () => _navigateToSubmitExperience(), // Llama sin argumentos para nueva experiencia
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('experiences')
            .where('creatorId', isEqualTo: _currentUser!.uid) // Solo las del creador actual
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
                      onPressed: () => _navigateToSubmitExperience(), // Llama sin argumentos para nueva experiencia
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            );
          }

          final experiences = snapshot.data!.docs.map((doc) => Experience.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: experiences.length,
            itemBuilder: (context, index) {
              final experience = experiences[index];
              return ExperienceListItem(
                experience: experience,
                currentUserRole: _currentAppUser!.role,
                currentUserId: _currentUser!.uid,
                onAction: (action, exp) => _handleExperienceAction(action, exp), // Asegúrate que el onAction esté bien
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nueva Experiencia'),
        onPressed: () => _navigateToSubmitExperience(), // Llama sin argumentos para nueva experiencia
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
