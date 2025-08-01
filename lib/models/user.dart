import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para representar un usuario de la aplicación.
class AppUser {
  final String uid; // ID único del usuario
  final String email;
  final String role; // NUEVO: Rol del usuario: 'user', 'moderator' o 'admin'
  final int experiencesSubmitted; // Cantidad de experiencias subidas
  final List<String> interests; // Lista de intereses del usuario
  final Timestamp? lastInterestUpdate; // Fecha de la última actualización de intereses
  final List<String> savedExperiences; // IDs de las experiencias guardadas

  /// Constructor principal para crear una instancia de AppUser.
  const AppUser({
    required this.uid,
    required this.email,
    this.role = 'user',
    this.experiencesSubmitted = 0,
    this.interests = const [],
    this.lastInterestUpdate,
    this.savedExperiences = const [],
  });

  /// Constructor de fábrica para crear una instancia de AppUser desde un DocumentSnapshot de Firestore.
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Se extraen los datos y se manejan los posibles valores nulos con valores por defecto.
    return AppUser(
      uid: doc.id,
      email: data?['email'] as String? ?? '',
      role: data?['role'] as String? ?? 'user',
      experiencesSubmitted: (data?['experiencesSubmitted'] as num?)?.toInt() ?? 0,
      interests: List<String>.from(data?['interests'] ?? []),
      lastInterestUpdate: data?['lastInterestUpdate'] as Timestamp?,
      savedExperiences: List<String>.from(data?['savedExperiences'] ?? []),
    );
  }

  /// Método para convertir una instancia de AppUser a un mapa para subir a Firestore.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'experiencesSubmitted': experiencesSubmitted,
      'interests': interests,
      'lastInterestUpdate': lastInterestUpdate,
      'savedExperiences': savedExperiences,
    };
  }
}
