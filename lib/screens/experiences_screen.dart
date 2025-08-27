import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';

// Paleta
const Color kBackgroundColor = Color(0xFFFFF0E0);
const Color kAccentColor = Color(0xFF952E07);
const Color kTextColor = Color(0xFF311F14);

// Fuente
const String kFontFamily = 'Montserrat';

class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({super.key});
  @override
  _ExperiencesScreenState createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  List<String> _selectedCategories = []; // Solo usamos la lista
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _categories = [
    'Todas', 'Gastronomía', 'Arte y Artesanía', 'Patrimonio',
    'Naturaleza y Aventura', 'Música y Danza', 'Bienestar',
  ];

  // Filtros adicionales (fechas y precio) — usados por el modal de filtros
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _minPrice;
  int? _maxPrice;

  // Estado (entidad federativa)
String? _selectedState; // null = sin filtro

// Lista de estados de México (incluye CDMX)
final List<String> _mexicoStates = const [
  'Aguascalientes', 'Baja California', 'Baja California Sur', 'Campeche',
  'Coahuila', 'Colima', 'Chiapas', 'Chihuahua', 'Ciudad de México',
  'Durango', 'Guanajuato', 'Guerrero', 'Hidalgo', 'Jalisco', 'México',
  'Michoacán', 'Morelos', 'Nayarit', 'Nuevo León', 'Oaxaca', 'Puebla',
  'Querétaro', 'Quintana Roo', 'San Luis Potosí', 'Sinaloa', 'Sonora',
  'Tabasco', 'Tamaulipas', 'Tlaxcala', 'Veracruz', 'Yucatán', 'Zacatecas',
];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
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

    if (_selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: _selectedCategories);
    }
    query = query.orderBy('title', descending: false);

    return query.snapshots().map((snapshot) {
      final experiences = snapshot.docs
          .map((doc) => Experience.fromFirestore(doc))
          .where((e) => e.status != ExperienceStatus.rejected)
          .toList();
      return experiences;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,

      // ───────── NAVIGATION BAR (AppBar) ─────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Experiencias',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.w700,
            fontFamily: kFontFamily,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      // ───────────────────────────────────────────

      body: Column(
        children: [
          // ===== Buscador =====
          Padding(
            padding: const EdgeInsets.fromLTRB(
              10,12,10,0
            ), // PADDING-- separación externa del bloque buscador respecto a los bordes del Scaffold
            child: Row(
              children: [
                // Campo de búsqueda
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontFamily: kFontFamily),
                    decoration: InputDecoration(
                      hintText: 'Buscar',
                      hintStyle: const TextStyle(fontFamily: kFontFamily),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12,
                      ), // PADDING-- relleno interno del TextField: ancho a los lados y alto arriba/abajo
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: kAccentColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Botón de filtros
                SizedBox(
                  height: 44,
                  width: 44,
                  child: Material(
                    color: Color(0xFF952E07),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showFilterBottomSheet(context),
                      child: const Center(
                        child: Icon(Icons.tune_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== Chips de categorías =====
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // PADDING-- margen interno lateral del contenedor de chips para que no peguen a los bordes
            decoration: BoxDecoration(
              color: kBackgroundColor,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final c = _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // PADDING-- espacio entre chip y chip
                  child: _buildFilterChip(c, c == 'Todas' ? _selectedCategories.isEmpty : _selectedCategories.contains(c)),
                );
              },
            ),
          ),

          // ===== Lista =====
          Expanded(
            child: StreamBuilder<List<Experience>>(
              stream: _getExperiencesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kAccentColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar experiencias: ${snapshot.error}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontFamily: kFontFamily,
                      ),
                    ),
                  );
                }

                List<Experience> experiences = snapshot.data ?? [];

                // Filtro por búsqueda
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.toLowerCase().trim();
                  experiences = experiences
                      .where((e) => e.title.toLowerCase().contains(q))
                      .toList();
                }

                // Filtro por Estado (si se seleccionó alguno)
                if (_selectedState != null && _selectedState!.isNotEmpty) {
                  final state = _selectedState!;
                  experiences = experiences.where((e) {
                    // 1) Si tu modelo tiene un campo 'state', úsalo (descomenta si existe):
                    // if ((e.state ?? '').isNotEmpty) {
                    //   return e.state!.toLowerCase() == state.toLowerCase();
                    // }

                    // 2) Si no existe 'state', intenta detectar el estado dentro de 'location'
                    final loc = e.location.toLowerCase();
                    return loc.contains(state.toLowerCase());
                  }).toList();
                }

                // Filtro por precio mínimo/máximo si fueron provistos
                if (_minPrice != null || _maxPrice != null) {
                  experiences = experiences.where((e) {
                    if (_minPrice != null && e.price < _minPrice!) return false;
                    if (_maxPrice != null && e.price > _maxPrice!) return false;
                    return true;
                  }).toList();
                }

                // Filtro por fecha: sólo si ambas fechas están establecidas
                if (_filterStartDate != null && _filterEndDate != null) {
                  final start = _filterStartDate!;
                  final end = _filterEndDate!;
                  experiences = experiences.where((e) {
                    if (e.schedule.isEmpty) return false;
                    return e.schedule.any((s) => !s.date.isBefore(start) && !s.date.isAfter(end));
                  }).toList();
                }

                if (experiences.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      // PADDING-- respiración general del mensaje vacío
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 50, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No se encontraron experiencias que coincidan con tu búsqueda o filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontFamily: kFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  // PADDING-- margen interno del listado para que las tarjetas no toquen los bordes
                  itemCount: experiences.length,
                  itemBuilder: (_, i) => _buildExperienceCard(experiences[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===== Chip de filtros =====
  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: kFontFamily,
          color: isSelected ? Colors.white : const Color(0xFF952E07),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          if (label == 'Todas') {
            // Si selecciona "Todas", limpiar todas las categorías
            _selectedCategories.clear();
          } else {
            // Si selecciona una categoría específica
            if (_selectedCategories.contains(label)) {
              // Si ya está seleccionada, la quitamos
              _selectedCategories.remove(label);
            } else {
              // Si no está seleccionada, la agregamos
              _selectedCategories.add(label);
            }
          }
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF952E07),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF952E07) : Colors.grey[300]!,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // PADDING-- relleno interno del chip (hacia los lados y arriba/abajo)
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? const Color(0xFF952E07) : Colors.grey[300]!,
        ),
      ),
    );
  }

Widget _buildExperienceCard(Experience experience) {
  return InkWell(
    onTap: () {
      if (_isSearching) setState(() => _isSearching = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExperienceDetailScreen(experience: experience),
        ),
      );
    },
    child: Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white, // Fondo blanco
      child: Row(
        children: [
          // Imagen con bordes redondeados y padding izquierdo
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // Bordes redondeados
              child: SizedBox(
                width: 120,
                height: 120,
                child: experience.imageAsset.startsWith('http')
                    ? Image.network(
                        experience.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _placeholderImageForCard(experience.category),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kAccentColor,
                            ),
                          );
                        },
                      )
                    : (experience.imageAsset.isNotEmpty &&
                            experience.imageAsset != 'assets/placeholder.jpg')
                        ? Image.asset(
                            experience.imageAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholderImageForCard(experience.category),
                          )
                        : _placeholderImageForCard(experience.category),
              ),
            ),
          ),
          const SizedBox(width: 12), // Espacio entre imagen y texto
          // Contenido textual a la derecha
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                      fontFamily: kFontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          experience.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[700],
                            fontFamily: kFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Categoría en un óvalo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getIconForCategory(experience.category),
                                size: 14, color: kAccentColor),
                            const SizedBox(width: 5),
                            Text(
                              experience.category,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: kAccentColor,
                                fontFamily: kFontFamily,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8), // Espacio entre la categoría y duración
                      // Duración en forma de chip
                      if (experience.duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kAccentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            experience.duration,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: kAccentColor,
                              fontFamily: kFontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (experience.price > 0)
                            ? '\$${experience.price.toStringAsFixed(0)} MXN'
                            : 'Gratis',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kAccentColor,
                          fontFamily: kFontFamily,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_isSearching) setState(() => _isSearching = false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExperienceDetailScreen(
                                  experience: experience),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontFamily,
                          ),
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
          ),
        ],
      ),
    ),
  );
}


  Widget _placeholderImageForCard(String category) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccentColor, Color.fromARGB(255, 138, 65, 28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForCategory(category),
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Gastronomía':
        return Icons.restaurant_menu_rounded;
      case 'Arte y Artesanía':
        return Icons.palette_rounded;
      case 'Patrimonio':
        return Icons.account_balance_rounded;
      case 'Naturaleza y Aventura':
        return Icons.terrain_rounded;
      case 'Música y Danza':
        return Icons.music_note_rounded;
      case 'Bienestar':
        return Icons.spa_rounded;
      default:
        return Icons.explore_rounded;
    }
  }
  void _showFilterBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) {
      // ── MOVER variables temporales AQUÍ (fuera del builder de StatefulBuilder)
      String? tempSelectedState = _selectedState;
      DateTime? tempStart = _filterStartDate;
      DateTime? tempEnd = _filterEndDate;
      List<String> tempSelectedCategories = List.from(_selectedCategories);

      final TextEditingController minPriceController =
          TextEditingController(text: _minPrice?.toString() ?? '');
      final TextEditingController maxPriceController =
          TextEditingController(text: _maxPrice?.toString() ?? '');

      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickDate({required bool isStart}) async {
            final initial = isStart
                ? (tempStart ?? DateTime.now())
                : (tempEnd ?? DateTime.now());
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2300),
            );
            if (picked != null) {
              setModalState(() {
                if (isStart) {
                  tempStart = picked;
                  if (tempEnd != null && tempEnd!.isBefore(tempStart!)) {
                    tempEnd = null;
                  }
                } else {
                  tempEnd = picked;
                  if (tempStart != null && tempStart!.isAfter(tempEnd!)) {
                    tempStart = null;
                  }
                }
              });
            }
          }

          String _format(DateTime? d) {
            if (d == null) return '';
            String two(int n) => n.toString().padLeft(2, '0');
            return '${two(d.day)}/${two(d.month)}/${d.year}';
          }

          Widget _dateBox({
            required String placeholder,
            required DateTime? value,
            required VoidCallback onTap,
          }) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_format(value).isNotEmpty) ? _format(value) : placeholder,
                        style: const TextStyle(fontFamily: kFontFamily),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, size: 18),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kAccentColor,
                        fontFamily: kFontFamily,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ======= Estado =======
                    const Text(
                      'Estado',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: tempSelectedState, // puede ser null
                      hint: const Text('Selecciona un estado',
                          style: TextStyle(fontFamily: kFontFamily)),
                      isExpanded: true,
                      onChanged: (String? newState) {
                        setModalState(() {
                          // Convertir "todos" a null (sin filtro)
                          if (newState == 'todos') {
                            tempSelectedState = null;
                          } else {
                            tempSelectedState = newState;
                          }
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'todos',
                          child: Text('Todos',
                              style: TextStyle(fontFamily: kFontFamily)),
                        ),
                        ..._mexicoStates.map((state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(state,
                                style: const TextStyle(fontFamily: kFontFamily)),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ======= Categorías (múltiple) =======
                    const Text(
                      'Categorías',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _categories.where((c) => c != 'Todas').map((c) {
                        final isSel = tempSelectedCategories.contains(c);
                        return FilterChip(
                          label: Text(
                            c,
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              color: isSel ? Colors.white : const Color(0xFF8B4513),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSel,
                          onSelected: (sel) {
                            setModalState(() {
                              if (sel) {
                                tempSelectedCategories.add(c);
                              } else {
                                tempSelectedCategories.remove(c);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: kAccentColor,
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSel ? kAccentColor : Colors.grey[300]!,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // ======= Fechas =======
                    const Text(
                      'Fechas',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _dateBox(
                            placeholder: 'Desde',
                            value: tempStart,
                            onTap: () => pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dateBox(
                            placeholder: 'Hasta',
                            value: tempEnd,
                            onTap: () => pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ======= Precio =======
                    const Text(
                      'Precio (MXN)',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPriceController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              fontWeight: FontWeight.w400,
                              color: kTextColor,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '\$ mín.',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxPriceController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontFamily: kFontFamily),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '\$ máx.',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ======= Acciones =======
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempStart = null;
                                tempEnd = null;
                                minPriceController.clear();
                                maxPriceController.clear();
                                tempSelectedCategories.clear();
                                tempSelectedState = null;
                              });
                              setState(() {
                                _filterStartDate = null;
                                _filterEndDate = null;
                                _minPrice = null;
                                _maxPrice = null;
                                _selectedCategories.clear();
                                _selectedState = null;
                              });
                              Navigator.pop(modalContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kAccentColor,
                              side: const BorderSide(color: kAccentColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Limpiar',
                                style: TextStyle(fontFamily: kFontFamily)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Validación fechas
                              if ((tempStart != null && tempEnd == null) ||
                                  (tempStart == null && tempEnd != null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Selecciona ambas fechas o ninguna.',
                                      style: TextStyle(fontFamily: kFontFamily),
                                    ),
                                  ),
                                );
                                return;
                              }

                              final minP = int.tryParse(minPriceController.text.trim());
                              final maxP = int.tryParse(maxPriceController.text.trim());

                              setState(() {
                                _selectedCategories = List.from(tempSelectedCategories);
                                _selectedState = tempSelectedState; // null = sin filtro
                                _filterStartDate = tempStart;
                                _filterEndDate = tempEnd;
                                _minPrice = minP;
                                _maxPrice = maxP;
                              });
                              Navigator.pop(modalContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Aplicar',
                                style: TextStyle(fontFamily: kFontFamily)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

}