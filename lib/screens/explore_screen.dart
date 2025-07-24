import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import '../models/experience.dart'; // Asegúrate de que tu modelo Experience esté actualizado
import 'experience_detail_screen.dart'; // Para navegar a los detalles de la experiencia

/// Pantalla de exploración que muestra un mapa interactivo (placeholder)
/// y experiencias destacadas, cargando estas últimas desde Firestore.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  /// Obtiene una experiencia destacada de Firestore.
  ///
  /// Punto de complejidad:
  /// Esta es una consulta única (no un stream) para obtener un documento.
  /// Necesita manejar el caso de que no se encuentre ninguna experiencia destacada.
  Future<Experience?> _getFeaturedExperience() async {
    try {
      // Busca experiencias que estén marcadas como destacadas.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('experiences')
          .where('isFeatured', isEqualTo: true)
          .limit(1) // Solo queremos una experiencia destacada.
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Si se encuentra una experiencia, la convierte a un objeto Experience.
        return Experience.fromFirestore(querySnapshot.docs.first);
      }
      return null; // No se encontró ninguna experiencia destacada.
    } catch (e) {
      print('Error al obtener experiencia destacada: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explorar',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFE67E22)),
            onPressed: () {
              // TODO: Implementar filtros para la pantalla de exploración.
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sección del mapa integrado (actualmente un placeholder visual).
          Container(
            height: 300,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  // Placeholder visual del mapa con gradiente.
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE67E22).withOpacity(0.8),
                          const Color(0xFF8B4513).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, size: 48, color: Colors.white70),
                          SizedBox(height: 8),
                          Text(
                            'Mapa Interactivo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Controles del mapa (placeholders).
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        _buildMapControl(Icons.list, () {}),
                        const SizedBox(height: 8),
                        _buildMapControl(Icons.sort, () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sección de experiencias destacadas.
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Experiencias Destacadas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // FutureBuilder para cargar la experiencia destacada.
                  FutureBuilder<Experience?>(
                    future: _getFeaturedExperience(), // Llama a la función asíncrona.
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator()); // Muestra carga.
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}')); // Muestra error.
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Center(child: Text('No se encontró experiencia destacada.')); // No hay datos.
                      }

                      final featuredExperience = snapshot.data!; // La experiencia destacada.
                      return _buildFeaturedExperienceCard(context, featuredExperience); // Construye la tarjeta.
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un botón de control para el mapa.
  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFFE67E22)),
        onPressed: onTap,
      ),
    );
  }

  /// Construye una tarjeta de experiencia destacada.
  /// Ahora recibe un objeto `Experience` para mostrar datos dinámicos.
  Widget _buildFeaturedExperienceCard(BuildContext context, Experience experience) {
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
              // Sección de imagen/icono de la tarjeta destacada.
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        experience.imageAsset, // Usa la imagen de la experiencia
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
                              _getIconForCategory(experience.category), // Icono basado en la categoría
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (experience.isVerified) // Muestra "Verificado" si lo es
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
              // Contenido de texto de la tarjeta destacada.
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title, // Título dinámico
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            experience.location, // Ubicación dinámica
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${experience.price} MXN', // Precio dinámico
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE67E22),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // Navega a la pantalla de detalles de la experiencia.
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExperienceDetailScreen(
                                    experience: experience, // Pasa el objeto experiencia.
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Ver más',
                              style: TextStyle(fontSize: 12),
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
}
