// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart'; // Asegúrate que la ruta sea correcta

class EditProfileScreen extends StatefulWidget {
  final AppUser currentUserData; // Pasamos los datos actuales para evitar una carga inicial

  const EditProfileScreen({super.key, required this.currentUserData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  List<String> _galleryImageUrls = [];
  final List<XFile?> _localImageFilesToUpload = []; // Para nuevas imágenes seleccionadas
  final List<String> _galleryImageUrlsToDeleteFromStorage = []; // Para URLs de Storage que se eliminan

  bool _isLoading = false;
  final int _galleryLimit = 3;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final String _defaultPlaceholder = 'assets/images/placeholder.png'; // Asegúrate que exista

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUserData.username);
    _bioController = TextEditingController(text: widget.currentUserData.bio);
    // Copiar la lista para poder modificarla
    _galleryImageUrls = List.from(widget.currentUserData.galleryImageUrls);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  Future<void> _pickGalleryImage() async {
    if (_galleryImageUrls.length + _localImageFilesToUpload.length >= _galleryLimit) {
      _showSnackBar(
        'Ya has alcanzado el límite de $_galleryLimit imágenes en la galería.',
        isError: true,
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null && mounted) {
        setState(() {
          _localImageFilesToUpload.add(image);
        });
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar la imagen: $e', isError: true);
    }
  }

  void _removeGalleryImage(int index, {bool isLocalFile = false}) {
    if (!mounted) return;
    setState(() {
      if (isLocalFile) {
        if (index < _localImageFilesToUpload.length) {
          _localImageFilesToUpload.removeAt(index);
        }
      } else {
        if (index < _galleryImageUrls.length) {
          String urlToRemove = _galleryImageUrls.removeAt(index);
          // Si la URL es de Firebase Storage, la añadimos a la lista para borrarla de Storage al guardar
          if (urlToRemove.startsWith('https://firebasestorage.googleapis.com')) {
            _galleryImageUrlsToDeleteFromStorage.add(urlToRemove);
          }
        }
      }
    });
  }

  void _showAddImageUrlDialog() {
    if (_galleryImageUrls.length + _localImageFilesToUpload.length >= _galleryLimit) {
      _showSnackBar('Ya has alcanzado el límite de $_galleryLimit imágenes en la galería.', isError: true);
      return;
    }
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Imagen desde URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(hintText: 'https://ejemplo.com/imagen.jpg'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                if (mounted) {
                  setState(() {
                    _galleryImageUrls.add(url); // Añadir directamente la URL de internet
                  });
                  Navigator.pop(context);
                }
              } else {
                _showSnackBar('Ingresa una URL válida.', isError: true);
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }


  Future<String?> _uploadFileToStorage(XFile file, String userId) async {
    try {
      String fileName = 'users/$userId/gallery/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      Reference storageRef = _storage.ref().child(fileName);
      UploadTask uploadTask;

      if (kIsWeb) {
        Uint8List fileBytes = await file.readAsBytes();
        uploadTask = storageRef.putData(fileBytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        uploadTask = storageRef.putFile(File(file.path), SettableMetadata(contentType: 'image/jpeg'));
      }

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error subiendo archivo a Storage: $e");
      _showSnackBar('Error al subir una imagen: ${e.toString()}', isError: true);
      return null;
    }
  }

  Future<void> _deleteUrlsFromStorage(List<String> urlsToDelete) async {
    for (String url in urlsToDelete) {
      try {
        // Solo intentar borrar si es una URL de Firebase Storage
        if (url.startsWith('https://firebasestorage.googleapis.com')) {
          Reference photoRef = _storage.refFromURL(url);
          await photoRef.delete();
          print("Imagen eliminada de Storage: $url");
        }
      } catch (e) {
        print("Error eliminando imagen de Storage ($url): $e");
        // No mostrar snackbar por cada error aquí, podría ser molesto. Loggear es suficiente.
      }
    }
  }


  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Por favor, corrige los errores.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Error: Usuario no autenticado.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    List<String> finalGalleryUrls = List.from(_galleryImageUrls); // Empezar con las URLs existentes (o recién añadidas de internet)

    // Subir nuevas imágenes locales
    for (XFile? file in _localImageFilesToUpload) {
      if (file != null) {
        String? downloadUrl = await _uploadFileToStorage(file, user.uid);
        if (downloadUrl != null) {
          finalGalleryUrls.add(downloadUrl);
        } else {
          // Si una subida falla, podríamos decidir detener todo o continuar.
          // Por ahora, continuamos pero el usuario verá el error.
        }
      }
    }
    // Asegurar que no excedamos el límite después de las subidas
    if (finalGalleryUrls.length > _galleryLimit) {
      _showSnackBar('Se ha excedido el límite de $_galleryLimit imágenes. Se guardarán las primeras $_galleryLimit.', isError: true);
      finalGalleryUrls = finalGalleryUrls.sublist(0, _galleryLimit);
    }


    Map<String, dynamic> updatedData = {
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
      'galleryImageUrls': finalGalleryUrls, // Las URLs actualizadas
      // No actualizamos 'profileImageUrl' aquí, eso se maneja en ProfileScreen
    };

    try {
      // Borrar las imágenes de Storage que fueron marcadas para eliminación
      if (_galleryImageUrlsToDeleteFromStorage.isNotEmpty) {
        await _deleteUrlsFromStorage(_galleryImageUrlsToDeleteFromStorage);
      }

      await _firestore.collection('users').doc(user.uid).update(updatedData);
      _showSnackBar('Perfil actualizado con éxito.');
      if (mounted) {
        Navigator.pop(context, true); // Devuelve true para indicar que se guardó
      }
    } catch (e) {
      _showSnackBar('Error al actualizar el perfil: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentImageCount = _galleryImageUrls.length + _localImageFilesToUpload.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          IconButton(
            icon: _isLoading ? const SizedBox(width:20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,)) : const Icon(Icons.save_rounded),
            onPressed: _isLoading ? null : _saveProfile,
            tooltip: 'Guardar Cambios',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Usuario',
                  hintText: 'Cómo te verán los demás',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre de usuario no puede estar vacío.';
                  }
                  if (value.trim().length < 3) {
                    return 'Debe tener al menos 3 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Biografía',
                  hintText: 'Cuéntanos un poco sobre ti o tu trabajo...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                maxLines: 4,
                maxLength: 250, // Límite de caracteres para la bio
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Galería de Muestra (${_galleryImageUrls.length + _localImageFilesToUpload.length}/$_galleryLimit)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library_outlined),
                        tooltip: 'Añadir desde Galería',
                        onPressed: (currentImageCount < _galleryLimit) ? _pickGalleryImage : null,
                        color: (currentImageCount < _galleryLimit) ? Theme.of(context).primaryColor : Colors.grey,
                      ),
                      IconButton(
                        icon: const Icon(Icons.link_outlined),
                        tooltip: 'Añadir desde URL',
                        onPressed: (currentImageCount < _galleryLimit) ? _showAddImageUrlDialog : null,
                        color: (currentImageCount < _galleryLimit) ? Theme.of(context).primaryColor : Colors.grey,
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (_galleryImageUrls.isEmpty && _localImageFilesToUpload.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Center(
                    child: Text(
                      'Aún no has añadido imágenes a tu galería.\nPuedes añadir hasta $_galleryLimit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                _buildGalleryGrid(),

              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: _isLoading
                    ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Icon(Icons.save_alt_outlined),
                label: const Text('Guardar Todos los Cambios'),
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    // Combinar URLs existentes y archivos locales para la visualización
    List<Widget> galleryItems = [];

    // URLs de Firebase o internet
    for (int i = 0; i < _galleryImageUrls.length; i++) {
      galleryItems.add(_buildGalleryItem(_galleryImageUrls[i], i, isLocalFile: false));
    }
    // Archivos locales pendientes de subir
    for (int i = 0; i < _localImageFilesToUpload.length; i++) {
      if (_localImageFilesToUpload[i] != null) {
        galleryItems.add(_buildGalleryItem(_localImageFilesToUpload[i]!, i, isLocalFile: true));
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 imágenes por fila
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: galleryItems.length,
      itemBuilder: (context, index) {
        return galleryItems[index];
      },
    );
  }

  Widget _buildGalleryItem(dynamic itemData, int index, {required bool isLocalFile}) {
    ImageProvider imageProvider;
    if (isLocalFile && itemData is XFile) {
      if (kIsWeb) {
        imageProvider = NetworkImage(itemData.path); // Para web, XFile.path es una URL blob
      } else {
        imageProvider = FileImage(File(itemData.path));
      }
    } else if (!isLocalFile && itemData is String) { // URL de internet o Storage
      if (itemData.startsWith('http')) {
        imageProvider = NetworkImage(itemData);
      } else if (itemData.startsWith('assets/')) { // Aunque no deberíamos tener assets aquí
        imageProvider = AssetImage(itemData);
      } else {
        imageProvider = AssetImage(_defaultPlaceholder);
      }
    } else {
      imageProvider = AssetImage(_defaultPlaceholder); // Fallback
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  // Si la imagen de red falla, puedes intentar mostrar un placeholder aquí
                  // Esto es más complejo de manejar directamente en DecorationImage.
                  // Podrías tener un child en el Container que se muestre si hay error.
                  print("Error cargando imagen en grid: $itemData");
                }
            ),
          ),
          // Fallback visual si la imagen no carga o es un placeholder
          child: imageProvider is AssetImage && (imageProvider).assetName == _defaultPlaceholder
              ? Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 30))
              : null,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Material( // Necesario para el InkWell y el efecto ripple en el IconButton
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _removeGalleryImage(index, isLocalFile: isLocalFile),
              borderRadius: BorderRadius.circular(20), // Para el área del ripple
              child: Container(
                padding: const EdgeInsets.all(2), // Padding alrededor del icono
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
        if (isLocalFile) // Indicador de que es una nueva imagen
          Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4)
                ),
                child: const Text('NUEVA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              )
          )
      ],
    );
  }
}
