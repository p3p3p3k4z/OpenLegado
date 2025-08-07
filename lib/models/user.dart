import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para representar un usuario de la aplicación.
class AppUser {
  final String uid; // ID único del usuario
  final String email;
  final String? name; // Nombre del usuario, opcional
  final String role; // Rol del usuario: 'user', 'moderator', o 'admin'
  final String? profileImageUrl; // URL de la imagen de perfil del usuario
  final List<String> interests; // Lista de intereses del usuario
  final List<String> savedExperiences; // IDs de las experiencias guardadas/favoritas
  final int experiencesSubmitted; // Cantidad de experiencias subidas por este usuario

  /// Constructor principal para crear una instancia de AppUser.
  const AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.role = 'user',
    this.profileImageUrl,
    this.interests = const [],
    this.savedExperiences = const [],
    this.experiencesSubmitted = 0,
  });

  /// Constructor de fábrica para crear una instancia de AppUser desde un DocumentSnapshot de Firestore.
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return AppUser(
      uid: doc.id,
      email: data?['email'] as String? ?? '',
      name: data?['name'] as String?,
      role: data?['role'] as String? ?? 'user',
      profileImageUrl: data?['profileImageUrl'] as String?,
      interests: List<String>.from(data?['interests'] ?? []),
      savedExperiences: List<String>.from(data?['savedExperiences'] ?? []),
      experiencesSubmitted: (data?['experiencesSubmitted'] as num?)?.toInt() ?? 0,
    );
  }

  /// Método para convertir una instancia de AppUser a un mapa para subir a Firestore.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'interests': interests,
      'savedExperiences': savedExperiences,
      'experiencesSubmitted': experiencesSubmitted,
    };
  }
}
