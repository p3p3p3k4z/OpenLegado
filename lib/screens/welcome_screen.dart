import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'main_navigation.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF8DC),
              Color(0xFFF5E6D3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(flex: 2),
                
                // Logo y marca
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Color(0xFF8B4513),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ClipOval(
                      child: Image.asset(
                        'assets/legado.jpg',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.temple_hindu,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 32),
                
                Text(
                  'LEGADO',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                    letterSpacing: 4,
                  ),
                ),
                
                SizedBox(height: 16),
                
                Text(
                  'Descubre la cultura que\nno está en los mapas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),
                
                Spacer(flex: 3),
                
                // Botones de acción
                Column(
                  children: [
                    Text(
                      'Selecciona una opción:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8B4513),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Botón Iniciar Sesión
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8B4513),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Botón Registrarse
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RegisterScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF8B4513),
                          side: BorderSide(
                            color: Color(0xFF8B4513),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Registrarse',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Botón Continuar como Invitado
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MainNavigation()),
                        );
                      },
                      child: Text(
                        'Continuar como Invitado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF8B4513),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
