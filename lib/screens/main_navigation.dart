import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart'; // Importa el nuevo servicio de Firestore
import 'admin_panel_screen.dart';
import 'submit_experience_screen.dart';
import 'explore_screen.dart';
import 'experiences_screen.dart';
import 'profile_screen.dart';
import 'search_and_filter_screen.dart';

/// Widget principal que gestiona la navegación de nivel superior de la aplicación.
/// Utiliza un `BottomNavigationBar` para cambiar entre diferentes pantallas,
/// mostrando opciones adicionales (como el panel de administración)
/// según el rol del usuario.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;

  // Lista de pantallas para usuarios normales.
  final List<Widget> _userScreens = [
    const ExploreScreen(),
    const SearchAndFilterScreen(),
    const ExperiencesScreen(),
    const SubmitExperienceScreen(),
    const ProfileScreen(),
  ];

  // Lista de pantallas para usuarios administradores.
  final List<Widget> _adminScreens = [
    const ExploreScreen(),
    const SearchAndFilterScreen(),
    const ExperiencesScreen(),
    const SubmitExperienceScreen(),
    const AdminPanelScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios de autenticación para obtener el rol del usuario.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data;

        if (user != null) {
          // Escucha el documento del usuario para obtener su rol.
          return StreamBuilder<DocumentSnapshot>(
            stream: _firestoreService.getUserStream(user.uid),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              bool isAdmin = false;
              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userRole = userDocSnapshot.data!['role'] as String? ?? 'user';
                if (userRole == 'admin' || userRole == 'moderator') {
                  isAdmin = true;
                }
              }

              final screensToShow = isAdmin ? _adminScreens : _userScreens;

              return Scaffold(
                body: screensToShow[_selectedIndex],
                bottomNavigationBar: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  selectedItemColor: const Color(0xFFE67E22),
                  unselectedItemColor: const Color(0xFF8D6E63),
                  backgroundColor: Colors.white,
                  elevation: 8,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.explore),
                      activeIcon: Icon(Icons.explore, size: 28),
                      label: 'Explorar',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.search),
                      activeIcon: Icon(Icons.search, size: 28),
                      label: 'Buscar',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_view_day),
                      activeIcon: Icon(Icons.calendar_view_day, size: 28),
                      label: 'Mis Experiencias',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.add_circle_outline),
                      activeIcon: Icon(Icons.add_circle_outline, size: 28),
                      label: 'Subir',
                    ),
                    if (isAdmin)
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.admin_panel_settings),
                        activeIcon: Icon(Icons.admin_panel_settings, size: 28),
                        label: 'Admin',
                      ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person),
                      activeIcon: Icon(Icons.person, size: 28),
                      label: 'Mi perfil',
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          // Si no hay usuario logueado, mostramos una versión simplificada de la navegación.
          final simplifiedScreens = _userScreens;

          return Scaffold(
            body: simplifiedScreens[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: const Color(0xFFE67E22),
              unselectedItemColor: const Color(0xFF8D6E63),
              backgroundColor: Colors.white,
              elevation: 8,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore),
                  activeIcon: Icon(Icons.explore, size: 28),
                  label: 'Explorar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  activeIcon: Icon(Icons.search, size: 28),
                  label: 'Buscar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_view_day),
                  activeIcon: Icon(Icons.calendar_view_day, size: 28),
                  label: 'Mis Experiencias',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  activeIcon: Icon(Icons.person, size: 28),
                  label: 'Mi perfil',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
