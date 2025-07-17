import 'package:flutter/material.dart';
import 'explore_screen.dart';
import 'experiences_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    ExploreScreen(),
    ExperiencesScreen(), 
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0xFFE67E22), 
              width: 2
            )
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Color(0xFFE67E22),
          unselectedItemColor: Color(0xFF8D6E63),
          backgroundColor: Colors.white,
          elevation: 8,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              activeIcon: Icon(Icons.explore, size: 28),
              label: 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_day),
              activeIcon: Icon(Icons.calendar_view_day, size: 28),
              label: 'Experiencias',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              activeIcon: Icon(Icons.person, size: 28),
              label: 'Mi perfil',
            ),
          ],
        ),
      ),
    );
  }
}
