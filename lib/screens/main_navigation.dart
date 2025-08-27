// En main_navigation.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importa tus pantallas
import 'explore_screen.dart';
import 'experiences_screen.dart';
import 'profile_screen.dart';
import 'submit_experience_screen.dart'; // Asegúrate que esta importación esté
import 'admin/admin_panel_screen.dart';
import 'creator/creator_panel_screen.dart';
import 'moderator/moderator_panel_screen.dart';

// Importa tu modelo de usuario
import '../models/user.dart'; // Ajusta la ruta si es necesario

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  AppUser? _currentUserData;
  Stream<AppUser?>? _userStream;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((User? firebaseUser) {
      if (mounted) {
        if (firebaseUser != null) {
          setState(() {
            _userStream = _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .snapshots()
                .map((snapshot) {
              if (snapshot.exists) {
                return AppUser.fromFirestore(snapshot);
              }
              return null;
            });
          });
        } else {
          setState(() {
            _currentUserData = null;
            _userStream = null;
            _selectedIndex = 0;
          });
        }
      }
    });
  }

  void _onItemTapped(int index, List<Widget> currentScreens) {
    if (index >= 0 && index < currentScreens.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else if (currentScreens.isNotEmpty) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  // Método para cambiar de pestaña programáticamente
  void _navigateToTab(int tabIndex) {
    // Aquí, currentScreens se obtendrá del contexto del build más reciente.
    // Necesitamos asegurarnos de que el índice es válido para las pantallas
    // que estarán disponibles cuando se reconstruya el widget.
    // La forma más simple es confiar en que el `build` método
    // generará `screensToShow` correctamente, y que `_onItemTapped`
    // o el `IndexedStack` manejarán un índice temporalmente inválido
    // si la lista de pantallas aún no refleja el cambio.

    // Llamamos a _onItemTapped para que maneje la lógica de actualización del índice
    // Necesitaremos la lista de pantallas que ESTARÁ disponible.
    // Esto es un poco circular. Una solución más directa:
    if (mounted) {
      // Simplemente actualiza el índice. El build se encargará del resto.
      // La validación del índice ocurrirá en el IndexedStack y en el BottomNavigationBar.
      setState(() {
        _selectedIndex = tabIndex;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (_auth.currentUser != null && userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        _currentUserData = userSnapshot.data;
        String effectiveRole = 'guest';
        if (_currentUserData != null) {
          effectiveRole = _currentUserData!.role;
        } else if (_auth.currentUser != null && !userSnapshot.hasData && userSnapshot.connectionState != ConnectionState.waiting) {
          effectiveRole = 'user';
        }

        List<Widget> screensToShow = [];
        List<BottomNavigationBarItem> navBarItems = [];

        // --- Pestañas base para 'guest' y 'user' (y todos los demás roles) ---
        screensToShow.addAll([
          const ExploreScreen(),
          const ExperiencesScreen(),
        ]);
        navBarItems.addAll([
          BottomNavigationBarItem(
            icon: Image.asset("assets/navigation_icons/hogar.png", width: 25, height: 25),
            activeIcon: Image.asset("assets/navigation_icons/hogar_rojo.png", width: 25, height: 25),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Image.asset("assets/navigation_icons/destellos.png", width: 25, height: 25),
            activeIcon: Image.asset("assets/navigation_icons/destellos_rojo.png", width: 25, height: 25),
            label: 'Experiencias',
          ),
        ]);

        // Para saber a qué índice navegar después de subir una experiencia.
        // Podrías hacerlo más dinámico si el panel del creador puede no estar.
        int targetIndexAfterSubmit = 0; // Por defecto a "Explorar" (índice 0)

        // --- Pestañas adicionales basadas en el rol efectivo ---
        if (effectiveRole != 'guest') {
          // Pestaña "Subir Experiencia"
          if (effectiveRole == 'creator' || effectiveRole == 'admin') {
            screensToShow.add(
              SubmitExperienceScreen(
                onSubmitSuccess: () {
                  // Navega a la pestaña "Explorar" (índice 0) después de enviar.
                  // O al panel del creador si esa es la preferencia.
                  // Por ahora, vamos a "Explorar".
                  _navigateToTab(targetIndexAfterSubmit);
                },
                // Aquí deberías pasar `experienceToEdit` si esta pantalla
                // también se usa para editar desde la barra de navegación.
                // Por ejemplo:
                // experienceToEdit: _someExperienceToEditLogic(),
                // Si solo es para NUEVAS experiencias desde aquí, puedes omitirlo
                // o pasar `null` explícitamente si tu constructor lo permite sin `required`.
                // Dado que `experienceToEdit` en `SubmitExperienceScreen` es opcional,
                // no necesitamos pasarlo si no estamos editando desde aquí.
              ),
            );
            navBarItems.add(
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'Subir',
              ),
            );
          }

          // Pestañas de Panel específico del rol
          if (effectiveRole == 'admin') {
            screensToShow.add(const AdminPanelScreen());
            navBarItems.add(
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_outlined),
                activeIcon: Icon(Icons.admin_panel_settings),
                label: 'Admin',
              ),
            );
            // Si un admin sube algo, quizás quiera ir a su panel.
            // targetIndexAfterSubmit = screensToShow.length -1; // Índice del AdminPanel recién añadido
          } else if (effectiveRole == 'moderator') {
            screensToShow.add(const ModeratorPanelScreen());
            navBarItems.add(
              const BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: 'Moderar',
              ),
            );
          } else if (effectiveRole == 'creator') { // Solo 'creator', no 'admin' que ya tiene su panel
            // Asumimos que si es solo 'creator', quiere ir a su panel después de subir.
            // targetIndexAfterSubmit = screensToShow.length; // El índice ANTES de añadir el panel del creador.
            // OJO: La pestaña "Subir" ya fue añadida.
            // Hay que ser cuidadoso con el orden.

            // Para simplificar, mantenemos targetIndexAfterSubmit = 0 (Explorar).
            // Si quieres que vaya al CreatorPanel, debes calcular el índice correcto
            // de CreatorPanelScreen en la lista screensToShow.
            // Ejemplo: si CreatorPanel es la última pestaña para un 'creator'
            // (después de Explorar, Experiencias, Subir):
            // targetIndexAfterSubmit = 3; (o screensToShow.length)

            screensToShow.add(const CreatorPanelScreen());
            navBarItems.add(
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Mi Panel',
              ),
            );
          }
        }

        // Pestaña de Perfil (siempre al final para todos)
        screensToShow.add(const ProfileScreen());
        navBarItems.add(
          BottomNavigationBarItem(
            icon: Image.asset("assets/navigation_icons/usuario.png", width: 25, height: 25),
            activeIcon: Image.asset("assets/navigation_icons/usuario_rojo.png", width: 25, height: 25),
            label: 'Perfil',
          ),
        );

        // Ajustar _selectedIndex si después de un cambio de rol queda fuera de rango
        int currentSelectedIndex = _selectedIndex;
        if (currentSelectedIndex >= screensToShow.length && screensToShow.isNotEmpty) {
          currentSelectedIndex = 0; // Ir a la primera pestaña
        } else if (screensToShow.isEmpty && currentSelectedIndex != 0) {
          currentSelectedIndex = 0;
        }

        // Usar addPostFrameCallback para evitar errores de setState durante el build
        if (_selectedIndex != currentSelectedIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedIndex = currentSelectedIndex;
              });
            }
          });
        }

        return Scaffold(
          body: screensToShow.isEmpty
              ? const Center(child: Text("Sin pantallas disponibles")) // O un CircularProgressIndicator
              : IndexedStack(
            index: (_selectedIndex >= 0 && _selectedIndex < screensToShow.length) ? _selectedIndex : 0,
            children: screensToShow,
          ),
          bottomNavigationBar: navBarItems.isEmpty
              ? null
              : Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide( color: Colors.white, width: 5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, -1),
                )
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: (_selectedIndex >= 0 && _selectedIndex < navBarItems.length) ? _selectedIndex : 0,
              onTap: (index) => _onItemTapped(index, screensToShow), // Pasa screensToShow actual
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF952E07),
              unselectedItemColor: const Color.fromARGB(255, 100, 100, 100),
              backgroundColor: Colors.white,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: navBarItems,
              selectedLabelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}
