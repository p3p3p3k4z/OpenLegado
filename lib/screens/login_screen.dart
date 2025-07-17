import 'package:flutter/material.dart';
import 'main_navigation.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

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
          child: Padding(
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
                  
                  SizedBox(height: 48),
                  
                  // Campos del formulario
                  Text(
                    'Correo electrónico:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Ingresa tu correo',
                      suffixIcon: Icon(Icons.email_outlined, color: Color(0xFF8B4513)),
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
                  
                  SizedBox(height: 24),
                  
                  Text(
                    'Contraseña:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Ingresa tu contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Color(0xFF8B4513),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                  
                  SizedBox(height: 32),
                  
                  // Botón de inicio de sesión
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // TODO: Implementar autenticación real
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => MainNavigation()),
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
                        'Iniciar Sesión',
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
                          '¿No tienes una cuenta? ',
                          style: TextStyle(color: Color(0xFF5D4037)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => RegisterScreen()),
                            );
                          },
                          child: Text(
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
                  
                  Spacer(),
                ],
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
