import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Para tipo LatLng
import 'package:intl/date_symbol_data_local.dart';
// import 'package:intl/intl.dart'; // Ya importado arriba
import '../models/experience.dart'; // Asegúrate que aquí esté Experience y TicketSchedule
import './map_picker_screen.dart';   // Importa tu pantalla de selección de mapa

class SubmitExperienceScreen extends StatefulWidget {
  final Experience? experienceToEdit;
  final VoidCallback onSubmitSuccess; // <-- 1. AÑADIDO ESTO

  const SubmitExperienceScreen({
    super.key,
    this.experienceToEdit,
    required this.onSubmitSuccess, // <-- 2. ACTUALIZADO CONSTRUCTOR
  });

  @override
  State<SubmitExperienceScreen> createState() => _SubmitExperienceScreenState();
}

class _SubmitExperienceScreenState extends State<SubmitExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController(); // Para URL de imagen
  final _locationController = TextEditingController(); // Dirección textual
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _highlightsController = TextEditingController(); // Para lista separada por comas

  final List<TicketSchedule> _scheduleList = [];
  String? _selectedCategory;
  final List<String> _categories = [
    'Gastronomía', 'Arte y Artesanía', 'Patrimonio',
    'Naturaleza y Aventura', 'Música y Danza', 'Bienestar', 'Otro',
  ];
  bool _isLoading = false;
  LatLng? _selectedMapPosition; // Para guardar la LatLng del mapa

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_MX', null);

    if (widget.experienceToEdit != null) {
      _loadExperienceForEditing(widget.experienceToEdit!);
    }
  }

  void _loadExperienceForEditing(Experience experience) {
    _titleController.text = experience.title;
    _descriptionController.text = experience.description;
    _imageController.text = experience.imageAsset == 'assets/placeholder.jpg' || experience.imageAsset.startsWith('https://static.vecteezy.com/system/resources/previews/008/695/917/non_2x/no-image-available-icon-simple-two-colors-template-for-no-image-or-picture-coming-soon-and-placeholder-illustration-isolated-on-white-background-vector.jpg')
        ? ''
        : experience.imageAsset;
    _locationController.text = experience.location;
    _priceController.text = experience.price.toString();
    _durationController.text = experience.duration;
    _highlightsController.text = experience.highlights.join(', ');
    _selectedCategory = experience.category;

    if (experience.latitude != 0.0 || experience.longitude != 0.0) {
      _selectedMapPosition = LatLng(experience.latitude, experience.longitude);
    }

    _scheduleList.clear();
    _scheduleList.addAll(experience.schedule);
    _scheduleList.sort((a, b) => a.date.compareTo(b.date));
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Future<void> _addOrEditScheduleEntry({TicketSchedule? scheduleToEdit, int? index}) async {
    // 1. SELECCIONAR FECHA
    final DateTime initialDatePickerDate = scheduleToEdit?.date ?? DateTime.now();
    final DateTime firstAllowedDate = DateTime.now().subtract(const Duration(days: 1)); // No permitir fechas pasadas
    final DateTime validInitialDate = initialDatePickerDate.isBefore(firstAllowedDate) ? firstAllowedDate : initialDatePickerDate;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
      firstDate: firstAllowedDate,
      lastDate: DateTime.now().add(const Duration(days: 730)), // Por ejemplo, hasta 2 años en el futuro
      locale: const Locale('es', 'MX'),
      helpText: scheduleToEdit == null ? 'SELECCIONAR FECHA' : 'EDITAR FECHA',
      confirmText: 'ACEPTAR',
      cancelText: 'CANCELAR',
    );

    if (pickedDate == null) return; // El usuario canceló la selección de fecha
    if (!mounted) return;

    // 2. SELECCIONAR HORA
    final TimeOfDay initialTimePickerTime = scheduleToEdit != null
        ? TimeOfDay.fromDateTime(scheduleToEdit.date) // Usar la hora existente si se está editando
        : TimeOfDay.now(); // Usar la hora actual si es una nueva entrada

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTimePickerTime,
      helpText: scheduleToEdit == null ? 'SELECCIONAR HORA' : 'EDITAR HORA',
      confirmText: 'ACEPTAR',
      cancelText: 'CANCELAR',
      builder: (context, child) { // Opcional: Para que el tema del TimePicker coincida con el DatePicker
        return Localizations.override(
          context: context,
          locale: const Locale('es', 'MX'), // Para formato de hora AM/PM o 24h según locale
          child: child,
        );
      },
    );

    if (pickedTime == null) return; // El usuario canceló la selección de hora
    if (!mounted) return;

    // 3. COMBINAR FECHA Y HORA
    final DateTime finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 4. VERIFICAR DUPLICADOS (AHORA CON HORA)
    // No permitir agregar la misma fecha Y HORA más de una vez
    final isEditingSameDateTime = scheduleToEdit != null && finalDateTime.isAtSameMomentAs(scheduleToEdit.date);

    if (!isEditingSameDateTime) {
      final existingEntryIndex = _scheduleList.indexWhere((s) => s.date.isAtSameMomentAs(finalDateTime));
      if (existingEntryIndex != -1) {
        _showSnackBar('Ya existe una entrada para esta fecha y hora. Edítala o elimínala.', isError: true);
        return;
      }
    }

    // Validar que la fecha y hora no sean en el pasado (considerando un pequeño margen por si acaso)
    if (finalDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      _showSnackBar('No puedes seleccionar una fecha y hora en el pasado.', isError: true);
      return;
    }


    // 5. OBTENER CUPO
    int? capacity = await _showCapacityDialog(context, initialCapacity: scheduleToEdit?.capacity);
    if (capacity != null && capacity > 0) {
      setState(() {
        final newEntry = TicketSchedule(
          date: finalDateTime, // Usar el DateTime combinado
          capacity: capacity,
          bookedTickets: scheduleToEdit?.bookedTickets ?? 0,
        );
        if (scheduleToEdit != null && index != null && index < _scheduleList.length) {
          _scheduleList[index] = newEntry;
        } else {
          _scheduleList.add(newEntry);
        }
        _scheduleList.sort((a, b) => a.date.compareTo(b.date)); // Ordenar por fecha y hora
      });
    }
  }

  Future<int?> _showCapacityDialog(BuildContext context, {int? initialCapacity}) async {
    final capacityController = TextEditingController(text: initialCapacity?.toString() ?? '');
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ElevatedButton(
              child: const Text('Guardar'),
              onPressed: () {
                final capacity = int.tryParse(capacityController.text);
                if (capacity != null && capacity > 0) {
                  Navigator.pop(dialogContext, capacity);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
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

  void _removeScheduleEntry(int index) {
    if (index < 0 || index >= _scheduleList.length) return;

    if (_scheduleList[index].bookedTickets > 0) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Confirmar Eliminación"),
          content: Text("Esta fecha tiene ${_scheduleList[index].bookedTickets} ticket(s) reservado(s). ¿Estás seguro de que deseas eliminarla? Esta acción no se puede deshacer."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancelar")),
            TextButton(
                onPressed: (){
                  Navigator.pop(dialogContext);
                  setState(() {
                    _scheduleList.removeAt(index);
                  });
                  _showSnackBar("Entrada de horario eliminada.");
                },
                child: Text("Eliminar", style: TextStyle(color: Theme.of(context).colorScheme.error))
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _scheduleList.removeAt(index);
      });
      _showSnackBar("Entrada de horario eliminada.");
    }
  }

  Future<void> _openMapPicker() async {
    LatLng initialMapPosition = _selectedMapPosition ?? const LatLng(19.432608, -99.133209);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialPosition: initialMapPosition,
          initialAddress: _locationController.text,
        ),
      ),
    );

    if (result != null && result.containsKey('location') && result.containsKey('address')) {
      final LatLng selectedLocation = result['location'] as LatLng;
      final String selectedAddress = result['address'] as String;

      setState(() {
        _selectedMapPosition = selectedLocation;
        _locationController.text = selectedAddress;
      });
    }
  }

  Future<void> _submitExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para enviar una experiencia.', isError: true);
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
    if (_selectedMapPosition == null || _locationController.text.trim().isEmpty) {
      _showSnackBar('Por favor, selecciona la ubicación en el mapa.', isError: true);
      return;
    }
    if (_scheduleList.isEmpty) {
      _showSnackBar('Debes agregar al menos una fecha con cupo.', isError: true);
      return;
    }

    setState(() { _isLoading = true; });

    final highlightsList = _highlightsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final int price = int.tryParse(_priceController.text) ?? 0;
    final double latitude = _selectedMapPosition!.latitude;
    final double longitude = _selectedMapPosition!.longitude;

    int totalMaxCapacity = _scheduleList.fold(0, (sum, item) => sum + item.capacity);
    int totalBookedTickets = _scheduleList.fold(0, (sum, item) => sum + item.bookedTickets);

    String imageAssetValue = _imageController.text.trim();
    if (imageAssetValue.isEmpty) {
      imageAssetValue = 'assets/placeholder.jpg';
    }

    Experience experienceData = Experience(
      id: widget.experienceToEdit?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageAsset: imageAssetValue,
      location: _locationController.text.trim(),
      rating: widget.experienceToEdit?.rating ?? 0.0,
      price: price,
      duration: _durationController.text.trim(),
      highlights: highlightsList,
      latitude: latitude,
      longitude: longitude,
      category: _selectedCategory!,
      isVerified: widget.experienceToEdit?.isVerified ?? false,
      isFeatured: widget.experienceToEdit?.isFeatured ?? false,
      maxCapacity: totalMaxCapacity,
      bookedTickets: totalBookedTickets,
      reviewsCount: widget.experienceToEdit?.reviewsCount ?? 0,
      schedule: List<TicketSchedule>.from(_scheduleList),
      creatorId: widget.experienceToEdit?.creatorId ?? user.uid,
      status: widget.experienceToEdit?.status ?? ExperienceStatus.pending,
      submittedAt: widget.experienceToEdit?.submittedAt,
      lastUpdatedAt: null,
    );

    try {
      final firestoreMap = experienceData.toFirestoreMap();
      if (widget.experienceToEdit != null) {
        await FirebaseFirestore.instance.collection('experiences').doc(widget.experienceToEdit!.id).update(firestoreMap);
        _showSnackBar('Experiencia actualizada con éxito.');
      } else {
        await FirebaseFirestore.instance.collection('experiences').add(firestoreMap);
        _showSnackBar('Experiencia enviada para revisión.');
        _clearForm();
      }
      // if (mounted) Navigator.of(context).pop(); // <-- REMOVER ESTA LÍNEA
      if (mounted) { // <-- 3. LLAMAR AL CALLBACK
        widget.onSubmitSuccess();
      }
    } catch (e) {
      _showSnackBar('Error al guardar la experiencia: ${e.toString()}', isError: true);
      print("Firestore error: $e");
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
    setState(() {
      _selectedCategory = null;
      _scheduleList.clear();
      _selectedMapPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).colorScheme.secondary;
    final Color textColorPrimary = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final Color textColorSecondary = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.experienceToEdit == null ? 'Nueva Experiencia Cultural' : 'Editar Experiencia'),
        backgroundColor: accentColor,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                widget.experienceToEdit == null ? 'Comparte tu Joya Cultural' : 'Modifica los Detalles',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: accentColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Llena los campos para que otros puedan descubrir y disfrutar tu experiencia.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColorSecondary),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Información General'),
              _buildTextFormField(
                controller: _titleController,
                labelText: 'Título de la experiencia*',
                hintText: 'Ej. Taller de Alebrijes en Arrazola',
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa un título.' : null,
                icon: Icons.title,
              ),
              _buildTextFormField(
                controller: _descriptionController,
                labelText: 'Descripción detallada*',
                hintText: 'Describe la actividad, qué la hace única, qué incluye...',
                maxLines: 5,
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa una descripción.' : null,
                icon: Icons.description_outlined,
              ),
              _buildTextFormField(
                controller: _imageController,
                labelText: 'URL de la imagen principal',
                hintText: 'https://ejemplo.com/imagen.jpg (Opcional)',
                keyboardType: TextInputType.url,
                icon: Icons.image_outlined,
              ),
              _buildTextFormField(
                controller: _priceController,
                labelText: 'Precio (MXN)*',
                hintText: 'Ej. 350. Ingresa 0 si es gratuita.',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Ingresa un precio.';
                  if (int.tryParse(value.trim()) == null) return 'Precio inválido.';
                  return null;
                },
                icon: Icons.attach_money_outlined,
              ),
              _buildTextFormField(
                controller: _durationController,
                labelText: 'Duración*',
                hintText: 'Ej. 2 horas, Medio día, 1 día completo',
                validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa la duración.' : null,
                icon: Icons.timer_outlined,
              ),
              _buildTextFormField(
                controller: _highlightsController,
                labelText: 'Puntos destacados (separados por coma)',
                hintText: 'Ej. Guía bilingüe, Materiales incluidos, Degustación',
                icon: Icons.star_border_outlined,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _inputDecoration(labelText: 'Categoría*', icon: Icons.category_outlined),
                items: _categories.map((String category) => DropdownMenuItem<String>(value: category, child: Text(category))).toList(),
                onChanged: (String? newValue) => setState(() { _selectedCategory = newValue; }),
                validator: (value) => value == null ? 'Selecciona una categoría.' : null,
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Ubicación de la Experiencia*'),
              _buildTextFormField(
                controller: _locationController,
                labelText: 'Dirección (seleccionada del mapa)*',
                hintText: 'La dirección aparecerá aquí tras seleccionar en mapa',
                readOnly: true,
                validator: (value) => value == null || value.trim().isEmpty ? 'Selecciona una ubicación en el mapa.' : null,
                icon: Icons.location_on_outlined,
                onTap: _openMapPicker,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: Text(_selectedMapPosition == null ? 'Seleccionar en Mapa' : 'Modificar Ubicación en Mapa'),
                  onPressed: _openMapPicker,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor, side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              if (_selectedMapPosition != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Lat: ${_selectedMapPosition!.latitude.toStringAsFixed(6)}, Lng: ${_selectedMapPosition!.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColorSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),
              _buildSectionTitle('Fechas y Cupos Disponibles*'),
              const SizedBox(height: 8),
              if (_scheduleList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'Aún no has añadido fechas.\nPresiona el botón "+" para agregar la primera.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColorSecondary, fontStyle: FontStyle.italic, height: 1.5),
                    ),
                  ),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _scheduleList.length,
                itemBuilder: (context, index) {
                  final scheduleItem = _scheduleList[index];
                  // FORMATEADOR PARA FECHA Y HORA
                  final String formattedDateTime = DateFormat('EEEE, dd MMM yyyy - hh:mm a', 'es_MX').format(scheduleItem.date);
                  // Alternativa para formato 24h: DateFormat('EEEE, dd MMM yyyy - HH:mm', 'es_MX')

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.1),
                        foregroundColor: primaryColor,
                        child: const Icon(Icons.calendar_today_outlined, size: 20),
                      ),
                      title: Text(
                        formattedDateTime, // Usar el DateTime formateado
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('Cupo: ${scheduleItem.capacity} (Disponibles: ${scheduleItem.capacity - scheduleItem.bookedTickets})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: Colors.blueGrey.shade600, size: 22),
                            tooltip: 'Editar esta fecha/hora/cupo',
                            onPressed: () => _addOrEditScheduleEntry(scheduleToEdit: scheduleItem, index: index),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 22),
                            tooltip: 'Eliminar esta fecha/hora/cupo',
                            onPressed: () => _removeScheduleEntry(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton.extended(
                  onPressed: () => _addOrEditScheduleEntry(),
                  label: const Text('Añadir Fecha'),
                  icon: const Icon(Icons.add),
                  backgroundColor: primaryColor,
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading
                    ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(widget.experienceToEdit == null ? Icons.cloud_upload_outlined : Icons.save_alt_outlined),
                label: Text(widget.experienceToEdit == null ? 'Enviar para Revisión' : 'Guardar Cambios'),
                onPressed: _isLoading ? null : _submitExperience,
                style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
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
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(labelText: labelText, hintText: hintText, icon: icon),
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        validator: validator,
        readOnly: readOnly,
        onTap: onTap,
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      ),
    );
  }

  InputDecoration _inputDecoration({required String labelText, String? hintText, IconData? icon}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)) : null,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey.shade100.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    super.dispose();
  }
}
