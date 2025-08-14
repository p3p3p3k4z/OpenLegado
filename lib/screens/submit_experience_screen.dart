import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // IMPORTAR
import 'package:geocoding/geocoding.dart' as geocoding; // IMPORTAR

import '../models/experience.dart';
import './map_picker_screen.dart'; // IMPORTAR la nueva pantalla

// Si TicketSchedule no está en experience.dart, impórtalo o defínelo aquí.
// class TicketSchedule { ... }

class SubmitExperienceScreen extends StatefulWidget {
  final Experience? experienceToEdit;

  const SubmitExperienceScreen({super.key, this.experienceToEdit});

  @override
  State<SubmitExperienceScreen> createState() => _SubmitExperienceScreenState();
}

class _SubmitExperienceScreenState extends State<SubmitExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();
  final _locationController = TextEditingController(); // Este se llenará con la dirección del mapa
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _highlightsController = TextEditingController();
  final _latitudeController = TextEditingController(); // Se llenará desde el mapa
  final _longitudeController = TextEditingController(); // Se llenará desde el mapa

  final List<TicketSchedule> _scheduleList = [];
  String? _selectedCategory;
  final List<String> _categories = [
    'Gastronomía', 'Arte y Artesanía', 'Patrimonio',
    'Naturaleza y Aventura', 'Música y Danza', 'Bienestar',
  ];
  bool _isLoading = false;

  // NUEVO: Para guardar las coordenadas seleccionadas del mapa
  LatLng? _selectedMapPosition;

  @override
  void initState() {
    super.initState();
    if (widget.experienceToEdit != null) {
      final experience = widget.experienceToEdit!;
      _titleController.text = experience.title;
      _descriptionController.text = experience.description;
      _imageController.text = experience.imageAsset == 'assets/placeholder.jpg' ? '' : experience.imageAsset;
      _locationController.text = experience.location;
      _priceController.text = experience.price.toString();
      _durationController.text = experience.duration;
      _highlightsController.text = experience.highlights.join(', ');
      _latitudeController.text = experience.latitude.toStringAsFixed(6);
      _longitudeController.text = experience.longitude.toStringAsFixed(6);
      _selectedCategory = experience.category;
      _scheduleList.addAll(experience.schedule);
      _scheduleList.sort((a, b) => a.date.compareTo(b.date));

      // Guardar la posición inicial para el mapa si estamos editando
      _selectedMapPosition = LatLng(experience.latitude, experience.longitude);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Métodos de Schedule (sin cambios, los omito por brevedad pero deben estar aquí) ---
  Future<void> _addOrEditScheduleEntry({TicketSchedule? scheduleToEdit, int? index}) async {
    final DateTime initialEntryDate = scheduleToEdit?.date ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialEntryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('es', 'MX'), // Para formato de fecha en español
    );

    if (pickedDate != null && mounted) {
      int? capacity = await _showCapacityDialog(context, initialCapacity: scheduleToEdit?.capacity);
      if (capacity != null && capacity > 0) {
        setState(() {
          final newEntry = TicketSchedule(
            date: pickedDate,
            capacity: capacity,
            bookedTickets: scheduleToEdit?.bookedTickets ?? 0,
          );
          if (scheduleToEdit != null && index != null) {
            _scheduleList[index] = newEntry;
          } else {
            final existingIndex = _scheduleList.indexWhere((s) =>
            s.date.year == pickedDate.year &&
                s.date.month == pickedDate.month &&
                s.date.day == pickedDate.day);
            if (existingIndex != -1 && (scheduleToEdit == null || _scheduleList[existingIndex].date != scheduleToEdit.date)) {
              _showSnackBar('Ya existe una entrada para esta fecha. Edítala o elimínala.', isError: true);
              return;
            }
            _scheduleList.add(newEntry);
          }
          _scheduleList.sort((a, b) => a.date.compareTo(b.date));
        });
      }
    }
  }

  Future<int?> _showCapacityDialog(BuildContext context, {int? initialCapacity}) async {
    final capacityController = TextEditingController(text: initialCapacity?.toString() ?? '');
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ingresar Cupo Máximo'),
          content: TextField(
            controller: capacityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: 'Ej. 10', labelText: 'Cupo'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Guardar'),
              onPressed: () {
                final capacity = int.tryParse(capacityController.text);
                if (capacity != null && capacity > 0) {
                  Navigator.pop(context, capacity);
                } else {
                  if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ingresa un cupo válido mayor a 0."), backgroundColor: Colors.orangeAccent),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
  // --- FIN Métodos de Schedule ---

  // NUEVO: Método para abrir el selector de mapa
  Future<void> _openMapPicker() async {
    LatLng initialMapPosition = _selectedMapPosition ?? const LatLng(19.4326, -99.1332); // CDMX por defecto

    // Navigator.push devuelve un Future que se completa cuando la pantalla a la que se navegó hace pop.
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialPosition: initialMapPosition,
          initialAddress: _locationController.text, // Pasar la dirección actual
        ),
      ),
    );

    if (result != null && result.containsKey('location') && result.containsKey('address')) {
      final LatLng selectedLocation = result['location'] as LatLng;
      final String selectedAddress = result['address'] as String;

      setState(() {
        _selectedMapPosition = selectedLocation;
        _latitudeController.text = selectedLocation.latitude.toStringAsFixed(6);
        _longitudeController.text = selectedLocation.longitude.toStringAsFixed(6);
        _locationController.text = selectedAddress; // Actualizar con la dirección obtenida del mapa
      });
    }
  }


  Future<void> _submitExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para enviar una experiencia.', isError: true);
      return;
    }

    // NUEVO: Validar que se haya seleccionado una ubicación del mapa
    if (_selectedMapPosition == null || _latitudeController.text.isEmpty || _longitudeController.text.isEmpty) {
      _showSnackBar('Por favor, selecciona la ubicación en el mapa.', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Por favor, corrige los errores en el formulario.', isError: true);
      return;
    }
    if (_selectedCategory == null) {
      _showSnackBar('Por favor, selecciona una categoría.', isError: true);
      return;
    }
    if (_scheduleList.isEmpty) {
      _showSnackBar('Debes agregar al menos una fecha con cupo.', isError: true);
      return;
    }

    setState(() { _isLoading = true; });

    final highlightsList = _highlightsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final int price = int.tryParse(_priceController.text) ?? 0;
    // Latitud y Longitud ahora se toman de _selectedMapPosition para mayor precisión
    // o de los controladores que ya fueron actualizados por el mapa.
    final double latitude = _selectedMapPosition!.latitude;
    final double longitude = _selectedMapPosition!.longitude;

    int totalMaxCapacity = _scheduleList.fold(0, (sum, item) => sum + item.capacity);
    int totalBookedTickets = _scheduleList.fold(0, (sum, item) => sum + item.bookedTickets);

    Map<String, dynamic> firestoreMap;
    String imageAssetValue = _imageController.text.trim().isEmpty ? 'assets/placeholder.jpg' : _imageController.text.trim();

    if (widget.experienceToEdit != null) {
      Experience updatedExperience = widget.experienceToEdit!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageAsset: imageAssetValue,
        location: _locationController.text.trim(), // Usar el texto del controlador (actualizado por el mapa)
        price: price,
        duration: _durationController.text.trim(),
        highlights: highlightsList,
        latitude: latitude,
        longitude: longitude,
        category: _selectedCategory!,
        schedule: List<TicketSchedule>.from(_scheduleList),
        maxCapacity: totalMaxCapacity,
        bookedTickets: totalBookedTickets,
      );
      firestoreMap = updatedExperience.toFirestoreMap();
    } else {
      Experience newExperience = Experience(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageAsset: imageAssetValue,
        location: _locationController.text.trim(),
        price: price,
        duration: _durationController.text.trim(),
        highlights: highlightsList,
        latitude: latitude,
        longitude: longitude,
        category: _selectedCategory!,
        schedule: List<TicketSchedule>.from(_scheduleList),
        maxCapacity: totalMaxCapacity,
        bookedTickets: totalBookedTickets,
        reviewsCount: 0,
        isVerified: false,
        isFeatured: false,
        creatorId: user.uid,
        status: ExperienceStatus.pending,
      );
      firestoreMap = newExperience.toFirestoreMap();
    }

    try {
      if (widget.experienceToEdit != null) {
        await FirebaseFirestore.instance.collection('experiences').doc(widget.experienceToEdit!.id).update(firestoreMap);
        _showSnackBar('Experiencia actualizada con éxito.');
      } else {
        await FirebaseFirestore.instance.collection('experiences').add(firestoreMap);
        _showSnackBar('Experiencia enviada para revisión.');
        _clearForm();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _imageController.clear();
    _locationController.clear();
    _priceController.clear();
    _durationController.clear();
    _highlightsController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    setState(() {
      _selectedCategory = null;
      _scheduleList.clear();
      _selectedMapPosition = null; // Limpiar la posición del mapa también
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.experienceToEdit == null ? 'Nueva Experiencia' : 'Editar Experiencia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                widget.experienceToEdit == null ? 'Comparte tu Experiencia Cultural' : 'Modifica los Detalles',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF5D4037)),
              ),
              const SizedBox(height: 8),
              Text(
                'Completa la información para que otros puedan descubrirla.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8D6E63)),
              ),
              const SizedBox(height: 24),

              _buildTextFormField(
                controller: _titleController,
                labelText: 'Título de la experiencia*',
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa un título.' : null,
              ),
              _buildTextFormField(
                controller: _descriptionController,
                labelText: 'Descripción detallada*', maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa una descripción.' : null,
              ),
              _buildTextFormField(
                controller: _imageController,
                labelText: 'URL de la imagen principal', keyboardType: TextInputType.url,
              ),

              // --- SECCIÓN DE UBICACIÓN MODIFICADA ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ubicación de la Experiencia*", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).hintColor)),
                    const SizedBox(height: 8),
                    _buildTextFormField(
                      controller: _locationController,
                      labelText: 'Dirección (seleccionada del mapa)*',
                      hintText: 'La dirección aparecerá aquí tras seleccionar en mapa',
                      readOnly: true, // Hacerlo de solo lectura, se actualiza desde el mapa
                      validator: (value) => value == null || value.trim().isEmpty ? 'Selecciona una ubicación en el mapa.' : null,
                      onTap: _openMapPicker, // Permitir abrir el mapa al tocar este campo también
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Seleccionar/Modificar en Mapa'),
                        onPressed: _openMapPicker,
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                      ),
                    ),
                    // Opcional: mostrar los campos de lat y lng (de solo lectura)
                    if (_latitudeController.text.isNotEmpty || _longitudeController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _latitudeController,
                                labelText: 'Latitud (del mapa)',
                                readOnly: true,
                                // No se necesita validador aquí si es de solo lectura y se llena programáticamente
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _longitudeController,
                                labelText: 'Longitud (del mapa)',
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // --- FIN SECCIÓN DE UBICACIÓN ---

              _buildTextFormField(
                controller: _priceController, labelText: 'Precio (MXN)*',
                keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Ingresa un precio.';
                  if (int.tryParse(value.trim()) == null) return 'Precio inválido.';
                  return null;
                },
              ),
              _buildTextFormField(
                controller: _durationController, labelText: 'Duración*',
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa la duración.' : null,
              ),
              _buildTextFormField(
                controller: _highlightsController,
                labelText: 'Puntos destacados (separados por coma)',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDecoration(labelText: 'Categoría*'),
                items: _categories.map((String category) => DropdownMenuItem<String>(value: category, child: Text(category))).toList(),
                onChanged: (String? newValue) => setState(() { _selectedCategory = newValue; }),
                validator: (value) => value == null ? 'Selecciona una categoría.' : null,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fechas y Cupos Disponibles*', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF5D4037))),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Theme.of(context).primaryColor, size: 28),
                    tooltip: 'Añadir nueva fecha y cupo',
                    onPressed: () => _addOrEditScheduleEntry(),
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (_scheduleList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('Añade al menos una fecha con su cupo máximo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                )
              else
                ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scheduleList.length,
                  itemBuilder: (context, index) {
                    final scheduleItem = _scheduleList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        title: Text(DateFormat('EEEE, dd MMM yyyy', 'es_MX').format(scheduleItem.date), style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('Cupo: ${scheduleItem.capacity} (${scheduleItem.bookedTickets} reservados)'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
                              tooltip: 'Editar esta fecha/cupo',
                              onPressed: () => _addOrEditScheduleEntry(scheduleToEdit: scheduleItem, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Eliminar esta fecha/cupo',
                              onPressed: () => setState(() { _scheduleList.removeAt(index); }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading
                    ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(widget.experienceToEdit == null ? Icons.cloud_upload_outlined : Icons.save_outlined),
                label: Text(widget.experienceToEdit == null ? 'Enviar para Revisión' : 'Guardar Cambios'),
                onPressed: _isLoading ? null : _submitExperience,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false, // NUEVO
    VoidCallback? onTap,    // NUEVO
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(labelText: labelText, hintText: hintText),
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        validator: validator,
        readOnly: readOnly, // Aplicar readOnly
        onTap: onTap,       // Aplicar onTap
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      ),
    );
  }

  InputDecoration _inputDecoration({required String labelText, String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade700, width: 2),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _highlightsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    // No olvides el nuevo controlador si lo agregaste en MapPickerScreen (ej. _searchController no está aquí)
    super.dispose();
  }
}
