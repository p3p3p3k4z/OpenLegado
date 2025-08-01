import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para una `Experience`.
/// Esto nos ayuda a estructurar los datos de la experiencia de Firestore en un objeto Dart.
class Experience {
  final String id;
  final String title;
  final String description;
  final String imageAsset;
  final String location;
  final String category;
  final double price;
  final double rating;
  final int reviews;
  final String artisanName;
  final List<String> highlights;
  final String duration; // Duración de la experiencia
  final int maxCapacity; // Capacidad máxima de la experiencia
  final int bookedTickets; // Número de boletos ya reservados
  final double latitude; // Latitud de la ubicación
  final double longitude; // Longitud de la ubicación
  final String status; // Estado de la experiencia: 'pending', 'approved', 'rejected'
  final bool isVerified; // Si la experiencia ha sido verificada por un admin
  final bool isFeatured; // Si la experiencia debe ser destacada en la pantalla de inicio

  Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.location,
    required this.category,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.artisanName,
    required this.highlights,
    required this.duration,
    required this.maxCapacity,
    required this.bookedTickets,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.isVerified,
    required this.isFeatured,
  });

  /// Constructor de fábrica para crear una instancia de Experience desde un DocumentSnapshot de Firestore.
  factory Experience.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Se extraen los datos y se manejan los posibles valores nulos con valores por defecto.
    return Experience(
      id: doc.id,
      title: data?['title'] as String? ?? 'Título Desconocido',
      description: data?['description'] as String? ?? 'Descripción no disponible',
      imageAsset: data?['imageAsset'] as String? ?? 'assets/placeholder.jpg',
      location: data?['location'] as String? ?? 'Ubicación no disponible',
      category: data?['category'] as String? ?? 'Sin categoría',
      price: (data?['price'] as num?)?.toDouble() ?? 0.0,
      rating: (data?['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (data?['reviews'] as num?)?.toInt() ?? 0,
      artisanName: data?['artisanName'] as String? ?? 'Artesano Desconocido',
      highlights: List<String>.from(data?['highlights'] ?? []),
      duration: data?['duration'] as String? ?? 'No especificada',
      maxCapacity: (data?['maxCapacity'] as num?)?.toInt() ?? 10,
      bookedTickets: (data?['bookedTickets'] as num?)?.toInt() ?? 0,
      latitude: (data?['latitude'] as num?)?.toDouble() ?? 19.4326, // Latitud de CDMX por defecto
      longitude: (data?['longitude'] as num?)?.toDouble() ?? -99.1332, // Longitud de CDMX por defecto
      status: data?['status'] as String? ?? 'pending',
      isVerified: data?['isVerified'] as bool? ?? false,
      isFeatured: data?['isFeatured'] as bool? ?? false,
    );
  }
}
