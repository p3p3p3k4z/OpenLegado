import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/experience.dart';
import 'experience_detail_screen.dart';

/// Pantalla de búsqueda y filtros avanzados para experiencias.
class SearchAndFilterScreen extends StatefulWidget {
  const SearchAndFilterScreen({super.key});

  @override
  State<SearchAndFilterScreen> createState() => _SearchAndFilterScreenState();
}

class _SearchAndFilterScreenState extends State<SearchAndFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _selectedCategory = 'Todas';
  double _minPrice = 0;
  double _maxPrice = 10000;
  double _minRating = 0.0;
  String? _selectedDuration;

  final List<String> _categories = [
    'Todas',
    'Gastronomía',
    'Arte y Artesanía',
    'Patrimonio',
    'Naturaleza y Aventura',
    'Música y Danza',
    'Bienestar',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Construye la consulta de Firestore basada en los filtros y la búsqueda.
  Stream<QuerySnapshot> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('experiences');

    // Filtrar por estado 'approved'
    query = query.where('status', isEqualTo: 'approved');

    // Filtrar por categoría
    if (_selectedCategory != 'Todas') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Filtrar por rango de precio (precio >= minPrice y precio <= maxPrice)
    query = query.where('price', isGreaterThanOrEqualTo: _minPrice);
    query = query.where('price', isLessThanOrEqualTo: _maxPrice);

    // Filtrar por rating
    if (_minRating > 0) {
      query = query.where('rating', isGreaterThanOrEqualTo: _minRating);
    }

    // Filtrar por texto de búsqueda (opcional, requiere indexación de Firestore)
    // Para simplificar, haremos un filtrado local, ya que la búsqueda 'contains'
    // en Firestore no es escalable.
    // Una implementación más avanzada usaría una herramienta como Algolia o Elastic Search.

    return query.snapshots();
  }

  /// Muestra un modal con opciones de filtrado.
  Future<void> _showFilterModal() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Filtros Avanzados',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Categoría', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8.0,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE67E22),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        onSelected: (selected) {
                          modalSetState(() {
                            _selectedCategory = category;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Rango de Precio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  RangeSlider(
                    values: RangeValues(_minPrice, _maxPrice),
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels('\$${_minPrice.round()}', '\$${_maxPrice.round()}'),
                    activeColor: const Color(0xFFE67E22),
                    onChanged: (RangeValues newValues) {
                      modalSetState(() {
                        _minPrice = newValues.start.roundToDouble();
                        _maxPrice = newValues.end.roundToDouble();
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'category': _selectedCategory,
                          'minPrice': _minPrice,
                          'maxPrice': _maxPrice,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67E22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Aplicar Filtros'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result['category'];
        _minPrice = result['minPrice'];
        _maxPrice = result['maxPrice'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Experiencias', style: TextStyle(color: Color(0xFF5D4037))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF5D4037)),
            onPressed: _showFilterModal,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por título o artesano...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE67E22)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar los resultados.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No se encontraron experiencias con estos criterios.'));
                }

                // Filtrado local por texto de búsqueda (si no se usa una herramienta externa)
                final experiences = snapshot.data!.docs.map((doc) => Experience.fromFirestore(doc)).toList();
                final filteredExperiences = experiences.where((exp) {
                  final lowerCaseQuery = _searchText.toLowerCase();
                  return exp.title.toLowerCase().contains(lowerCaseQuery) ||
                      exp.artisanName.toLowerCase().contains(lowerCaseQuery) ||
                      _searchText.isEmpty;
                }).toList();

                if (filteredExperiences.isEmpty) {
                  return const Center(child: Text('No se encontraron experiencias que coincidan con la búsqueda.'));
                }

                return ListView.builder(
                  itemCount: filteredExperiences.length,
                  itemBuilder: (context, index) {
                    final experience = filteredExperiences[index];
                    return _buildExperienceCard(experience);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta de experiencia para la lista de resultados.
  Widget _buildExperienceCard(Experience experience) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExperienceDetailScreen(experience: experience),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  experience.imageAsset,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 100),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.location,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${experience.price.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE67E22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
