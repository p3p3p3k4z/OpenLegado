import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para representar el feedback de un usuario (calificación y comentario)
/// sobre una experiencia. Esto se usaría como un documento en una subcolección de
/// "feedback" dentro de cada experiencia en Firestore.
class ExperienceFeedback {
  final String id;
  final String userId;
  final String userName; // Nombre del usuario que deja el comentario
  final double rating; // Calificación de 1.0 a 5.0
  final String comment;
  final Timestamp createdAt;

  const ExperienceFeedback({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  /// Constructor de fábrica para crear una instancia de ExperienceFeedback desde un DocumentSnapshot.
  factory ExperienceFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return ExperienceFeedback(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      userName: data?['userName'] as String? ?? 'Anónimo',
      rating: (data?['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data?['comment'] as String? ?? '',
      createdAt: data?['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
