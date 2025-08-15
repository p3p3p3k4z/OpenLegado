import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart'; // Asegúrate que la ruta sea correcta
import 'experience_detail_screen.dart'; // Asegúrate que la ruta sea correcta

class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  _ExperiencesScreenState createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  String _selectedCategory = 'Todas';
  String _searchQuery = ''; // Para la búsqueda por nombre
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false; // Para controlar la visibilidad del TextField de búsqueda

  // Lista estática de categorías (pueden cargarse desde Firestore si hay una colección de categorías).
  // Si estas categorías también están en ExperienceData, podrías obtenerlas de ahí
  // para mantener una única fuente de verdad: final List<String> _categories = ExperienceData.getCategories();
  final List<String> _categories = [
    'Todas', 'Gastronomía', 'Arte y Artesanía', 'Patrimonio',
    'Naturaleza y Aventura', 'Música y Danza', 'Bienestar',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        // No es necesario llamar a setState aquí directamente si _getExperiencesStream no
        // depende directamente de _searchQuery para la consulta a Firestore.
        // El StreamBuilder se reconstruirá y el filtrado se aplicará en su builder.
        // Pero si quieres una reacción más explícita o tienes otros elementos UI
        // que dependen de _searchQuery fuera del StreamBuilder, puedes hacer setState aquí.
        // Por ahora, lo dejamos que el StreamBuilder maneje el re-renderizado.
        if (_searchQuery != _searchController.text) {
          setState(() { // setState para que el StreamBuilder pueda refiltrar
            _searchQuery = _searchController.text;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Experience>> _getExperiencesStream() {
    Query<Map<String, dynamic>> query =
    FirebaseFirestore.instance.collection('experiences');

    if (_selectedCategory != 'Todas') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Nota: Si ordenas por un campo y luego filtras por otro en el cliente (como el nombre),
    // el orden inicial podría no ser el final después del filtro de nombre.
    // Si la búsqueda por nombre es prioritaria, podrías considerar no ordenar aquí y
    // ordenar la lista filtrada en el cliente. O si Firestore lo permite, añadir
    // el orderBy del campo de búsqueda aquí también (requiere índices).
    query = query.orderBy('title', descending: false);

    return query.snapshots().map((snapshot) {
      // Mapeo inicial desde Firestore
      List<Experience> experiences = snapshot.docs
          .map((doc) => Experience.fromFirestore(doc))
          .toList();

      // El filtrado por nombre se aplicará en el builder del StreamBuilder
      // para que el StreamBuilder reaccione a cambios en _searchQuery.
      return experiences;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Buscar experiencia...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
          style: const TextStyle(color: Color.fromARGB(255, 38, 238, 75), fontSize: 16),
          // onChanged: (value) { // El listener ya se encarga de _searchQuery
          //   setState(() {
          //     _searchQuery = value;
          //   });
          // },
        )
            : const Text(
          'Experiencias',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
            
          ),
        ),
        backgroundColor: Colors.white,
        elevation: _isSearching ? 1 : 0, // Elevación sutil si se busca
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: const Color(0xFFE67E22)),
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear(); // Limpia el texto y _searchQuery via listener
                }
                _isSearching = !_isSearching;
                if (!_isSearching && _searchController.text.isNotEmpty) {
                  _searchController.clear();
                }
                // Si se activa la búsqueda, el autofocus del TextField debería funcionar
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Color(0xFFE67E22)), // Icono de tu versión
            tooltip: 'Filtrar',
            onPressed: () {
              // Si la búsqueda está activa, opcionalmente ciérrala
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  // _searchController.clear(); // Opcional: limpiar búsqueda al abrir filtros
                });
              }
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1.0))
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildFilterChip(category, _selectedCategory == category),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Experience>>(
              stream: _getExperiencesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE67E22)));
                }
                if (snapshot.hasError) {
                  print("Error en StreamBuilder: ${snapshot.error}");
                  return Center(
                      child: Text('Error al cargar experiencias: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade700)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty && _searchQuery.isEmpty && _selectedCategory == 'Todas') {
                  // Muestra "No hay experiencias" solo si no hay datos de origen y no hay filtros activos
                  return const Center(child: Text('No hay experiencias disponibles actualmente.'));
                }

                List<Experience> experiences = snapshot.data ?? [];

                // Aplicar filtro de búsqueda por nombre aquí, sobre los datos del Stream
                if (_searchQuery.isNotEmpty) {
                  String lowerCaseQuery = _searchQuery.toLowerCase().trim();
                  if (lowerCaseQuery.isNotEmpty) {
                    experiences = experiences.where((experience) {
                      return experience.title.toLowerCase().contains(lowerCaseQuery);
                    }).toList();
                  }
                }

                if (experiences.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 50, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No se encontraron experiencias que coincidan con tu búsqueda o filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

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

  Widget _buildFilterChip(String label, bool isSelected) {
    // Usando el estilo de tu versión estable con pequeñas mejoras
    return Container(
      margin: const EdgeInsets.only(right: 8), // Reducido el margen un poco
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8B4513),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, // Más contraste para seleccionado
          ),
        ),
        selected: isSelected,
        onSelected: (value) {
          setState(() {
            _selectedCategory = label;
            // El StreamBuilder se reconstruirá automáticamente porque _getExperiencesStream
            // usa _selectedCategory.
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: const Color(0xFFE67E22),
        checkmarkColor: Colors.white,
        elevation: isSelected ? 2.0 : 0.0, // Sutil elevación si está seleccionado
        side: isSelected
            ? BorderSide.none // Sin borde si está seleccionado
            : BorderSide(color: Colors.grey[350]!),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Ajuste de padding
      ),
    );
  }

  Widget _buildExperienceCard(Experience experience) {
    // Tomando como base tu _buildExperienceCard y aplicando los campos de tu modelo `Experience`
    // y algunas mejoras visuales que habíamos visto.
    return InkWell(
      onTap: () {
        if (_isSearching) {
          setState(() { _isSearching = false; });
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExperienceDetailScreen(experience: experience),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2, // Tu elevación original es 0, puedes ajustar como prefieras
        clipBehavior: Clip.antiAlias, // Para que el borderRadius afecte a la imagen
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Un radio más suave
        child: Column( // Usar Column para controlar mejor la imagen y el contenido
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de imagen
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 150, // Altura de imagen más estándar
                  child: experience.imageAsset.startsWith('http')
                      ? Image.network(
                    experience.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholderImageForCard(experience.category),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                          child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2.0, color: const Color(0xFFE67E22)
                          )
                      );
                    },
                  )
                      : experience.imageAsset.isNotEmpty && experience.imageAsset != 'assets/placeholder.jpg'
                      ? Image.asset(
                      experience.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print("Error al cargar asset local: ${experience.imageAsset} - $error");
                        return _placeholderImageForCard(experience.category);
                      }
                  )
                      : _placeholderImageForCard(experience.category),
                ),
                if (experience.isVerified)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.9), // Verde verificad
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text('Verificado', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Contenido de texto de la tarjeta
            Padding(
              padding: const EdgeInsets.all(12.0), // Padding uniforme
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // mainAxisAlignment: MainAxisAlignment.spaceBetween, // No necesario con Column externa
                children: [
                  Text(
                    experience.title,
                    style: const TextStyle(
                      fontSize: 16.5, // Ligeramente más grande
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row( // Categoría y Duración
                    children: [
                      Icon(_getIconForCategory(experience.category), size: 13, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(experience.category, style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
                      const Spacer(),
                      if (experience.duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE67E22).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
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
                  Row( // Ubicación y Rating
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          experience.location,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (experience.rating > 0)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              experience.rating.toStringAsFixed(1), // Muestra un decimal
                              style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Precio y botón "Ver más"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        (experience.price > 0)
                            ? '\$${experience.price.toStringAsFixed(0)} MXN'
                            : 'Gratis',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE67E22),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_isSearching) { setState(() { _isSearching = false; }); }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExperienceDetailScreen(experience: experience),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE67E22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), // Botón más pequeño
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Ver más'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImageForCard(String category) {
    // Tu placeholder, pero ahora usa la categoría para el icono
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [ Color(0xFFE67E22), Color(0xFF8B4513)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForCategory(category),
          size: 40,
          color: Colors.white.withOpacity(0.8), // Ligeramente más opaco
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    // Usando los iconos que tenías, pero con la versión _rounded para consistencia si te gusta
    switch (category) {
      case 'Gastronomía': return Icons.restaurant_menu_rounded;
      case 'Arte y Artesanía': return Icons.palette_rounded;
      case 'Patrimonio': return Icons.account_balance_rounded;
      case 'Naturaleza y Aventura': return Icons.terrain_rounded; // o Icons.hiking_rounded
      case 'Música y Danza': return Icons.music_note_rounded;
      case 'Bienestar': return Icons.spa_rounded;
      default: return Icons.explore_rounded;
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    // Tu _showFilterBottomSheet se mantiene igual, ya que solo filtra por categorías
    // y la lógica de aplicar el filtro ya actualiza _selectedCategory,
    // lo que hace que el StreamBuilder se reconstruya.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para mejor manejo en pantallas pequeñas
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) { // Renombrado para evitar confusión de context
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            String tempSelectedCategory = _selectedCategory;

            return Padding( // Padding para que no se pegue a los bordes si el teclado aparece
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar por Categoría', // Título más específico
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // No necesitas el subtítulo "Categorías" si es el único filtro
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0, // Espacio vertical entre chips
                      children: _categories.map((category) => FilterChip(
                        label: Text(category),
                        selected: tempSelectedCategory == category,
                        onSelected: (value) {
                          setModalState(() {
                            tempSelectedCategory = category;
                          });
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: const Color(0xFFE67E22),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                            color: tempSelectedCategory == category ? Colors.white : const Color(0xFF8B4513),
                            fontWeight: tempSelectedCategory == category ? FontWeight.bold : FontWeight.normal
                        ),
                        side: BorderSide(
                          color: tempSelectedCategory == category
                              ? const Color(0xFFE67E22)
                              : Colors.grey[300]!,
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(modalContext),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF8B4513),
                                side: const BorderSide(color: Color(0xFF8B4513)),
                                padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = tempSelectedCategory;
                                // No es necesario llamar a _loadExperiences o similar aquí,
                                // el StreamBuilder se reconstruirá con el nuevo _selectedCategory.
                              });
                              Navigator.pop(modalContext);
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE67E22),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10), // Un poco de espacio al final
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

const kColorFondo = Color(0xFFFFF0E0);
const kColorSeleccion = Color(0xFFCC7163);
const kColorTexto = Color(0xFF311F14);
const kColorGris = Color(0xFF8D6E63);