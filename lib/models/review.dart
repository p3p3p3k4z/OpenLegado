import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para una `Review`.
/// Esto nos ayuda a estructurar los datos de una reseña en un objeto Dart.
class Review {
  final String id;
  final String userId;
  final String userName;
  final String experienceId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.experienceId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  /// Constructor de fábrica para crear una instancia de Review desde un DocumentSnapshot de Firestore.
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Review(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      userName: data?['userName'] as String? ?? 'Anónimo',
      experienceId: data?['experienceId'] as String? ?? '',
      rating: (data?['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data?['comment'] as String? ?? '',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Método para convertir una instancia de Review a un mapa para subir a Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'experienceId': experienceId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
    };
  }
}
