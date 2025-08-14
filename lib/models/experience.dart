import 'package:cloud_firestore/cloud_firestore.dart';

// Asumimos que TicketSchedule está definido en alguna parte,
// por ejemplo, en el mismo archivo o importado.
// class TicketSchedule { ... } // (Definición como la discutimos antes)

// Define los posibles estados para mayor claridad y evitar errores de tipeo
enum ExperienceStatus { pending, approved, rejected, archived }

/// Clase de modelo para representar una experiencia cultural en la aplicación Legado.
class Experience {
  final String id;
  final String title;
  final String description;
  final String imageAsset; // Ruta del asset local o URL de imagen
  final String location;
  final double rating; // Calificación promedio de todas las reseñas
  final int price; // Precio en MXN
  final String duration;
  final List<String> highlights; // Lista de puntos destacados
  final double latitude;
  final double longitude;
  final String category; // Categoría de la experiencia

  // Campos existentes para la gestión y el feedback
  final bool isVerified; // Si la experiencia ha sido verificada por un admin
  final bool isFeatured; // Si la experiencia se destaca en la página principal
  final int maxCapacity; // Cupo máximo de personas (considera si se deriva de schedule)
  final int bookedTickets; // Número de boletos ya reservados (considera si se deriva de schedule)
  final int reviewsCount; // Cantidad de comentarios

  // CAMPO PARA EL HORARIO/CALENDARIO DE TICKETS (Discutido previamente)
  final List<TicketSchedule> schedule;

  // NUEVOS CAMPOS SOLICITADOS
  final String creatorId;         // ID del usuario que creó/subió la experiencia
  final ExperienceStatus status;  // Estado de la experiencia (pending, approved, rejected)
  final DateTime? submittedAt;    // Fecha de envío/creación
  final DateTime? lastUpdatedAt;  // Fecha de última actualización


  /// Constructor principal para crear una instancia de Experience.
  const Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.location,
    this.rating = 0.0,
    this.price = 0,
    required this.duration,
    this.isVerified = false,
    this.isFeatured = false,
    this.highlights = const [],
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.category,
    this.maxCapacity = 0,
    this.bookedTickets = 0,
    this.reviewsCount = 0,
    this.schedule = const [], // Valor por defecto para schedule
    required this.creatorId,
    this.status = ExperienceStatus.pending, // Valor por defecto para status
    this.submittedAt,
    this.lastUpdatedAt,
  });

  /// Constructor de fábrica para crear una instancia de Experience desde un DocumentSnapshot de Firestore.
  factory Experience.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Parseo del schedule
    List<TicketSchedule> parsedSchedule = [];
    if (data?['schedule'] != null && data!['schedule'] is List) {
      parsedSchedule = (data['schedule'] as List<dynamic>)
          .map((item) {
        // Asegúrate de que TicketSchedule.fromMap maneje Map<String, dynamic>
        // Si item no es ya Map<String, dynamic>, necesitarás un cast seguro.
        if (item is Map<String, dynamic>) {
          return TicketSchedule.fromMap(item);
        }
        // Retorna un valor por defecto o maneja el error si el item no es el esperado
        return TicketSchedule(date: DateTime.now(), capacity: 0); // O lanza un error
      })
          .toList();
    }

    // Parseo del status
    ExperienceStatus currentStatus = ExperienceStatus.pending; // Valor por defecto
    if (data?['status'] is String) {
      currentStatus = ExperienceStatus.values.firstWhere(
            (e) => e.toString() == 'ExperienceStatus.${data!['status']}',
        orElse: () => ExperienceStatus.pending, // Fallback si el string no coincide
      );
    }

    return Experience(
      id: doc.id,
      title: data?['title'] as String? ?? 'Sin título',
      description: data?['description'] as String? ?? 'Sin descripción',
      imageAsset: data?['imageAsset'] as String? ?? 'assets/placeholder.jpg',
      location: data?['location'] as String? ?? 'Ubicación desconocida',
      rating: (data?['rating'] as num?)?.toDouble() ?? 0.0,
      price: (data?['price'] as num?)?.toInt() ?? 0,
      duration: data?['duration'] as String? ?? 'N/A',
      isVerified: data?['isVerified'] as bool? ?? false,
      isFeatured: data?['isFeatured'] as bool? ?? false,
      highlights: List<String>.from(data?['highlights'] ?? []),
      latitude: (data?['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data?['longitude'] as num?)?.toDouble() ?? 0.0,
      category: data?['category'] as String? ?? 'General',
      maxCapacity: (data?['maxCapacity'] as num?)?.toInt() ?? 0,
      bookedTickets: (data?['bookedTickets'] as num?)?.toInt() ?? 0,
      reviewsCount: (data?['reviewsCount'] as num?)?.toInt() ?? 0,
      schedule: parsedSchedule,
      creatorId: data?['creatorId'] as String? ?? '', // Proveer un fallback o manejar error
      status: currentStatus,
      submittedAt: (data?['submittedAt'] as Timestamp?)?.toDate(),
      lastUpdatedAt: (data?['lastUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Método para convertir esta instancia de Experience a un Map para Firestore.
  /// No incluye el 'id' porque Firestore lo maneja (especialmente para .add()).
  /// Para .update() o .set() en un doc existente, el ID se usa para obtener la referencia al doc.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title,
      'description': description,
      'imageAsset': imageAsset,
      'location': location,
      'rating': rating,
      'price': price,
      'duration': duration,
      'highlights': highlights,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      'maxCapacity': maxCapacity, // Podría ser calculado desde `schedule` al momento de guardar
      'bookedTickets': bookedTickets, // Podría ser calculado desde `schedule` al momento de guardar
      'reviewsCount': reviewsCount,
      'schedule': schedule.map((s) => s.toMap()).toList(),
      'creatorId': creatorId,
      'status': status.toString().split('.').last, // Guarda el nombre del enum como string
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : FieldValue.serverTimestamp(), // Usar serverTimestamp si es nuevo
      'lastUpdatedAt': FieldValue.serverTimestamp(), // Siempre usa serverTimestamp para la última actualización
    };
  }

  // (Opcional) Método copyWith para facilitar la creación de nuevas instancias con algunos campos modificados
  Experience copyWith({
    String? id,
    String? title,
    String? description,
    String? imageAsset,
    String? location,
    double? rating,
    int? price,
    String? duration,
    List<String>? highlights,
    double? latitude,
    double? longitude,
    String? category,
    bool? isVerified,
    bool? isFeatured,
    int? maxCapacity,
    int? bookedTickets,
    int? reviewsCount,
    List<TicketSchedule>? schedule,
    String? creatorId,
    ExperienceStatus? status,
    DateTime? submittedAt,
    DateTime? lastUpdatedAt,
    // No incluyas id aquí si no quieres que se pueda cambiar fácilmente con copyWith
    // El id es generalmente inmutable una vez asignado por Firestore.
  }) {
    return Experience(
      id: id ?? this.id, // O simplemente this.id si el id no debe ser copiado
      title: title ?? this.title,
      description: description ?? this.description,
      imageAsset: imageAsset ?? this.imageAsset,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      highlights: highlights ?? this.highlights,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      bookedTickets: bookedTickets ?? this.bookedTickets,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      schedule: schedule ?? this.schedule,
      creatorId: creatorId ?? this.creatorId,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

// Asegúrate de tener la definición de TicketSchedule disponible.
// Por ejemplo:
class TicketSchedule {
  final DateTime date;
  final int capacity;
  final int bookedTickets;

  TicketSchedule({
    required this.date,
    required this.capacity,
    this.bookedTickets = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'capacity': capacity,
      'bookedTickets': bookedTickets,
    };
  }

  factory TicketSchedule.fromMap(Map<String, dynamic> map) {
    return TicketSchedule(
      date: (map['date'] as Timestamp).toDate(),
      capacity: map['capacity'] as int? ?? 0,
      bookedTickets: map['bookedTickets'] as int? ?? 0,
    );
  }
}
