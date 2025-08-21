import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< AÑADIDO: Importar Firestore
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
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // 1. Autenticar con Firebase (tu código original)
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // <<< INICIO DE LA LÓGICA DE VERIFICACIÓN DE BANEO >>>
        User? firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          DocumentSnapshot userDoc;
          try {
            userDoc = await FirebaseFirestore.instance
                .collection('users') // Asume que tu colección se llama 'users'
                .doc(firebaseUser.uid)
                .get();
          } catch (firestoreError) {
            // Error al intentar obtener el documento de Firestore
            if (mounted) {
              _showSnackBar(
                  'Error al verificar estado de la cuenta. Inténtalo de nuevo.',
                  Colors.orange);
              // Considera cerrar sesión si la verificación falla críticamente
              // await FirebaseAuth.instance.signOut();
            }
            if (mounted) setState(() => _isLoading = false);
            return; // Detener el flujo si no se puede verificar
          }

          if (userDoc.exists) {
            // Asume que el campo se llama 'isDisabled' y es booleano
            // El '?? false' maneja el caso donde el campo no exista, tratándolo como no baneado.
            bool isDisabled = false;
            try {
              // Intenta obtener el campo 'isDisabled'.
              // Si el campo no existe, userDoc.get() podría devolver null o lanzar un error
              // dependiendo de la configuración de Firestore y si se usa data() vs get().
              // Usar data() y luego acceder al campo es más seguro para chequear existencia.
              Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
              if (userData != null && userData.containsKey('isDisabled')) {
                isDisabled = userData['isDisabled'] as bool? ?? false;
              }
              // Si 'isDisabled' no está en userData, se mantendrá en 'false' (no baneado).
            } catch (e) {
              // En caso de error al castear o acceder, asumir no baneado pero loguear.
              print("Advertencia: No se pudo leer 'isDisabled' para ${firebaseUser.uid}. Asumiendo no baneado. Error: $e");
              isDisabled = false; // Por seguridad o UX, decide si esto debería ser true.
            }


            if (isDisabled) {
              await FirebaseAuth.instance.signOut(); // Desloguear al usuario baneado
              if (mounted) {
                _showSnackBar(
                    'Tu cuenta ha sido suspendida. Por favor, contacta con soporte.',
                    Colors.red,
                    duration: const Duration(seconds: 5)); // SnackBar más largo
              }
            } else {
              // Usuario no baneado, proceder a la navegación
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainNavigation()),
                );
              }
            }
          } else {
            // El documento del usuario no existe en Firestore (estado inconsistente)
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              _showSnackBar(
                  'Perfil de usuario no encontrado. Contacta con soporte.',
                  Colors.orange);
            }
          }
        } else {
          // Esto no debería ocurrir si signInWithEmailAndPassword tuvo éxito sin lanzar excepción.
          // Pero por si acaso:
          if (mounted) {
            _showSnackBar('Error inesperado obteniendo datos de usuario.', Colors.red);
          }
        }
        // <<< FIN DE LA LÓGICA DE VERIFICACIÓN DE BANEO >>>

      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'user-not-found') {
          message = 'No se encontró un usuario con ese correo.';
        } else if (e.code == 'wrong-password') {
          message = 'Contraseña incorrecta.';
        } else if (e.code == 'invalid-email') {
          message = 'El formato del correo electrónico es inválido.';
        } else if (e.code == 'too-many-requests') {
          message = 'Demasiados intentos. Inténtalo más tarde.';
        } else if (e.code == 'network-request-failed') { // Añadido para errores de red
          message = 'Error de red. Verifica tu conexión.';
        }
        // No es necesario manejar 'user-disabled' de FirebaseAuthException aquí explícitamente
        // si tu lógica de 'isDisabled' en Firestore es la principal.
        else {
          message = 'Error al iniciar sesión. Inténtalo de nuevo.';
          // print('Firebase Auth Error: ${e.code} - ${e.message}');
        }
        if (mounted) {
          _showSnackBar(message, Colors.red);
        }
      } catch (e) {
        // Captura cualquier otra excepción inesperada.
        if (mounted) {
          _showSnackBar('Ocurrió un error inesperado.', Colors.red);
          // print('Unexpected Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Modificado para aceptar una duración opcional
  void _showSnackBar(String message, Color color, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... Tu código de build existente ...
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity, // Asegura que el Container ocupe toda la altura
        decoration: const BoxDecoration(
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
            padding: const EdgeInsets.symmetric(horizontal: 32), // Padding solo horizontal aquí
            // Envolver el Form con SingleChildScrollView
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32), // Padding vertical para el contenido scrolleable
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // Opcional: Centrar contenido si es más pequeño que la pantalla
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B4513),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: ClipOval(
                            child: Image.asset(
                              'assets/legado.jpg', // Asegúrate que esta imagen existe en tu pubspec.yaml y en la ruta
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.temple_hindu,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'LEGADO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Descubre la cultura que\nno está en los mapas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Correo electrónico:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Ingresa tu correo',
                        suffixIcon: const Icon(Icons.email_outlined,
                            color: Color(0xFF8B4513)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE67E22), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu correo';
                        }
                        if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                            .hasMatch(value)) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Contraseña:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Ingresa tu contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF8B4513),
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE67E22), width: 2),
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
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B4513),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Row( // Usar Row para alinear horizontalmente
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿No tienes una cuenta? ',
                            style: TextStyle(color: Color(0xFF5D4037)),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : () { // Deshabilitar si está cargando
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: const Text(
                              'Regístrate',
                              style: TextStyle(
                                color: Color(0xFFE67E22),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // const Spacer(), // Eliminado, no es ideal con SingleChildScrollView
                    // Si se necesita espacio al final, usar SizedBox
                    const SizedBox(height: 20), // Espacio opcional al final del contenido scrolleable
                  ],
                ),
              ),
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

