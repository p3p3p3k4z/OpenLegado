import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  _InterestsScreenState createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final List<Map<String, dynamic>> _interests = [
    {
      'title': 'Gastronomía',
      'icon': Icons.restaurant,
      'selected': false,
    },
    {
      'title': 'Arte y Artesania',
      'icon': Icons.emoji_objects, // cambia por uno más "artesanal"
      'selected': false,
    },
    {
      'title': 'Historia y Patrimonio',
      'icon': Icons.account_balance,
      'selected': false,
    },
    {
      'title': 'Naturaleza y Aventura',
      'icon': Icons.terrain,
      'selected': false,
    },
    {
      'title': 'Música y Danza',
      'icon': Icons.music_note,
      'selected': false,
    },
    {
      'title': 'Bienestar',
      'icon': Icons.spa,
      'selected': false,
    },
  ];

  bool _isLoading = false;

  Future<void> _saveInterests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('No hay usuario autenticado para guardar intereses.', Colors.red);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final selectedInterests = _getSelectedInterests();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'interests': selectedInterests,
          'lastInterestUpdate': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _showSnackBar('Intereses guardados exitosamente!', Colors.green);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );
    } on FirebaseException catch (e) {
      _showSnackBar('Error al guardar intereses: ${e.message}', Colors.red);
    } catch (e) {
      _showSnackBar('Ocurrió un error inesperado: $e', Colors.red);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

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
      backgroundColor: kColorFondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              Text(
                '¿Cuáles son\ntus intereses?',
                textAlign: TextAlign.left,
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kColorTexto,
                  height: 1.1,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 45),
              Expanded(
                child: GridView.builder(
                  itemCount: _interests.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (context, index) {
                    return _buildInterestCard(index);
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading || _getSelectedInterests().isEmpty
                      ? null
                      : _saveInterests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF952E07),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '                Puedes cambiarlos más tarde en tu perfil',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: kColorGris,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestCard(int index) {
    final interest = _interests[index];
    final isSelected = interest['selected'] as bool;

    return GestureDetector(
      onTap: () {
        setState(() {
          _interests[index]['selected'] = !isSelected;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isSelected ? kColorSeleccion : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF4E1E0A),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                interest['icon'] as IconData,
                size: 60,
                color:  kColorTexto,
              ),
              const SizedBox(height: 11),
              Text(
                interest['title'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kColorTexto,
                  height: 1.15,
                  fontFamily: 'Nunito'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getSelectedInterests() {
    return _interests
        .where((interest) => interest['selected'] as bool)
        .map((interest) => interest['title'] as String)
        .toList();
  }
}

// Colores
const kColorFondo = Color(0xFFFFF0E0);
const kColorSeleccion = Color(0xFFCC7163);
const kColorTexto = Color(0xFF311F14);
const kColorGris = Color(0xFF8D6E63);