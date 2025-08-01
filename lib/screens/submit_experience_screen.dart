import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/experience.dart'; // Asegúrate de importar el modelo Experience

/// Pantalla para que los usuarios puedan enviar una nueva experiencia.
/// Ahora también permite la edición de una experiencia existente si se pasa un objeto
/// Experience en el constructor.
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
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _highlightsController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _maxCapacityController = TextEditingController();

  String? _selectedCategory;
  final List<String> _categories = [
    'Gastronomía',
    'Arte y Artesanía',
    'Patrimonio',
    'Naturaleza y Aventura',
    'Música y Danza',
    'Bienestar',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con los datos de la experiencia si se está editando.
    if (widget.experienceToEdit != null) {
      final experience = widget.experienceToEdit!;
      _titleController.text = experience.title;
      _descriptionController.text = experience.description;
      _imageController.text = experience.imageAsset;
      _locationController.text = experience.location;
      _priceController.text = experience.price.toString();
      _durationController.text = experience.duration;
      _highlightsController.text = experience.highlights.join(', ');
      _maxCapacityController.text = experience.maxCapacity.toString();
      _latitudeController.text = experience.latitude.toString();
      _longitudeController.text = experience.longitude.toString();
      _selectedCategory = experience.category;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Maneja el proceso de envío o actualización de la experiencia en Firestore.
  Future<void> _submitExperience() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debe iniciar sesión para enviar una experiencia.', Colors.red);
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Dividir los highlights por comas y limpiar espacios.
      final List<String> highlightsList = _highlightsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Preparar los datos para Firestore.
      final experienceData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageAsset': _imageController.text.isEmpty ? 'https://placehold.co/600x400/E67E22/ffffff?text=Experiencia' : _imageController.text,
        'location': _locationController.text,
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'duration': _durationController.text,
        'highlights': highlightsList,
        'maxCapacity': int.tryParse(_maxCapacityController.text) ?? 10,
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        // Mantener valores de la experiencia si se está editando, si no, usar valores por defecto.
        'rating': widget.experienceToEdit?.rating ?? 0.0,
        'reviews': widget.experienceToEdit?.reviews ?? 0,
        'artisanName': widget.experienceToEdit?.artisanName ?? user.displayName ?? 'Anónimo',
        'bookedTickets': widget.experienceToEdit?.bookedTickets ?? 0,
        'status': widget.experienceToEdit?.status ?? 'pending',
        'isVerified': widget.experienceToEdit?.isVerified ?? false,
        'isFeatured': widget.experienceToEdit?.isFeatured ?? false,
      };

      try {
        if (widget.experienceToEdit != null) {
          // Si se está editando, actualiza el documento existente.
          await FirebaseFirestore.instance
              .collection('experiences')
              .doc(widget.experienceToEdit!.id)
              .update(experienceData);
          _showSnackBar('Experiencia actualizada con éxito.', Colors.green);
        } else {
          // Si es una nueva experiencia, crea un nuevo documento.
          await FirebaseFirestore.instance
              .collection('experiences')
              .add({
            ...experienceData,
            'submittedAt': FieldValue.serverTimestamp(),
            'submittedBy': user.uid,
          });
          _showSnackBar('Experiencia enviada para revisión con éxito.', Colors.green);
          // Limpiar los campos después del envío de una nueva experiencia.
          _titleController.clear();
          _descriptionController.clear();
          _imageController.clear();
          _locationController.clear();
          _priceController.clear();
          _durationController.clear();
          _highlightsController.clear();
          _latitudeController.clear();
          _longitudeController.clear();
          _maxCapacityController.clear();
          setState(() {
            _selectedCategory = null;
          });
        }
        // Navegar hacia atrás después de un envío o actualización exitosa.
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.experienceToEdit == null ? 'Enviar una Experiencia' : 'Editar Experiencia',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B4513),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                '¡Comparte una experiencia cultural!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ayuda a la comunidad a descubrir experiencias únicas llenando este formulario.',
                style: TextStyle(fontSize: 16, color: Color(0xFF8D6E63)),
              ),
              const SizedBox(height: 24),
              _buildTextFormField(
                controller: _titleController,
                labelText: 'Título de la experiencia',
                hintText: 'Ej. Taller de Alfarería Tradicional',
                validator: (value) => value == null || value.isEmpty ? 'Por favor, ingresa un título.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _descriptionController,
                labelText: 'Descripción detallada',
                hintText: 'Describe la experiencia, lo que incluye y por qué es especial.',
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty ? 'Por favor, ingresa una descripción.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _imageController,
                labelText: 'URL de la imagen (opcional)',
                hintText: 'https://example.com/imagen.jpg',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _locationController,
                labelText: 'Ubicación',
                hintText: 'Ej. Oaxaca, México',
                validator: (value) => value == null || value.isEmpty ? 'Por favor, ingresa la ubicación.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _priceController,
                labelText: 'Precio (MXN)',
                hintText: 'Ej. 500',
                keyboardType: TextInputType.number,
                validator: (value) => value == null || double.tryParse(value) == null ? 'Por favor, ingresa un precio válido.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _durationController,
                labelText: 'Duración',
                hintText: 'Ej. 2 horas',
                validator: (value) => value == null || value.isEmpty ? 'Por favor, ingresa la duración.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _highlightsController,
                labelText: 'Puntos destacados',
                hintText: 'Ej. Incluye materiales, Guía local, Bebidas',
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _maxCapacityController,
                labelText: 'Cupo máximo',
                hintText: 'Ej. 10',
                keyboardType: TextInputType.number,
                validator: (value) => value == null || int.tryParse(value) == null ? 'Por favor, ingresa un cupo válido.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _latitudeController,
                labelText: 'Latitud',
                hintText: 'Ej. 17.06209',
                keyboardType: TextInputType.number,
                validator: (value) => value == null || double.tryParse(value) == null ? 'Por favor, ingresa una latitud válida.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _longitudeController,
                labelText: 'Longitud',
                hintText: 'Ej. -96.72146',
                keyboardType: TextInputType.number,
                validator: (value) => value == null || double.tryParse(value) == null ? 'Por favor, ingresa una longitud válida.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
                  ),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) => value == null ? 'Por favor, selecciona una categoría.' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitExperience,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  widget.experienceToEdit == null ? 'Enviar para Revisión' : 'Guardar Cambios',
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
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
    _maxCapacityController.dispose();
    super.dispose();
  }
}
