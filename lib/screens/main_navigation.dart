// En main_navigation.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importa tus pantallas
import 'explore_screen.dart';
import 'experiences_screen.dart';
import 'profile_screen.dart';
import 'submit_experience_screen.dart';
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
  AppUser? _currentUserData; // Almacena los datos del AppUser deserializados
  Stream<AppUser?>? _userStream; // Stream para escuchar cambios en los datos del usuario

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _auth.authStateChanges().listen((User? firebaseUser) {
      if (!mounted) return; // Si el widget ya no está montado, no hacer nada

      if (firebaseUser != null) {
        // Usuario ha iniciado sesión, escuchar sus datos de Firestore
        if (_userStream == null || (_currentUserData?.uid != firebaseUser.uid)) {
          // Solo reiniciar el stream si es necesario (nuevo usuario o primera vez)
          setState(() {
            _userStream = _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .snapshots()
                .map((snapshot) {
              if (snapshot.exists) {
                print("Datos de usuario recibidos desde Firestore: ${snapshot.data()}");
                return AppUser.fromFirestore(snapshot);
              }
              print("Snapshot de usuario no existe para UID: ${firebaseUser.uid}");
              return null; // El documento del usuario no existe
            }).handleError((error) {
              print("Error en el stream de datos del usuario: $error");
              return null; // Manejar error en el stream
            });
          });
        }
      } else {
        // Usuario ha cerrado sesión
        setState(() {
          _currentUserData = null;
          _userStream = null; // Detener el stream anterior
          _selectedIndex = 0; // Volver a la pestaña por defecto
          print("Usuario cerró sesión. Navegación reiniciada.");
        });
      }
    });
  }

  void _onItemTapped(int index) {
    // La validación del índice la hará el BottomNavigationBar y el IndexedStack
    // al usar la longitud de las listas generadas en build.
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToTab(int tabIndex) {
    // Simplemente actualiza el índice. El método build se encargará de reconstruir
    // con las pantallas y pestañas correctas.
    if (mounted) {
      setState(() {
        _selectedIndex = tabIndex;
      });
    }
  }

  // --- Métodos Helper para construir la UI ---

  String _getEffectiveRole(AppUser? userData, User? firebaseUser) {
    if (userData != null) {
      return userData.role; // Rol desde Firestore tiene prioridad
    }
    if (firebaseUser != null) {
      // Si hay un usuario de Firebase pero no datos de AppUser (quizás aún cargando o no existe el doc)
      // podríamos considerarlo 'user' por defecto, o esperar. Por ahora, 'user'.
      return 'user';
    }
    return 'guest'; // No hay usuario autenticado
  }

  List<Widget> _buildScreens(String effectiveRole) {
    List<Widget> screens = [];

    // Pestañas base (todos los roles)
    screens.add(const ExploreScreen());
    screens.add(const ExperiencesScreen());

    // Pestaña "Subir Experiencia" (solo para creator y admin)
    if (effectiveRole == 'creator' || effectiveRole == 'admin') {
      screens.add(SubmitExperienceScreen(
        onSubmitSuccess: () {
          // Navegar a la pestaña "Explorar" (índice 0) después de subir.
          // O podrías tener una lógica para ir al panel del creador/admin.
          _navigateToTab(0);
        },
        // experienceToEdit: null, // Si es solo para nuevas desde aquí
      ));
    }

    // Paneles específicos de rol
    switch (effectiveRole) {
      case 'admin':
        screens.add(const AdminPanelScreen());
        break;
      case 'moderator':
        screens.add(const ModeratorPanelScreen());
        break;
      case 'creator':
      // Si es solo 'creator' y no 'admin' (admin ya tiene su panel)
        screens.add(const CreatorPanelScreen());
        break;
    }

    // Pestaña de Perfil (todos los roles, excepto guest si se decide ocultar)
    // Si queremos que guest no vea perfil, podríamos añadir: if (effectiveRole != 'guest')
    screens.add(const ProfileScreen());

    return screens;
  }

  List<BottomNavigationBarItem> _buildNavBarItems(String effectiveRole) {
    List<BottomNavigationBarItem> items = [];

    // Ítems base (todos los roles)
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.explore_outlined),
      activeIcon: Icon(Icons.explore),
      label: 'Explorar',
    ));
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today_outlined),
      activeIcon: Icon(Icons.calendar_today),
      label: 'Experiencias',
    ));

    // Ítem "Subir Experiencia"
    if (effectiveRole == 'creator' || effectiveRole == 'admin') {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle_outline),
        activeIcon: Icon(Icons.add_circle),
        label: 'Subir',
      ));
    }

    // Ítems de Panel específico del rol
    switch (effectiveRole) {
      case 'admin':
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ));
        break;
      case 'moderator':
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.shield_outlined),
          activeIcon: Icon(Icons.shield),
          label: 'Moderar',
        ));
        break;
      case 'creator':
        items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Mi Panel',
        ));
        break;
    }

    // Ítem de Perfil
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Mi Perfil',
    ));

    return items;
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder escucha los datos del AppUser desde Firestore
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        // Caso 1: Usuario de Firebase existe pero datos de AppUser aún cargando
        if (_auth.currentUser != null && userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
          print("MainNavigation: Esperando datos de AppUser...");
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFE67E22))));
        }

        // Almacenar los datos de AppUser cuando estén disponibles
        if (userSnapshot.hasData) {
          _currentUserData = userSnapshot.data;
          print("MainNavigation: Datos de AppUser actualizados: Rol ${_currentUserData?.role}");
        } else if (userSnapshot.hasError) {
          print("MainNavigation: Error en userSnapshot: ${userSnapshot.error}");
        }


        // Determinar el rol efectivo
        final String effectiveRole = _getEffectiveRole(_currentUserData, _auth.currentUser);
        print("MainNavigation: Rol efectivo determinado: $effectiveRole");

        // Construir listas de pantallas y navBarItems basadas en el rol
        final List<Widget> screensToShow = _buildScreens(effectiveRole);
        final List<BottomNavigationBarItem> navBarItems = _buildNavBarItems(effectiveRole);

        // Ajustar _selectedIndex si después de un cambio de rol queda fuera de rango
        // Esto se hace después de que las listas `screensToShow` y `navBarItems` se hayan generado
        // con el rol actual, para asegurar que el índice sea válido para ellas.
        int validatedSelectedIndex = _selectedIndex;
        if (screensToShow.isNotEmpty) {
          if (validatedSelectedIndex >= screensToShow.length || validatedSelectedIndex < 0) {
            print("MainNavigation: Índice seleccionado ($validatedSelectedIndex) fuera de rango para ${screensToShow.length} pantallas. Reiniciando a 0.");
            validatedSelectedIndex = 0; // Ir a la primera pestaña si está fuera de rango
            // Programar la actualización del estado para después del frame actual
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedIndex != validatedSelectedIndex) { // Comprobar si realmente necesita cambiar
                setState(() {
                  _selectedIndex = validatedSelectedIndex;
                });
              }
            });
          }
        } else {
          // Si no hay pantallas, el índice debería ser 0 (aunque no se mostrará nada)
          // Esto es más un caso de borde, usualmente siempre habrá al menos Perfil o Explorar.
          if (validatedSelectedIndex != 0) {
            validatedSelectedIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedIndex != validatedSelectedIndex) {
                setState(() {
                  _selectedIndex = validatedSelectedIndex;
                });
              }
            });
          }
        }


        return Scaffold(
          body: (screensToShow.isEmpty)
              ? const Center(child: Text("Cargando interfaz...")) // Placeholder si no hay pantallas
              : IndexedStack(
            // Usar el índice validado
            index: (validatedSelectedIndex >=0 && validatedSelectedIndex < screensToShow.length) ? validatedSelectedIndex : 0,
            children: screensToShow,
          ),
          bottomNavigationBar: (navBarItems.isEmpty)
              ? null
              : Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: const Color(0xFFE67E22), width: 1.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, -1),
                )
              ],
            ),
            child: BottomNavigationBar(
              // Usar el índice validado
              currentIndex: (validatedSelectedIndex >=0 && validatedSelectedIndex < navBarItems.length) ? validatedSelectedIndex : 0,
              onTap: _onItemTapped, // Simplificado, ya no necesita pasar screensToShow
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFFE67E22),
              unselectedItemColor: const Color(0xFF757575),
              backgroundColor: Colors.white,
              elevation: 0, // La elevación ya está en el Container por la sombra
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: navBarItems,
            ),
          ),
        );
      },
    );
  }
}
