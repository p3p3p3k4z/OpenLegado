import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para Firestore
import '../models/user.dart'; // Asegúrate que la ruta a tu modelo AppUser es correcta
import 'interests_screen.dart';
import 'login_screen.dart';

/// Pantalla de registro de nuevos usuarios.
/// Permite a los usuarios crear una nueva cuenta utilizando Firebase Authentication
/// y guarda la información básica en Firestore.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // CAMBIO: de _nameController a _usernameController y su etiqueta
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Instancias de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Maneja el proceso de registro de usuario con Firebase Authentication
  /// y crea el documento de usuario en Firestore.
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return; // Si el formulario no es válido, no continuar
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Crear usuario en Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // 2. Actualizar el displayName en Firebase Auth (opcional pero recomendado)
        // Usamos el username para el displayName también
        await firebaseUser.updateDisplayName(_usernameController.text.trim());

        // 3. Crear el objeto AppUser con la información y el rol por defecto
        AppUser newUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '', // Usar el email de Firebase Auth
          username: _usernameController.text.trim(), // Usar 'username' y el _usernameController
          role: 'user', // ROL POR DEFECTO CONSISTENTE (en minúsculas)
          profileImageUrl: null, // Se puede dejar null o definir un avatar por defecto
          interests: [], // Inicializar como lista vacía
          savedExperiences: [], // Inicializar como lista vacía
          experiencesSubmitted: 0, // Valor inicial
          communitiesSupported: 0, // Valor inicial para nuevos campos
          artisansMet: 0, // Valor inicial para nuevos campos
          createdAt: DateTime.now(), // Timestamp de creación
        );

        // 4. Guardar el nuevo usuario en la colección 'users' de Firestore
        // El método toMap() debe estar definido en tu modelo AppUser
        // y debe manejar todos los campos, incluyendo los nuevos.
        await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap(forCreation: true));

        if (mounted) {
          _showSnackBar('¡Registro exitoso!', Colors.green);
          // Navega a la pantalla de intereses después de un registro exitoso.
          // `pushReplacement` evita que el usuario regrese a la pantalla de registro.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const InterestsScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        message = 'Ya existe una cuenta con ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      } else {
        message = 'Error al registrarse: ${e.message}';
        print("Error FirebaseAuth: ${e.code} - ${e.message}");
      }
      if (mounted) _showSnackBar(message, Colors.red);
    } catch (e) {
      if (mounted) _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
      print("Error inesperado creando usuario en Firestore o similar: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            'assets/legado.jpg', // Asegúrate que este asset exista
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
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
                  const SizedBox(height: 32),

                  _buildLabel('Nombre de usuario'), // Etiqueta actualizada
                  const SizedBox(height: 8),
                  _buildTextField( // Usando la misma función _buildTextField que ya tenías
                    controller: _usernameController, // Controlador actualizado
                    hintText: 'Ingresa tu nombre de usuario', // Hint actualizado
                    icon: Icons.person_outline, // Icono (el original usa suffixIcon, ajustado abajo)
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu nombre de usuario';
                      }
                      if (value.length < 3) {
                        return 'El nombre de usuario debe tener al menos 3 caracteres';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildLabel('Correo electrónico'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Ingresa tu correo',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu correo';
                      }
                      // Una regex más común para emails
                      final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$");
                      if (!emailRegex.hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildLabel('Contraseña'),
                  const SizedBox(height: 8),
                  _buildPasswordField( // Usando la misma función _buildPasswordField que ya tenías
                    controller: _passwordController,
                    hintText: 'Crea una contraseña',
                    obscureText: _obscurePassword,
                    onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa una contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildLabel('Confirma contraseña'),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirma tu contraseña',
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor confirma tu contraseña';
                      }
                      if (value != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox( // Para un CircularProgressIndicator más centrado y de tamaño fijo
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                          : const Text(
                        'Registrarme',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Row( // Usar Row para alinear "Ya tienes cuenta?" y "Inicia Sesión"
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes una cuenta? ',
                          style: TextStyle(color: Color(0xFF5D4037)),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : () { // Deshabilitar si está cargando
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          style: TextButton.styleFrom( // Estilos para mejor apariencia
                            padding: const EdgeInsets.symmetric(horizontal: 4.0), // Menos padding
                            minimumSize: const Size(50, 30), // Área táctil mínima
                          ),
                          child: const Text(
                            'Inicia Sesión',
                            style: TextStyle(
                              color: Color(0xFFE67E22),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B4513),
      ),
    );
  }

  // Modificado para usar prefixIcon como lo hacías en la versión más reciente
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF8B4513)), // CAMBIO: prefixIcon
        filled: true,
        fillColor: Colors.white.withOpacity(0.9), // Ligera transparencia
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Sin borde por defecto
        ),
        enabledBorder: OutlineInputBorder( // Borde sutil cuando está habilitado
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.brown.shade200.withOpacity(0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
        ),
        errorBorder: OutlineInputBorder( // Borde para errores
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder( // Borde para errores cuando está enfocado
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction, // Validar mientras el usuario escribe
    );
  }

  // Modificado para que el icono de visibilidad sea consistente
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8B4513)), // Icono de candado
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, // Iconos con borde
            color: const Color(0xFF8B4513).withOpacity(0.7),
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.brown.shade200.withOpacity(0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose(); // CAMBIO: Asegurarse que es _usernameController
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
