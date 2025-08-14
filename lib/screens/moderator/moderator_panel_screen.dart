import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart'; // Para AppUser
import '../admin/manage_experiences_tab.dart'; // Reutilizamos la pestaña

class ModeratorPanelScreen extends StatefulWidget {
  const ModeratorPanelScreen({super.key});

  @override
  State<ModeratorPanelScreen> createState() => _ModeratorPanelScreenState();
}

class _ModeratorPanelScreenState extends State<ModeratorPanelScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentAppUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentAppUser = AppUser.fromFirestore(userDoc as DocumentSnapshot<Map<String, dynamic>>);
          _isLoadingUser = false;
        });
      } else if (mounted) {
        _handleLoadingError("Documento de usuario no encontrado.");
      }
    } else if (mounted) {
      _handleLoadingError("No hay usuario autenticado.");
    }
  }

  void _handleLoadingError(String message) {
    setState(() {
      _isLoadingUser = false;
    });
    print("Error ModeratorPanel: $message");
    // Podrías mostrar un SnackBar o redirigir
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel de Moderador')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentAppUser == null || (_currentAppUser!.role != 'moderator' && _currentAppUser!.role != 'admin')) {
      // Si es admin, también podría acceder, pero asumimos que tiene su propio panel
      // Esta pantalla es específicamente para moderadores
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No tienes los permisos necesarios para acceder a esta sección.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Moderación'),
        // Puedes añadir acciones específicas para moderadores si es necesario
      ),
      body: ManageExperiencesTab(
        currentUserRole: _currentAppUser!.role, // Será 'moderator' o 'admin' si un admin usa esta vista
        currentUserId: _currentAppUser!.uid,
      ),
    );
  }
}
