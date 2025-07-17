import 'package:flutter/material.dart';
import 'interests_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo pequeño
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Color(0xFF8B4513),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: ClipOval(
                          child: Image.asset(
                            'assets/legado.jpg',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.temple_hindu,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  Center(
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
                  
                  SizedBox(height: 8),
                  
                  Center(
                    child: Text(
                      'Descubre la cultura que\nno está en los mapas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Nombre de usuario
                  _buildLabel('Nombre de usuario'),
                  SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Ingresa tu nombre completo',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu nombre';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Correo electrónico
                  _buildLabel('Correo electrónico'),
                  SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Ingresa tu correo',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
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
                  
                  SizedBox(height: 16),
                  
                  // Contraseña
                  _buildLabel('Contraseña'),
                  SizedBox(height: 8),
                  _buildPasswordField(
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
                  
                  SizedBox(height: 16),
                  
                  // Confirmar contraseña
                  _buildLabel('Confirma contraseña'),
                  SizedBox(height: 8),
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
                  
                  SizedBox(height: 32),
                  
                  // Botón de registro
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Navegar a la pantalla de intereses
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => InterestsScreen()),
                          );
                        }
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
                        'Registrarme',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Enlaces adicionales
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '¿Ya tienes una cuenta? ',
                          style: TextStyle(color: Color(0xFF5D4037)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => LoginScreen()),
                            );
                          },
                          child: Text(
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
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B4513),
      ),
    );
  }

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
        suffixIcon: Icon(icon, color: Color(0xFF8B4513)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFE67E22), width: 2),
        ),
      ),
      validator: validator,
    );
  }

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
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Color(0xFF8B4513),
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFE67E22), width: 2),
        ),
      ),
      validator: validator,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
