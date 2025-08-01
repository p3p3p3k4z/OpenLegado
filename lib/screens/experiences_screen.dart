import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Experiencias', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF8B4513),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterModal,
          ),
        ],
      ),
      // Uso de StreamBuilder para obtener actualizaciones en tiempo real.
      body: StreamBuilder<QuerySnapshot>(
        // La consulta a Firestore se construye dinámicamente.
        stream: _buildExperienceStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay experiencias disponibles.'));
          }

          // Se convierten los DocumentSnapshot a objetos Experience.
          final experiences = snapshot.data!.docs
              .map((doc) => Experience.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: experiences.length,
            itemBuilder: (context, index) {
              final experience = experiences[index];
              return _buildExperienceCard(experience);
            },
          );
        },
      ),
    );
  }

  /// Construye el stream de experiencias, aplicando el filtro de categoría.
  Stream<QuerySnapshot> _buildExperienceStream() {
    // Referencia a la colección 'experiences' en Firestore.
    final collection = FirebaseFirestore.instance.collection('experiences');

    // Comienza con una consulta base para las experiencias aprobadas.
    Query query = collection.where('status', isEqualTo: 'approved');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Si el usuario está autenticado, también se puede filtrar por experiencias favoritas o reservadas.
      // Aquí se podría añadir lógica más compleja.
    }

    // Aplica el filtro si la categoría no es 'Todas'.
    if (_selectedCategory != 'Todas') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Retorna el stream de la consulta.
    return query.snapshots();
  }

  /// Construye una tarjeta para mostrar una experiencia.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                experience.imageAsset,
                height: 200,
                fit: BoxFit.cover,
                // Manejo de errores de imagen
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${experience.rating}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF8D6E63)),
                      ),
                      const Spacer(),
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
                  const SizedBox(height: 8),
                  Text(
                    experience.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF8D6E63)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra un modal para que el usuario pueda seleccionar una categoría de filtro.
  void _showFilterModal() {
    String tempSelectedCategory = _selectedCategory;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtrar por Categoría',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _categories.map((category) => ChoiceChip(
                      label: Text(category),
                      selected: tempSelectedCategory == category,
                      selectedColor: const Color(0xFFE67E22),
                      labelStyle: TextStyle(
                        color: tempSelectedCategory == category ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      onSelected: (bool selected) {
                        modalState(() {
                          tempSelectedCategory = category;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: tempSelectedCategory == category ? const Color(0xFFE67E22) : Colors.grey[300]!,
                        ),
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
                            foregroundColor: Colors.white,
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
