import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';     // Importa Firebase Auth para obtener el usuario
import 'main_navigation.dart';

/// Pantalla de selección de intereses del usuario.
/// Permite al usuario elegir categorías de interés que luego podrían usarse para personalizar contenido.
/// Los intereses seleccionados se guardan en Firebase Firestore.
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  _InterestsScreenState createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  // Lista mutable de mapas que representan los intereses.
  // Cada mapa contiene 'title', 'icon' y 'selected' (estado de selección).
  final List<Map<String, dynamic>> _interests = [
    {
      'title': 'Gastronomía',
      'icon': Icons.restaurant,
      'selected': false,
    },
    {
      'title': 'Arte y\nArtesanía',
      'icon': Icons.palette,
      'selected': false,
    },
    {
      'title': 'Patrimonio',
      'icon': Icons.account_balance,
      'selected': false,
    },
    {
      'title': 'Naturaleza y\nAventura',
      'icon': Icons.terrain,
      'selected': false,
    },
    {
      'title': 'Música y\nDanza',
      'icon': Icons.music_note,
      'selected': false,
    },
    {
      'title': 'Bienestar',
      'icon': Icons.spa,
      'selected': false,
    },
  ];

  bool _isLoading = false; // Nuevo estado para controlar el indicador de carga

  /// Guarda los intereses seleccionados del usuario en Firebase Firestore.
  ///
  /// Punto de complejidad:
  /// Esta función realiza una operación de escritura en la base de datos.
  /// Es importante manejar:
  /// 1. La obtención del UID del usuario actual.
  /// 2. La interacción con la colección 'users' en Firestore.
  /// 3. Posibles errores durante la escritura (ej. problemas de red, permisos).
  Future<void> _saveInterests() async {
    final user = FirebaseAuth.instance.currentUser; // Obtiene el usuario actualmente autenticado.
    if (user == null) {
      // Si no hay usuario autenticado (lo cual no debería pasar si el flujo es correcto),
      // redirige al login o muestra un error.
      _showSnackBar('No hay usuario autenticado para guardar intereses.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true; // Muestra el indicador de carga.
    });

    try {
      final selectedInterests = _getSelectedInterests(); // Obtiene la lista de títulos de intereses.

      // Accede a la colección 'users' y al documento con el UID del usuario.
      // Si el documento no existe, Firestore lo creará.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'interests': selectedInterests, // Guarda la lista de intereses.
          'lastInterestUpdate': FieldValue.serverTimestamp(), // Marca la fecha de la última actualización.
          // Puedes añadir otros campos iniciales del usuario aquí si no lo hiciste en el registro.
          // 'email': user.email,
          // 'username': _nameController.text.trim(), // Si tuvieras el nombre aquí.
        },
        SetOptions(merge: true), // Usa merge: true para no sobrescribir otros campos si ya existen.
      );

      _showSnackBar('Intereses guardados exitosamente!', Colors.green);

      // Navega a la navegación principal una vez que los intereses se han guardado.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );
    } on FirebaseException catch (e) {
      // Captura excepciones específicas de Firebase Firestore.
      _showSnackBar('Error al guardar intereses: ${e.message}', Colors.red);
    } catch (e) {
      // Captura cualquier otra excepción inesperada.
      _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false; // Oculta el indicador de carga.
      });
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
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),

                const Text(
                  '¿Cuáles son\ntus intereses?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 48),

                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _interests.length,
                    itemBuilder: (context, index) {
                      return _buildInterestCard(index);
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Botón "Continuar".
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    // El botón está deshabilitado si no se ha seleccionado ningún interés o si está cargando.
                    onPressed: _isLoading || _getSelectedInterests().isEmpty
                        ? null
                        : _saveInterests, // Llama a la nueva función para guardar intereses.
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading // Muestra un CircularProgressIndicator si está cargando.
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Puedes cambiar tus intereses más tarde\nen tu perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye una tarjeta individual para la selección de intereses.
  /// [index]: El índice del interés en la lista `_interests`.
  Widget _buildInterestCard(int index) {
    final interest = _interests[index];
    final isSelected = interest['selected'] as bool;

    return GestureDetector(
      onTap: () {
        setState(() {
          _interests[index]['selected'] = !isSelected;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE67E22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFE67E22) : const Color(0xFFE0E0E0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFE67E22).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                interest['icon'] as IconData,
                size: 30,
                color: isSelected ? Colors.white : const Color(0xFFE67E22),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              interest['title'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF5D4037),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Obtiene una lista de los títulos de los intereses seleccionados.
  List<String> _getSelectedInterests() {
    return _interests
        .where((interest) => interest['selected'] as bool)
        .map((interest) => interest['title'] as String)
        .toList();
  }
}
