import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../models/experience.dart';
import 'submit_experience_screen.dart';

/// Pantalla del panel de administración que se adapta al rol del usuario.
/// - Los administradores pueden gestionar experiencias y usuarios.
/// - Los moderadores solo pueden gestionar experiencias.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  /// Muestra un SnackBar con un mensaje.
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Maneja la acción de aprobar una experiencia.
  Future<void> _approveExperience(BuildContext context, String experienceId) async {
    try {
      await FirebaseFirestore.instance.collection('experiences').doc(experienceId).update({
        'status': 'approved',
        'isVerified': true,
        'isFeatured': true,
      });
      _showSnackBar('Experiencia aprobada, verificada y destacada.', Colors.green);
    } catch (e) {
      _showSnackBar('Error al aprobar la experiencia: $e', Colors.red);
    }
  }

  /// Maneja la acción de eliminar una experiencia.
  Future<void> _deleteExperience(BuildContext context, String experienceId) async {
    try {
      await FirebaseFirestore.instance.collection('experiences').doc(experienceId).delete();
      _showSnackBar('Experiencia eliminada.', Colors.green);
    } catch (e) {
      _showSnackBar('Error al eliminar la experiencia: $e', Colors.red);
    }
  }

  /// Navega a la pantalla de edición para la experiencia seleccionada.
  void _editExperience(BuildContext context, Experience experience) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitExperienceScreen(experienceToEdit: experience),
      ),
    );
  }

  /// Maneja la acción de cambiar el rol de un usuario.
  Future<void> _changeUserRole(String userId, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
      });
      _showSnackBar('Rol de usuario actualizado.', Colors.green);
    } catch (e) {
      _showSnackBar('Error al actualizar el rol: $e', Colors.red);
    }
  }

  /// Muestra una lista de experiencias en espera o aprobadas.
  Widget _buildExperienceList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('experiences').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final experiences = snapshot.data!.docs
            .map((doc) => Experience.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();

        return ListView.builder(
          itemCount: experiences.length,
          itemBuilder: (context, index) {
            final experience = experiences[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: experience.imageAsset.isNotEmpty
                    ? Image.network(experience.imageAsset, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported),
                title: Text(experience.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado: ${experience.status}'),
                    Text('Verificada: ${experience.isVerified ? 'Sí' : 'No'}'),
                    Text('Destacada: ${experience.isFeatured ? 'Sí' : 'No'}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (experience.status == 'pending')
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveExperience(context, experience.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editExperience(context, experience),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteExperience(context, experience.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Muestra una lista de usuarios.
  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs
            .map((doc) => AppUser.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(user.email),
                subtitle: Text('Rol: ${user.role}'),
                trailing: DropdownButton<String>(
                  value: user.role,
                  onChanged: (String? newRole) {
                    if (newRole != null) {
                      _changeUserRole(user.uid, newRole);
                    }
                  },
                  items: <String>['user', 'moderator', 'admin']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseAuth.instance.currentUser != null
          ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser == null) {
          return const Center(
            child: Text(
              'Acceso denegado. Debe iniciar sesión como administrador.',
              style: TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.data!.exists) {
          return const Center(
            child: Text(
              'Acceso denegado. No se encontró el rol de usuario.',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          );
        }

        final user = AppUser.fromFirestore(snapshot.data! as DocumentSnapshot<Map<String, dynamic>>);
        final isAdmin = user.role == 'admin';
        final isModerator = user.role == 'moderator';

        if (!isAdmin && !isModerator) {
          return const Center(
            child: Text(
              'Acceso denegado. No tienes permisos de administrador.',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          );
        }

        return DefaultTabController(
          length: isAdmin ? 2 : 1,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Panel de Administración', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF8B4513),
              bottom: TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                tabs: [
                  const Tab(icon: Icon(Icons.event), text: 'Experiencias'),
                  if (isAdmin)
                    const Tab(icon: Icon(Icons.people), text: 'Usuarios'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildExperienceList(),
                if (isAdmin)
                  _buildUserList(),
              ],
            ),
          ),
        );
      },
    );
  }
}
