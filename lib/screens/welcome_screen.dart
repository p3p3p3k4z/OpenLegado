import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importa la pantalla de inicio de sesión.
import 'register_screen.dart'; // Importa la pantalla de registro.
import 'main_navigation.dart'; // Importa la navegación principal.

/// Pantalla de bienvenida inicial de la aplicación.
/// Ofrece opciones para iniciar sesión, registrarse o continuar como invitado.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key}); // Constructor constante.

  static const Color fondoColor = Color(0xFFFFF0E0);
  static const Color marron = Color(0xFF992E08);
  static const Color textoOscuro = Color(0xFF311F14);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),

              // Logo con imagen
              Image.asset(
                'assets/legado_logo_transparente.png',
                width: 275,
                height: 128,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 18),

              
              const SizedBox(height: 12),
              
              // Subtítulo
              Text(
                'Descubre la cultura que\nno está en los mapas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: textoOscuro,
                  height: 1.2,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 150),

              // Texto superior de opciones
              Text(
                'Selecciona una opción:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textoOscuro,
                  fontFamily: 'Montserrat',
                ),
              ),

              const SizedBox(height: 20),

              // Botón "Iniciar Sesión"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: marron,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón "Registrarse"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF992E08),
                    side: BorderSide(color: Color(0xFF992E08), width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Registrarse',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // "Continuar como invitado"
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainNavigation()),
                  );
                },
                child: Text(
                  'Continuar como invitado',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF992E08),
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}