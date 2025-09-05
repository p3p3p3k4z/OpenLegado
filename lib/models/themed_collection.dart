import 'package:cloud_firestore/cloud_firestore.dart';

class ThemedCollection {
  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final List<String> experienceIds; // CLAVE PARA EL CRUD: Añadir/quitar IDs aquí
  final bool isFeaturedOnExplore;
  final int order;
  final Timestamp createdAt;
  final String createdBy;          // UID del admin/curador
  final Timestamp? lastUpdatedAt;   // NUEVO OPCIONAL: Para saber cuándo se modificó la lista de experiencias

  ThemedCollection({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.experienceIds,
    this.isFeaturedOnExplore = false,
    this.order = 0,
    required this.createdAt,
    required this.createdBy,
    this.lastUpdatedAt, // NUEVO OPCIONAL
  });

  factory ThemedCollection.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Los datos del snapshot estaban nulos para ThemedCollection ID: ${snapshot.id}');
    }

    T _get<T>(String key, T defaultValue) {
      if (data.containsKey(key)) {
        var value = data[key];
        if (value is T) { return value; }
        else if (T == Timestamp && value is Timestamp) { return value as T;}
        // Podrías añadir más conversiones si tus datos de Firestore no son del tipo exacto
      }
      return defaultValue;
    }

    List<String> _getStringList(String key) {
      if (data.containsKey(key) && data[key] is List) {
        try {
          return List<dynamic>.from(data[key] as List)
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty) // Filtrar IDs vacíos
              .toList();
        } catch (e) { return []; }
      }
      return [];
    }

    return ThemedCollection(
      id: snapshot.id,
      title: _get('title', 'Colección Sin Título'),
      description: _get('description', 'Sin descripción.'),
      coverImageUrl: _get('coverImageUrl', ''),
      experienceIds: _getStringList('experienceIds'),
      isFeaturedOnExplore: _get('isFeaturedOnExplore', false),
      order: _get('order', 999),
      createdAt: _get('createdAt', Timestamp.now()),
      createdBy: _get('createdBy', ''),
      lastUpdatedAt: data['lastUpdatedAt'] as Timestamp?, // NUEVO OPCIONAL
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'experienceIds': experienceIds, // Este array se actualizaría en el CRUD
      'isFeaturedOnExplore': isFeaturedOnExplore,
      'order': order,
      'createdAt': createdAt, // Generalmente se establece una vez
      'createdBy': createdBy,
      // Al actualizar, querrás usar FieldValue.serverTimestamp() para lastUpdatedAt
      // 'lastUpdatedAt': lastUpdatedAt, // Se maneja mejor con FieldValue.serverTimestamp() en la operación de escritura
    };
  }
}
