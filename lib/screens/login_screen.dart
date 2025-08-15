import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Authentication
import 'main_navigation.dart';
import 'register_screen.dart';

/// Pantalla de inicio de sesión de la aplicación.
/// Permite a los usuarios ingresar sus credenciales para acceder utilizando Firebase Authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false; // Nuevo estado para controlar el indicador de carga

  /// Maneja el proceso de inicio de sesión con Firebase Authentication.
  ///
  /// Punto de complejidad:
  /// Esta función interactúa directamente con el servicio de autenticación de Firebase.
  /// Es crucial manejar los posibles errores que pueden ocurrir durante el inicio de sesión,
  /// como credenciales inválidas, usuario no encontrado, o problemas de red.
  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Muestra el indicador de carga
      });
      try {
        // Intenta iniciar sesión con el correo y la contraseña proporcionados.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Si el inicio de sesión es exitoso, navega a la pantalla principal.
        // `pushReplacement` evita que el usuario pueda regresar a la pantalla de login con el botón de atrás.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } on FirebaseAuthException catch (e) {
        // Captura excepciones específicas de Firebase Authentication.
        String message;
        if (e.code == 'user-not-found') {
          message = 'No se encontró un usuario con ese correo.';
        } else if (e.code == 'wrong-password') {
          message = 'Contraseña incorrecta.';
        } else if (e.code == 'invalid-email') {
          message = 'El formato del correo electrónico es inválido.';
        } else {
          message = 'Error al iniciar sesión: ${e.message}';
        }
        _showSnackBar(message, Colors.red); // Muestra un mensaje de error.
      } catch (e) {
        // Captura cualquier otra excepción inesperada.
        _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
      } finally {
        setState(() {
          _isLoading = false; // Oculta el indicador de carga
        });
      }
    }
  }

  /// Muestra un SnackBar con un mensaje y un color de fondo.
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFFFF0E0),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFFF0E0),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF3E2723)),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      "assets/legado_logo_transparente.png", // ¡Pon aquí tu ícono/logo!
                      height: 96,
                      width: 206,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Descubre la cultura que no\nestá en los mapas",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: const Color(0xFF311F14),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
              Text(
                'Correo electrónico:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ingresa tu correo',
                  hintStyle: TextStyle(color: Colors.black38),
                  suffixIcon: const Icon(Icons.email_outlined, color: Color(0xFF952E07)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF952E07), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu correo';
                  }
                  if (!value.contains('@')) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Contraseña:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Ingresa tu contraseña',
                  hintStyle: TextStyle(color: Colors.black38),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF952E07),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF952E07), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu contraseña';
                  }
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF952E07),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: const Color(0xFF333333),
                      fontSize: 15,
                    ),
                    children: [
                      const TextSpan(text: "¿No tienes una cuenta? "),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                          },
                          child: Text(
                            "Regístrate",
                            style: TextStyle(
                              color: const Color(0xFF952E07),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
  );
}


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}