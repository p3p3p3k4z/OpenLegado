import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart'; // Para AppUser
import './manage_experiences_tab.dart';
import './manage_users_tab.dart';
import './manage_themed_collections_tab.dart'; // <<<--- 1. AÑADE ESTA IMPORTACIÓN

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
    _tabController = TabController(length: 3, vsync: this); // <<<--- 2. CAMBIA LENGTH A 3
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) { // Buena práctica verificar mounted antes de setState
        if (userDoc.exists) {
          setState(() {
            _currentAppUser = AppUser.fromFirestore(userDoc);
            _isLoadingUser = false;
          });
        } else {
          _handleLoadingError("Documento de usuario no encontrado.");
        }
      }
    } else if (mounted) {
      _handleLoadingError("No hay usuario autenticado.");
    }
  }

  void _handleLoadingError(String message) {
    if (mounted) { // Buena práctica
      setState(() {
        _isLoadingUser = false;
      });
    }
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
        // backgroundColor: Colors.blueGrey[900], // Ejemplo si quieres un color de fondo para AppBar
        // foregroundColor: Colors.white, // Color para el título y acciones del AppBar
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent, // Color del indicador de la pestaña activa
          labelColor: Colors.orange,          // Color del ICONO y TEXTO de la pestaña activa
          unselectedLabelColor: Colors.orange.withOpacity(0.6), // Color del ICONO y TEXTO de las pestañas inactivas
          isScrollable: true,
          // indicatorWeight: 3.0, // Grosor del indicador
          // indicatorPadding: EdgeInsets.symmetric(horizontal: 8.0), // Padding para el indicador
          // labelStyle: TextStyle(fontWeight: FontWeight.bold), // Estilo para el texto de la pestaña activa
          // unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal), // Estilo para el texto de la pestaña inactiva
          tabs: const [
            Tab(
              icon: Icon(Icons.event_note_outlined), // El color lo tomará de labelColor/unselectedLabelColor
              text: 'Experiencias',
            ),
            Tab(
              icon: Icon(Icons.people_alt_outlined),
              text: 'Usuarios',
            ),
            Tab(
              icon: Icon(Icons.collections_bookmark_outlined),
              text: 'Colecciones',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManageExperiencesTab(
            currentUserRole: _currentAppUser!.role,
            currentUserId: _currentAppUser!.uid,
          ),
          const ManageUsersTab(),
          const ManageThemedCollectionsTab(), // <<<--- 4. AÑADE EL WIDGET DE LA NUEVA VISTA
        ],
      ),
    );
  }
}
