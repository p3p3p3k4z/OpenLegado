import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importa la pantalla de inicio de sesión.
import 'register_screen.dart'; // Importa la pantalla de registro.
import 'main_navigation.dart'; // Importa la navegación principal.

/// Pantalla de bienvenida inicial de la aplicación.
/// Ofrece opciones para iniciar sesión, registrarse o continuar como invitado.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key}); // Constructor constante.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        // Gradiente de fondo para la pantalla.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF8DC), // Beige suave.
              Color(0xFFF5E6D3), // Beige más oscuro.
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea( // Asegura que el contenido no se superponga con la barra de estado/notch.
          child: Padding(
            padding: const EdgeInsets.all(32), // Padding general para el contenido.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centra los elementos verticalmente.
              children: [
                const Spacer(flex: 2), // Espaciador flexible para empujar el logo hacia arriba.

                // Logo y marca de la aplicación.
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513), // Marrón Tierra.
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ClipOval( // Recorta la imagen en forma ovalada.
                      child: Image.asset(
                        'assets/legado.jpg', // Imagen del logo.
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        // `errorBuilder` para mostrar un icono si la imagen falla.
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.temple_hindu, // Icono de fallback.
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Título "LEGADO".
                const Text(
                  'LEGADO',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtítulo descriptivo.
                const Text(
                  'Descubre la cultura que\nno está en los mapas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),

                const Spacer(flex: 3), // Espaciador flexible para empujar los botones hacia abajo.

                // Sección de botones de acción.
                Column(
                  children: [
                    const Text(
                      'Selecciona una opción:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8B4513),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón "Iniciar Sesión".
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navega a la pantalla de inicio de sesión.
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B4513), // Marrón Tierra.
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón "Registrarse".
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          // Navega a la pantalla de registro.
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B4513),
                          side: const BorderSide(
                            color: Color(0xFF8B4513),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón "Continuar como Invitado".
                    TextButton(
                      onPressed: () {
                        // Navega a la navegación principal, reemplazando la ruta actual.
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MainNavigation()),
                        );
                      },
                      child: const Text(
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

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
