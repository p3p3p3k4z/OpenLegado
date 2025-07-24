import 'package:flutter/material.dart';
import 'explore_screen.dart'; // Importa la pantalla de exploración.
import 'experiences_screen.dart'; // Importa la pantalla de experiencias.
import 'profile_screen.dart'; // Importa la pantalla de perfil.

/// Widget principal que gestiona la navegación de nivel superior de la aplicación.
/// Utiliza un `BottomNavigationBar` para cambiar entre diferentes pantallas.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key}); // Constructor constante.

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Índice de la pestaña actualmente seleccionada en la barra de navegación inferior.
  int _selectedIndex = 0;

  // Lista de widgets (pantallas) que se mostrarán cuando se selecciona una pestaña.
  // Estas son las pantallas reales de la aplicación.
  final List<Widget> _screens = [
    const ExploreScreen(), // Pantalla de exploración.
    const ExperiencesScreen(), // Pantalla de lista de experiencias.
    const ProfileScreen(), // Pantalla de perfil de usuario.
    // TODO: Considerar añadir una cuarta pantalla si el BottomNavigationBar tiene 4 ítems.
    // Actualmente, el BottomNavigationBar tiene 4 ítems, pero _screens solo 3.
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Muestra la pantalla correspondiente al índice seleccionado.
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border( // Borde superior para la barra de navegación.
              top: BorderSide(
                  color: const Color(0xFFE67E22), // Naranja Principal.
                  width: 2
              )
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex, // El ítem actualmente seleccionado.
          onTap: (index) => setState(() => _selectedIndex = index), // Actualiza el índice al tocar.
          type: BottomNavigationBarType.fixed, // Asegura que todos los ítems se muestren con el mismo ancho.
          selectedItemColor: const Color(0xFFE67E22), // Color del ítem seleccionado.
          unselectedItemColor: const Color(0xFF8D6E63), // Color de los ítems no seleccionados.
          backgroundColor: Colors.white, // Fondo blanco para la barra.
          elevation: 8, // Sombra para la barra de navegación.
          items: const [ // Definición de los ítems de la barra de navegación.
            BottomNavigationBarItem(
              icon: Icon(Icons.explore), // Icono normal.
              activeIcon: Icon(Icons.explore, size: 28), // Icono más grande cuando está activo.
              label: 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_day), // Icono para experiencias (calendario).
              activeIcon: Icon(Icons.calendar_view_day, size: 28),
              label: 'Experiencias',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person), // Icono para perfil.
              activeIcon: Icon(Icons.person, size: 28),
              label: 'Mi perfil',
            ),
            // TODO: Si se desea una cuarta pantalla, añadir aquí el BottomNavigationBarItem correspondiente.
            // Por ejemplo:
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.map),
            //   activeIcon: Icon(Icons.map, size: 28),
            //   label: 'Mapa',
            // ),
          ],
        ),
      ),
    );
  }
}
