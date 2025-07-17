import 'package:flutter/material.dart';
import 'main_navigation.dart';

class InterestsScreen extends StatefulWidget {
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
              children: [
                SizedBox(height: 40),
                
                // Título
                Text(
                  '¿Cuáles son\ntus intereses?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                    height: 1.2,
                  ),
                ),
                
                SizedBox(height: 48),
                
                // Grid de intereses
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                
                SizedBox(height: 32),
                
                // Botón continuar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _getSelectedInterests().isNotEmpty 
                        ? () {
                            // TODO: Guardar intereses del usuario
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => MainNavigation()),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Texto informativo
                Text(
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
          color: isSelected ? Color(0xFFE67E22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFFE67E22) : Color(0xFFE0E0E0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
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
                    : Color(0xFFE67E22).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                interest['icon'] as IconData,
                size: 30,
                color: isSelected ? Colors.white : Color(0xFFE67E22),
              ),
            ),
            
            SizedBox(height: 12),
            
            Text(
              interest['title'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Color(0xFF5D4037),
                height: 1.2,
              ),
            ),
          ],
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
