// models/review.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String userName; // Para mostrar el nombre del autor
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

  // Convertir un objeto Review a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'experienceId': experienceId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt), // Firestore usa Timestamps
    };
  }

  // Crear un objeto Review desde un Firestore DocumentSnapshot
  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Review(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Usuario Anónimo',
      experienceId: data['experienceId'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
