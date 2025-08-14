import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo simple para una reserva (`Booking`).
class Booking {
  final String id;
  final String userId;
  final String experienceId;
  final String experienceTitle;
  final String experienceImage;
  final DateTime bookingDate; // Fecha en que se creó la reserva
  final int numberOfPeople;
  final String status;
  final DateTime createdAt;

  // Campos nuevos para el sistema de schedule y precios
  final DateTime? scheduleDate;    // Fecha y hora específicas del schedule reservado (si aplica)
  final double ticketPrice;       // Precio de un boleto al momento de la reserva
  final double totalAmount;       // Monto total de la reserva (ticketPrice * numberOfPeople)
  DateTime? updatedAt;          // Opcional: para rastrear cuándo se actualizó la reserva

  Booking({
    required this.id,
    required this.userId,
    required this.experienceId,
    required this.experienceTitle,
    required this.experienceImage,
    required this.bookingDate,
    required this.numberOfPeople,
    required this.status,
    required this.createdAt,
    // Parámetros nuevos
    this.scheduleDate,
    required this.ticketPrice,
    required this.totalAmount,
    this.updatedAt,
  });

  /// Constructor de fábrica para crear una instancia de Booking desde un DocumentSnapshot de Firestore.
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Valores por defecto o manejo de nulos robusto
    final String defaultTitle = 'Experiencia Desconocida';
    final String defaultImage = 'assets/images/placeholder.png'; // Asegúrate que esta ruta sea correcta
    final DateTime now = DateTime.now();

    return Booking(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      experienceId: data?['experienceId'] as String? ?? '',
      experienceTitle: data?['experienceTitle'] as String? ?? defaultTitle,
      experienceImage: data?['experienceImage'] as String? ?? defaultImage,
      bookingDate: (data?['bookingDate'] as Timestamp?)?.toDate() ?? now,
      numberOfPeople: (data?['numberOfPeople'] as num?)?.toInt() ?? 1,
      status: data?['status'] as String? ?? 'pending',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? now,
      // Lectura de campos nuevos
      scheduleDate: (data?['scheduleDate'] as Timestamp?)?.toDate(), // Puede ser null
      ticketPrice: (data?['ticketPrice'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data?['totalAmount'] as num?)?.toDouble() ?? 0.0,
      updatedAt: (data?['updatedAt'] as Timestamp?)?.toDate(), // Puede ser null
    );
  }

  /// Método para convertir una instancia de Booking a un mapa para subir a Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'experienceId': experienceId,
      'experienceTitle': experienceTitle,
      'experienceImage': experienceImage,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'numberOfPeople': numberOfPeople,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      // Escritura de campos nuevos
      'scheduleDate': scheduleDate != null ? Timestamp.fromDate(scheduleDate!) : null,
      'ticketPrice': ticketPrice,
      'totalAmount': totalAmount,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(), // Usar serverTimestamp para la actualización inicial si es null
    };
  }
}
