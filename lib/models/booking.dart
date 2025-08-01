import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo simple para una reserva (`Booking`).
class Booking {
  final String id;
  final String userId;
  final String experienceId;
  final String experienceTitle;
  final String experienceImage;
  final DateTime bookingDate; // La fecha específica de la reserva.
  final int numberOfPeople;
  final String status;
  final DateTime createdAt;

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
  });

  /// Constructor de fábrica para crear una instancia de Booking desde un DocumentSnapshot de Firestore.
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Booking(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      experienceId: data?['experienceId'] as String? ?? '',
      experienceTitle: data?['experienceTitle'] as String? ?? 'Experiencia Desconocida',
      experienceImage: data?['experienceImage'] as String? ?? 'assets/placeholder.jpg',
      bookingDate: (data?['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      numberOfPeople: (data?['numberOfPeople'] as num?)?.toInt() ?? 1,
      status: data?['status'] as String? ?? 'pending',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
