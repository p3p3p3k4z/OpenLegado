import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import '../models/experience.dart';
import 'experience_detail_screen.dart';

/// Pantalla principal que muestra una lista de experiencias culturales.
/// Permite filtrar las experiencias por categoría, cargándolas desde Firestore.
class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  _ExperiencesScreenState createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  String _selectedCategory = 'Todas'; // Categoría seleccionada actualmente.
  // No necesitamos una lista local _experiences, usaremos FutureBuilder/StreamBuilder.

  // Lista estática de categorías (pueden cargarse desde Firestore si hay una colección de categorías).
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
    // No es necesario _loadExperiences() aquí si usamos StreamBuilder/FutureBuilder directamente.
  }

  /// Obtiene un Stream de experiencias desde Firestore, filtrado por categoría.
  ///
  /// Punto de complejidad:
  /// Las consultas a Firestore son asíncronas. El uso de `snapshots()`
  /// proporciona actualizaciones en tiempo real, lo que es muy potente pero
  /// requiere manejar los estados de carga, datos y error.
  Stream<List<Experience>> _getExperiencesStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('experiences');

    if (_selectedCategory != 'Todas') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Ordenar las experiencias (opcional, pero mejora la presentación).
    // Nota: Si ordenas por un campo que no es el ID del documento,
    // Firestore puede requerir la creación de un índice compuesto.
    query = query.orderBy('title', descending: false);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Experience.fromFirestore(doc)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
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
            icon: const Icon(Icons.filter_list, color: Color(0xFFE67E22)),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sección de filtros rápidos (chips horizontales).
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildFilterChip(category, _selectedCategory == category);
              },
            ),
          ),

          // Lista de experiencias (ocupa el espacio restante).
          // StreamBuilder escucha los cambios en el stream de experiencias.
          Expanded(
            child: StreamBuilder<List<Experience>>(
              stream: _getExperiencesStream(), // Usa el stream de Firestore.
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator()); // Muestra carga.
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar experiencias: ${snapshot.error}')); // Muestra error.
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay experiencias disponibles.')); // No hay datos.
                }

                final experiences = snapshot.data!; // Las experiencias obtenidas.

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: experiences.length,
                  itemBuilder: (context, index) {
                    return _buildExperienceCard(experiences[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un widget `FilterChip` para la selección de categorías.
  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8B4513),
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (value) {
          setState(() {
            _selectedCategory = label; // Actualiza la categoría seleccionada.
            // No es necesario llamar a _loadExperiences() explícitamente,
            // StreamBuilder se encargará de reconstruir con el nuevo filtro.
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: const Color(0xFFE67E22),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFFE67E22) : Colors.grey[300]!,
        ),
      ),
    );
  }

  /// Construye una tarjeta de experiencia para la lista.
  Widget _buildExperienceCard(Experience experience) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              // Sección de imagen de la tarjeta.
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        experience.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
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
                    // Badge "Verificado" si la experiencia lo es.
                    if (experience.isVerified)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
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

              // Contenido de texto de la tarjeta.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE67E22).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  experience.duration,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFE67E22),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 12,
                                color: Color(0xFF8D6E63),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  experience.location,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8D6E63),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 12, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(
                                    experience.rating.toString(),
                                    style: const TextStyle(
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

                      // Precio y botón "Ver más".
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${experience.price} MXN',
                            style: const TextStyle(
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
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(70, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
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

  /// Devuelve un icono de Material Design basado en el nombre de la categoría.
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

  /// Muestra un BottomSheet con opciones de filtro para las experiencias.
  /// Ahora el BottomSheet es interactivo y actualiza la categoría seleccionada.
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // StatefulBuilder permite que el BottomSheet tenga su propio estado.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            String tempSelectedCategory = _selectedCategory; // Estado temporal para el modal.

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrar experiencias',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Categorías',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((category) => FilterChip(
                      label: Text(category),
                      selected: tempSelectedCategory == category, // Usa el estado temporal.
                      onSelected: (value) {
                        setModalState(() { // Actualiza el estado del modal.
                          tempSelectedCategory = category;
                        });
                      },
                      backgroundColor: Colors.grey[100],
                      selectedColor: const Color(0xFFE67E22),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: tempSelectedCategory == category ? const Color(0xFFE67E22) : Colors.grey[300]!,
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Al aplicar, actualiza el estado de la pantalla principal y cierra el modal.
                            setState(() {
                              _selectedCategory = tempSelectedCategory;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE67E22),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
