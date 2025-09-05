// lib/screens/admin/manage_themed_collections_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/themed_collection.dart'; // Asegúrate que esta ruta sea correcta
import '../../../models/experience.dart';      // Asegúrate que esta ruta sea correcta

class ManageThemedCollectionsTab extends StatefulWidget {
  const ManageThemedCollectionsTab({super.key});

  @override
  State<ManageThemedCollectionsTab> createState() => _ManageThemedCollectionsTabState();
}

class _ManageThemedCollectionsTabState extends State<ManageThemedCollectionsTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ThemedCollection? _currentlyManagingCollection;

  List<Experience> _experiencesInSelectedCollection = [];
  List<Experience> _availableExperiencesToAdd = [];
  bool _isLoadingExperiencesForCollection = false;
  bool _isLoadingAvailableExperiences = false;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isFeaturedOnExploreForm = false; // Usado tanto para crear como para editar

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coverImageUrlController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Stream<List<ThemedCollection>> _getThemedCollectionsStream() {
    return _db
        .collection('experience_collections')
        .orderBy('order', descending: false) // Orden ascendente
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ThemedCollection.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList())
        .handleError((error) {
      print("Error obteniendo stream de colecciones temáticas: $error");
      return <ThemedCollection>[];
    });
  }

  Future<void> _createNewThemedCollectionInDialog(BuildContext dialogContext) async {
    if (!_formKey.currentState!.validate()) return;

    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Usuario no autenticado."), backgroundColor: Colors.red));
      return;
    }

    try {
      await _db.collection('experience_collections').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverImageUrl': _coverImageUrlController.text.trim(),
        'experienceIds': [],
        'isFeaturedOnExplore': _isFeaturedOnExploreForm,
        'order': int.tryParse(_orderController.text.trim()) ?? 999,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nueva colección creada."), backgroundColor: Colors.green));
        Navigator.of(dialogContext).pop();
      }
      // Limpiar controladores se hace al abrir el diálogo de creación
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al crear: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateThemedCollectionDetails(BuildContext dialogContext, ThemedCollection collectionToEdit) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _db.collection('experience_collections').doc(collectionToEdit.id).update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverImageUrl': _coverImageUrlController.text.trim(),
        'isFeaturedOnExplore': _isFeaturedOnExploreForm,
        'order': int.tryParse(_orderController.text.trim()) ?? collectionToEdit.order,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Colección actualizada."), backgroundColor: Colors.green));
        Navigator.of(dialogContext).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al actualizar: $e"), backgroundColor: Colors.red));
      }
    }
  }


  Future<List<Experience>> _getExperiencesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    List<Experience> experiences = [];
    for (String id in ids) {
      if (id.trim().isNotEmpty) {
        try {
          final doc = await _db.collection('experiences').doc(id.trim()).get();
          if (doc.exists) {
            experiences.add(Experience.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
          }
        } catch (e) {
          print("Error obteniendo experiencia $id por ID: $e");
        }
      }
    }
    return experiences;
  }

  Stream<List<Experience>> _getExperiencesStreamForAdding({String? statusFilter = 'approved'}) {
    Query query = _db.collection('experiences');
    if (statusFilter != null && statusFilter.isNotEmpty) { // Solo aplicar filtro si no es nulo o vacío
      query = query.where('status', isEqualTo: statusFilter);
    }
    query = query.orderBy('title'); // Siempre ordenar
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Experience.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList())
        .handleError((error) {
      print("Error obteniendo stream de exp. para añadir: $error");
      return <Experience>[];
    });
  }

  void _startManagingCollection(ThemedCollection collection) async {
    if (!mounted) return;
    setState(() {
      _currentlyManagingCollection = collection;
      _experiencesInSelectedCollection = [];
      _availableExperiencesToAdd = [];
      _isLoadingExperiencesForCollection = true;
      _isLoadingAvailableExperiences = true;
    });

    try {
      final experiences = await _getExperiencesByIds(collection.experienceIds);
      if (mounted && _currentlyManagingCollection?.id == collection.id) {
        setState(() {
          _experiencesInSelectedCollection = experiences;
          _isLoadingExperiencesForCollection = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingExperiencesForCollection = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExperiencesForCollection = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando experiencias: $e"), backgroundColor: Colors.red));
      }
    }

    try {
      // Para la lista de "Disponibles", vamos a cargar todas las experiencias aprobadas.
      // Si quisieras TODAS sin importar estado, pasarías statusFilter: null
      _getExperiencesStreamForAdding(statusFilter: 'approved').first.then((allExperiences) {
        if (mounted && _currentlyManagingCollection?.id == collection.id) {
          final currentIdsInCollection = Set<String>.from(_currentlyManagingCollection!.experienceIds);
          setState(() {
            _availableExperiencesToAdd = allExperiences.where((exp) => !currentIdsInCollection.contains(exp.id)).toList();
            _isLoadingAvailableExperiences = false;
          });
        } else if (mounted) {
          setState(() => _isLoadingAvailableExperiences = false);
        }
      }).catchError((e){
        if (mounted) {
          setState(() => _isLoadingAvailableExperiences = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando exp. disponibles: $e"), backgroundColor: Colors.red));
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAvailableExperiences = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando exp. disponibles: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _stopManagingCollectionAndRefresh() {
    setState(() {
      _currentlyManagingCollection = null;
    });
  }

  Future<void> _addExperienceToManagingCollection(Experience experienceToAdd) async {
    if (_currentlyManagingCollection == null || !mounted) return;
    try {
      final collectionRef = _db.collection('experience_collections').doc(_currentlyManagingCollection!.id);
      await collectionRef.update({
        'experienceIds': FieldValue.arrayUnion([experienceToAdd.id]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      final updatedCollection = _currentlyManagingCollection!.copyWith(
          experienceIds: List.from(_currentlyManagingCollection!.experienceIds)..add(experienceToAdd.id)
      );
      // Actualizar el estado local y recargar las listas para la colección actual
      if(mounted) {
        setState(() {
          _currentlyManagingCollection = updatedCollection; // Actualiza la colección en gestión
          _experiencesInSelectedCollection.add(experienceToAdd); // Añade a la lista visible
          _availableExperiencesToAdd.removeWhere((exp) => exp.id == experienceToAdd.id); // Quita de disponibles
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'${experienceToAdd.title}' añadida."), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al añadir: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _removeExperienceFromManagingCollection(Experience experienceToRemove) async {
    if (_currentlyManagingCollection == null || !mounted) return;
    try {
      final collectionRef = _db.collection('experience_collections').doc(_currentlyManagingCollection!.id);
      await collectionRef.update({
        'experienceIds': FieldValue.arrayRemove([experienceToRemove.id]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      final updatedCollection = _currentlyManagingCollection!.copyWith(
          experienceIds: List.from(_currentlyManagingCollection!.experienceIds)..remove(experienceToRemove.id)
      );
      if(mounted) {
        setState(() {
          _currentlyManagingCollection = updatedCollection;
          _experiencesInSelectedCollection.removeWhere((exp) => exp.id == experienceToRemove.id);
          _availableExperiencesToAdd.add(experienceToRemove); // Opcional: añadir de nuevo a disponibles si no se recarga todo
          _availableExperiencesToAdd.sort((a,b) => a.title.compareTo(b.title)); // Mantener orden
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'${experienceToRemove.title}' quitada."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al quitar: $e"), backgroundColor: Colors.red));
    }
  }

  void _showCreateCollectionDialog() {
    _titleController.clear();
    _descriptionController.clear();
    _coverImageUrlController.clear();
    _orderController.text = '999';
    _isFeaturedOnExploreForm = false; // Reset para creación

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Usar una variable local para el estado del switch dentro del diálogo si es necesario para el StatefulBuilder
        // pero _isFeaturedOnExploreForm se actualizará directamente.
        bool isFeaturedDialogState = _isFeaturedOnExploreForm;
        return AlertDialog(
          title: const Text('Crear Nueva Colección'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                return SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                        const SizedBox(height: 10),
                        TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2, validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                        const SizedBox(height: 10),
                        TextFormField(controller: _coverImageUrlController, decoration: const InputDecoration(labelText: 'URL Portada (Opcional)'), keyboardType: TextInputType.url),
                        const SizedBox(height: 10),
                        TextFormField(controller: _orderController, decoration: const InputDecoration(labelText: 'Orden (ej. 1)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) == null) ? 'Número Requerido' : null),
                        SwitchListTile(title: const Text('¿Destacar en Explore?'), value: isFeaturedDialogState, onChanged: (bool value) {
                          setDialogState(() => isFeaturedDialogState = value);
                          _isFeaturedOnExploreForm = value; // Actualizar la variable del estado principal
                        }, dense: true, contentPadding: EdgeInsets.zero),
                      ],
                    ),
                  ),
                );
              }
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(onPressed: () => _createNewThemedCollectionInDialog(dialogContext), child: const Text('Crear')),
          ],
        );
      },
    );
  }

  void _showEditCollectionDialog(ThemedCollection collectionToEdit) {
    _titleController.text = collectionToEdit.title;
    _descriptionController.text = collectionToEdit.description;
    _coverImageUrlController.text = collectionToEdit.coverImageUrl;
    _orderController.text = collectionToEdit.order.toString();
    _isFeaturedOnExploreForm = collectionToEdit.isFeaturedOnExplore; // Usar la misma variable de estado

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool isFeaturedDialogState = _isFeaturedOnExploreForm; // Estado local para el switch del diálogo
        return AlertDialog(
          title: Text('Editar: ${collectionToEdit.title}'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                return SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                        const SizedBox(height: 10),
                        TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2, validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                        const SizedBox(height: 10),
                        TextFormField(controller: _coverImageUrlController, decoration: const InputDecoration(labelText: 'URL Portada (Opcional)'), keyboardType: TextInputType.url),
                        const SizedBox(height: 10),
                        TextFormField(controller: _orderController, decoration: const InputDecoration(labelText: 'Orden (ej. 1)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) == null) ? 'Número Requerido' : null),
                        SwitchListTile(title: const Text('¿Destacar en Explore?'), value: isFeaturedDialogState, onChanged: (bool value) {
                          setDialogState(() => isFeaturedDialogState = value);
                          _isFeaturedOnExploreForm = value;
                        }, dense: true, contentPadding: EdgeInsets.zero),
                      ],
                    ),
                  ),
                );
              }),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(onPressed: () => _updateThemedCollectionDetails(dialogContext, collectionToEdit), child: const Text('Guardar')),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentlyManagingCollection != null
          ? AppBar(
        title: Text("Gestionar: ${_currentlyManagingCollection!.title}", style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopManagingCollectionAndRefresh,
        ),
        elevation: 1,
      )
          : null,
      body: _currentlyManagingCollection == null
          ? _buildCollectionsListUI()
          : _buildSingleCollectionManagementUI(),
      floatingActionButton: _currentlyManagingCollection == null
          ? FloatingActionButton(
        onPressed: _showCreateCollectionDialog,
        tooltip: 'Crear Colección',
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildCollectionsListUI() {
    return StreamBuilder<List<ThemedCollection>>(
      stream: _getThemedCollectionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error cargando colecciones: ${snapshot.error}"));
        }
        final collections = snapshot.data ?? [];
        if (collections.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "No hay colecciones temáticas creadas.\nToca el botón '+' para crear una nueva.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: Colors.grey),
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 columnas, puedes ajustar
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
            childAspectRatio: 0.85, // Ajusta para la proporción de tus tarjetas
          ),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final collection = collections[index];
            return Card(
              clipBehavior: Clip.antiAlias, // Importante para que el Stack respete los bordes redondeados
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Stack( // Usar Stack para superponer el botón de editar
                children: <Widget>[
                  // Contenido principal de la tarjeta (imagen y texto)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // --- Sección de la Imagen ---
                      Expanded(
                        flex: 3,
                        child: InkWell( // Hacer la imagen clickeable para gestionar
                          onTap: () => _startManagingCollection(collection),
                          child: collection.coverImageUrl.isNotEmpty
                              ? Image.network(
                            collection.coverImageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, prog) =>
                            prog == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            errorBuilder: (ctx, err, st) => Container(
                                color: Colors.grey[200],
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                          )
                              : Container(
                              color: Colors.grey[300],
                              alignment: Alignment.center,
                              child: const Icon(Icons.photo_library, size: 50, color: Colors.grey)),
                        ),
                      ),
                      // --- Sección de Texto ---
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0), // Ajusta padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start, // Alinea al inicio
                            children: [
                              InkWell( // Hacer el título clickeable para gestionar
                                onTap: () => _startManagingCollection(collection),
                                child: Text(
                                  collection.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2, // Permite 2 líneas para el título
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${collection.experienceIds.length} experiencias",
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // --- Botón de Editar Superpuesto ---
                  Positioned(
                    top: 4.0,  // Distancia desde arriba
                    right: 4.0, // Distancia desde la derecha
                    child: Container( // Contenedor para darle un fondo semitransparente al botón (opcional)
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3), // Fondo semitransparente
                        shape: BoxShape.circle, // Hacer el fondo circular
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18), // Icono más sutil
                        color: Colors.white, // Color del icono
                        tooltip: 'Editar Detalles',
                        padding: const EdgeInsets.all(6.0), // Padding más pequeño para el botón
                        constraints: const BoxConstraints(), // Quitar restricciones de tamaño por defecto
                        onPressed: () {
                          // Si se está gestionando otra colección, primero se detiene esa gestión.
                          if (_currentlyManagingCollection != null && _currentlyManagingCollection!.id != collection.id) {
                            _stopManagingCollectionAndRefresh();
                          }
                          _showEditCollectionDialog(collection);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSingleCollectionManagementUI() {
    if (_currentlyManagingCollection == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("En \"${_currentlyManagingCollection!.title}\" (${_experiencesInSelectedCollection.length})", style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                ),
                if (_isLoadingExperiencesForCollection)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_experiencesInSelectedCollection.isEmpty)
                  const Expanded(child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Esta colección está vacía. Añade experiencias desde la columna de la derecha.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _experiencesInSelectedCollection.length,
                      itemBuilder: (context, index) {
                        final exp = _experiencesInSelectedCollection[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                          child: ListTile(
                            dense: true,
                            title: Text(exp.title, style: const TextStyle(fontSize: 13.0)),
                            trailing: IconButton(
                              iconSize: 20.0,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              tooltip: 'Quitar de la colección',
                              onPressed: () => _showConfirmationDialog(
                                title: 'Quitar Experiencia',
                                content: '¿Seguro que quieres quitar "${exp.title}" de "${_currentlyManagingCollection!.title}"?',
                                onConfirm: () => _removeExperienceFromManagingCollection(exp),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1.0, thickness: 1.0),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Disponibles (${_availableExperiencesToAdd.length})", style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                ),
                if (_isLoadingAvailableExperiences)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_availableExperiencesToAdd.isEmpty)
                  const Expanded(child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No hay más experiencias aprobadas para añadir a esta colección.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableExperiencesToAdd.length,
                      itemBuilder: (context, index) {
                        final exp = _availableExperiencesToAdd[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                          child: ListTile(
                            dense: true,
                            title: Text(exp.title, style: const TextStyle(fontSize: 13.0)),
                            trailing: IconButton(
                              iconSize: 20.0,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              tooltip: 'Añadir a la colección',
                              onPressed: () => _addExperienceToManagingCollection(exp),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog({ required String title, required String content, required VoidCallback onConfirm}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Confirmar'),
              onPressed: () {
                onConfirm();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

extension ThemedCollectionCopyWith on ThemedCollection {
  ThemedCollection copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? experienceIds,
    bool? isFeaturedOnExplore,
    int? order,
    Timestamp? createdAt,
    String? createdBy,
    Timestamp? lastUpdatedAt,
  }) {
    return ThemedCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      experienceIds: experienceIds ?? this.experienceIds,
      isFeaturedOnExplore: isFeaturedOnExplore ?? this.isFeaturedOnExplore,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
