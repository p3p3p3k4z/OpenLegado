import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart'; // Para AppUser
import './manage_experiences_tab.dart';
import './manage_users_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentAppUser;
  bool _isLoadingUser = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 pestañas: Experiencias, Usuarios
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentAppUser = AppUser.fromFirestore(userDoc);
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
    print("Error AdminPanel: $message");
    // Podrías mostrar un SnackBar o redirigir
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel de Administración')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentAppUser == null || _currentAppUser!.role != 'admin') {
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
        title: const Text('Panel de Administración'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          tabs: const [
            Tab(icon: Icon(Icons.event_note_outlined), text: 'Experiencias'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Usuarios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManageExperiencesTab(
            currentUserRole: _currentAppUser!.role, // Será 'admin'
            currentUserId: _currentAppUser!.uid,
          ),
          const ManageUsersTab(),
        ],
      ),
    );
  }
}
