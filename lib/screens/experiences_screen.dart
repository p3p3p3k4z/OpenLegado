import 'package:flutter/material.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';

class ExperiencesScreen extends StatefulWidget {
  @override
  _ExperiencesScreenState createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  String _selectedCategory = 'Todas';
  List<Experience> _experiences = [];

  @override
  void initState() {
    super.initState();
    _loadExperiences();
  }

  void _loadExperiences() {
    setState(() {
      _experiences = ExperienceData.getExperiencesByCategory(_selectedCategory);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Experiencias',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Color(0xFFE67E22)),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros rápidos
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ExperienceData.getCategories().length,
              itemBuilder: (context, index) {
                final category = ExperienceData.getCategories()[index];
                return _buildFilterChip(category, _selectedCategory == category);
              },
            ),
          ),
          
          // Lista de experiencias
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _experiences.length,
              itemBuilder: (context, index) {
                return _buildExperienceCard(_experiences[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: EdgeInsets.only(right: 12),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Color(0xFF8B4513),
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (value) {
          setState(() {
            _selectedCategory = label;
            _loadExperiences();
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Color(0xFFE67E22),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? Color(0xFFE67E22) : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildExperienceCard(Experience experience) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 120,
          color: Colors.white,
          child: Row(
            children: [
              // Imagen
              Container(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        experience.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFE67E22),
                                Color(0xFF8B4513),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _getIconForCategory(experience.category),
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (experience.isVerified)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Verificado',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Contenido
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  experience.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFFE67E22).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  experience.duration,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFE67E22),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: Color(0xFF8D6E63),
                              ),
                              SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  experience.location,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8D6E63),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 12, color: Colors.amber),
                                  SizedBox(width: 2),
                                  Text(
                                    experience.rating.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF8D6E63),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Precio y botón
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${experience.price} MXN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE67E22),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExperienceDetailScreen(
                                    experience: experience,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              minimumSize: Size(70, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Ver más',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Gastronomía':
        return Icons.restaurant;
      case 'Arte y Artesanía':
        return Icons.palette;
      case 'Patrimonio':
        return Icons.account_balance;
      case 'Naturaleza y Aventura':
        return Icons.terrain;
      case 'Música y Danza':
        return Icons.music_note;
      case 'Bienestar':
        return Icons.spa;
      default:
        return Icons.explore;
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtrar experiencias',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Categorías',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037),
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  'Gastronomía',
                  'Arte y Artesanía', 
                  'Patrimonio',
                  'Naturaleza y Aventura',
                  'Música y Danza',
                  'Bienestar'
                ].map((category) => FilterChip(
                  label: Text(category),
                  selected: false,
                  onSelected: (value) {},
                )).toList(),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE67E22),
                      ),
                      child: Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
