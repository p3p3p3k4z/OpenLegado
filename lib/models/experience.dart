import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para un `TicketSchedule`.
/// Representa una fecha específica y el cupo disponible para esa fecha.
class TicketSchedule {
  final DateTime date;
  final int capacity;

  TicketSchedule({
    required this.date,
    required this.capacity,
  });

  factory TicketSchedule.fromMap(Map<String, dynamic> data) {
    return TicketSchedule(
      date: (data['date'] as Timestamp).toDate(),
      capacity: (data['capacity'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'capacity': capacity,
    };
  }
}

/// Clase de modelo para una `Experience`.
/// Esto nos ayuda a estructurar los datos de la experiencia de Firestore en un objeto Dart.
class Experience {
  final String id;
  final String title;
  final String description;
  final String imageAsset;
  final String location;
  final double latitude;
  final double longitude;
  final String category;
  final double price;
  final double rating;
  final int reviews;
  final String artisanName;
  final List<String> highlights;
  final String duration;
  final String status;
  final bool isFeatured;
  final bool isVerified;
  final String submittedBy;
  final List<TicketSchedule> schedule; // NUEVO: Horario de fechas y cupos

  Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.artisanName,
    required this.highlights,
    required this.duration,
    required this.status,
    required this.isFeatured,
    required this.isVerified,
    required this.submittedBy,
    required this.schedule,
  });

  /// Constructor de fábrica para crear una instancia de Experience desde un DocumentSnapshot de Firestore.
  factory Experience.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Experience(
      id: doc.id,
      title: data?['title'] as String? ?? 'Título Desconocido',
      description: data?['description'] as String? ?? 'Descripción no disponible',
      imageAsset: data?['imageAsset'] as String? ?? 'assets/placeholder.jpg',
      location: data?['location'] as String? ?? 'Ubicación Desconocida',
      latitude: (data?['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data?['longitude'] as num?)?.toDouble() ?? 0.0,
      category: data?['category'] as String? ?? 'General',
      price: (data?['price'] as num?)?.toDouble() ?? 0.0,
      rating: (data?['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (data?['reviews'] as num?)?.toInt() ?? 0,
      artisanName: data?['artisanName'] as String? ?? 'Artesano Anónimo',
      highlights: List<String>.from(data?['highlights'] ?? []),
      duration: data?['duration'] as String? ?? 'Desconocida',
      status: data?['status'] as String? ?? 'pending',
      isFeatured: data?['isFeatured'] as bool? ?? false,
      isVerified: data?['isVerified'] as bool? ?? false,
      submittedBy: data?['submittedBy'] as String? ?? '',
      // Se crea la lista de TicketSchedule a partir de la lista de mapas en Firestore.
      schedule: (data?['schedule'] as List<dynamic>?)
          ?.map((item) => TicketSchedule.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
