import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/experience.dart';
import 'experience_detail_screen.dart';

// Paleta de colores flexible
const Color kBackgroundColor = Color(0xFFFFF0E0);
const Color kAccentColor = Color(0xFFF84400); // Naranja principal
const Color kTextColor = Color(0xFF311F14);   // Marrón oscuro para textos

// Fuente
const String kFontFamily = 'Montserrat';

class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({super.key});
  @override
  _ExperiencesScreenState createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  // Lógica de filtros y búsqueda
  List<String> _selectedCategories = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _minPrice;
  int? _maxPrice;
  String? _selectedState;

  // Estado de la UI
  bool _isSearching = false;

  // Listas de datos para filtros
  final List<String> _categories = [
    'Todas', 'Gastronomía', 'Arte y Artesanía', 'Patrimonio',
    'Naturaleza y Aventura', 'Música y Danza', 'Bienestar',
  ];
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
      if (mounted && _searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE CONSULTA SIMPLE (La que no da problemas de índice) ---
  Stream<List<Experience>> _getExperiencesStream() {
    Query<Map<String, dynamic>> query =
    FirebaseFirestore.instance.collection('experiences');

    // Filtra por categoría en el backend si se selecciona alguna
    if (_selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: _selectedCategories);
    }

    // Ordena por título. Esta combinación simple (where 'category' + orderBy 'title')
    // es la que Firestore suele permitir con un índice simple o autogenerado.
    query = query.orderBy('title');

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Experience.fromFirestore(doc))
      // Filtra el status en el cliente para evitar consultas complejas
          .where((e) => e.status == ExperienceStatus.approved)
          .toList();
    });
  }

  // Aplica los filtros más complejos en el lado del cliente
  List<Experience> _applyClientSideFilters(List<Experience> experiences) {
    List<Experience> filteredList = List.from(experiences);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filteredList = filteredList.where((e) => e.title.toLowerCase().contains(q)).toList();
    }
    if (_selectedState != null && _selectedState!.isNotEmpty) {
      filteredList = filteredList.where((e) => e.location.toLowerCase().contains(_selectedState!.toLowerCase())).toList();
    }
    if (_minPrice != null || _maxPrice != null) {
      filteredList = filteredList.where((e) {
        if (_minPrice != null && e.price < _minPrice!) return false;
        if (_maxPrice != null && e.price > _maxPrice!) return false;
        return true;
      }).toList();
    }
    if (_filterStartDate != null && _filterEndDate != null) {
      filteredList = filteredList.where((e) => e.schedule.any((s) => !s.date.isBefore(_filterStartDate!) && !s.date.isAfter(_filterEndDate!))).toList();
    }
    return filteredList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
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
          style: const TextStyle(color: kTextColor, fontSize: 16, fontFamily: kFontFamily),
        )
            : const Text(
          'Experiencias',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold, fontFamily: kFontFamily),
        ),
        backgroundColor: Colors.white,
        elevation: _isSearching ? 1.0 : 0.0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: kAccentColor),
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () {
              setState(() {
                if (_isSearching) _searchController.clear();
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: kAccentColor),
            tooltip: 'Filtrar',
            onPressed: () {
              if (_isSearching) setState(() => _isSearching = false);
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Experience>>(
        stream: _getExperiencesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kAccentColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}', style: TextStyle(color: Colors.red.shade700)));
          }

          List<Experience> experiences = snapshot.data ?? [];
          final filteredExperiences = _applyClientSideFilters(experiences);

          if (filteredExperiences.isEmpty) {
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
                      style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: kFontFamily),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredExperiences.length,
            itemBuilder: (context, index) {
              return _buildExperienceCard(filteredExperiences[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildExperienceCard(Experience experience) {
    return InkWell(
      onTap: () {
        if (_isSearching) setState(() => _isSearching = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ExperienceDetailScreen(experience: experience)),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: experience.imageAsset.startsWith('http')
                      ? Image.network(
                    experience.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImageForCard(experience.category),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kAccentColor));
                    },
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
                        // Usamos un verde como acento, como pediste
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text('Verificado', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: kFontFamily)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience.title,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: kTextColor, fontFamily: kFontFamily),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(_getIconForCategory(experience.category), size: 13, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(experience.category, style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontFamily: kFontFamily)),
                      const Spacer(),
                      if (experience.duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: kAccentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(experience.duration, style: const TextStyle(fontSize: 10, color: kAccentColor, fontWeight: FontWeight.w500, fontFamily: kFontFamily)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(experience.location, style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontFamily: kFontFamily), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      if (experience.rating > 0)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(experience.rating.toStringAsFixed(1), style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontWeight: FontWeight.bold, fontFamily: kFontFamily)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        (experience.price > 0) ? '\$${experience.price.toStringAsFixed(0)} MXN' : 'Gratis',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAccentColor, fontFamily: kFontFamily),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_isSearching) setState(() => _isSearching = false);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ExperienceDetailScreen(experience: experience)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: kFontFamily),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccentColor, Color.fromARGB(255, 138, 65, 28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(_getIconForCategory(category), size: 40, color: Colors.white.withOpacity(0.8))),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Gastronomía': return Icons.restaurant_menu_rounded;
      case 'Arte y Artesanía': return Icons.palette_rounded;
      case 'Patrimonio': return Icons.account_balance_rounded;
      case 'Naturaleza y Aventura': return Icons.terrain_rounded;
      case 'Música y Danza': return Icons.music_note_rounded;
      case 'Bienestar': return Icons.spa_rounded;
      default: return Icons.explore_rounded;
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        String? tempSelectedState = _selectedState;
        DateTime? tempStart = _filterStartDate;
        DateTime? tempEnd = _filterEndDate;
        List<String> tempSelectedCategories = List.from(_selectedCategories);
        final TextEditingController minPriceController = TextEditingController(text: _minPrice?.toString() ?? '');
        final TextEditingController maxPriceController = TextEditingController(text: _maxPrice?.toString() ?? '');

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate({required bool isStart}) async {
              final initial = isStart ? (tempStart ?? DateTime.now()) : (tempEnd ?? DateTime.now());
              final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2300));
              if (picked != null) {
                setModalState(() {
                  if (isStart) {
                    tempStart = picked;
                    if (tempEnd != null && tempEnd!.isBefore(tempStart!)) tempEnd = null;
                  } else {
                    tempEnd = picked;
                    if (tempStart != null && tempStart!.isAfter(tempEnd!)) tempStart = null;
                  }
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filtros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAccentColor, fontFamily: kFontFamily)),
                      const SizedBox(height: 14),

                      // Filtro por Estado
                      const Text('Estado', style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: tempSelectedState,
                        hint: const Text('Selecciona un estado', style: TextStyle(fontFamily: kFontFamily)),
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (String? newState) => setModalState(() => tempSelectedState = newState),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Todos los estados', style: TextStyle(fontFamily: kFontFamily))),
                          ..._mexicoStates.map((state) => DropdownMenuItem<String>(value: state, child: Text(state, style: const TextStyle(fontFamily: kFontFamily)))),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Filtro por Categorías
                      const Text('Categorías', style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 4,
                        children: _categories.where((c) => c != 'Todas').map((c) {
                          final isSel = tempSelectedCategories.contains(c);
                          return FilterChip(
                            label: Text(c, style: TextStyle(fontFamily: kFontFamily, color: isSel ? Colors.white : kTextColor)),
                            selected: isSel,
                            onSelected: (sel) => setModalState(() => sel ? tempSelectedCategories.add(c) : tempSelectedCategories.remove(c)),
                            backgroundColor: Colors.white,
                            selectedColor: kAccentColor,
                            checkmarkColor: Colors.white,
                            side: BorderSide(color: isSel ? kAccentColor : Colors.grey[300]!),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Filtro por Precio
                      const Text('Precio (MXN)', style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: minPriceController, keyboardType: TextInputType.number, decoration: InputDecoration(isDense: true, hintText: '\$ mín.', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!))))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: maxPriceController, keyboardType: TextInputType.number, decoration: InputDecoration(isDense: true, hintText: '\$ máx.', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!))))),
                      ]),
                      const SizedBox(height: 18),

                      // Botones de Acción
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _filterStartDate = null; _filterEndDate = null; _minPrice = null; _maxPrice = null; _selectedCategories.clear(); _selectedState = null;
                              });
                              Navigator.pop(modalContext);
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: kAccentColor, side: const BorderSide(color: kAccentColor), padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text('Limpiar', style: TextStyle(fontFamily: kFontFamily)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategories = List.from(tempSelectedCategories);
                                _selectedState = tempSelectedState;
                                _filterStartDate = tempStart;
                                _filterEndDate = tempEnd;
                                _minPrice = int.tryParse(minPriceController.text.trim());
                                _maxPrice = int.tryParse(maxPriceController.text.trim());
                              });
                              Navigator.pop(modalContext);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text('Aplicar', style: TextStyle(fontFamily: kFontFamily)),
                          ),
                        ),
                      ]),
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
