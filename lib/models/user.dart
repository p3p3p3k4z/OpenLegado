// models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? username;
  final String? profileImageUrl;
  final String role;
  final List<String> interests;
  final List<String> savedExperiences;
  final int experiencesSubmitted;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  // NUEVOS CAMPOS PARA ESTADÍSTICAS
  final int communitiesSupported;
  final int artisansMet;

  AppUser({
    required this.uid,
    this.email,
    this.username,
    this.profileImageUrl,
    this.role = 'user',
    List<String>? interests,
    List<String>? savedExperiences,
    this.experiencesSubmitted = 0,
    this.createdAt,
    this.lastLoginAt,
    // AÑADIR VALORES POR DEFECTO PARA LOS NUEVOS CAMPOS
    this.communitiesSupported = 0,
    this.artisansMet = 0,
  })  : interests = interests ?? [],
        savedExperiences = savedExperiences ?? [];

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento de usuario vacío para uid: ${snapshot.id}");

    return AppUser(
      uid: snapshot.id,
      email: data['email'] as String?,
      username: data['username'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      role: data['role'] as String? ?? 'user',
      interests: List<String>.from(data['interests'] as List<dynamic>? ?? []),
      savedExperiences: List<String>.from(data['savedExperiences'] as List<dynamic>? ?? []),
      experiencesSubmitted: (data['experiencesSubmitted'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      // LEER LOS NUEVOS CAMPOS DESDE FIRESTORE
      communitiesSupported: (data['communitiesSupported'] as num?)?.toInt() ?? 0,
      artisansMet: (data['artisansMet'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap({bool forCreation = false}) {
    final map = {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'interests': interests,
      'savedExperiences': savedExperiences,
      'experiencesSubmitted': experiencesSubmitted,
      // AÑADIR LOS NUEVOS CAMPOS AL MAPA PARA GUARDAR EN FIRESTORE
      'communitiesSupported': communitiesSupported,
      'artisansMet': artisansMet,
      // createdAt y lastLoginAt como los tenías
    };

    if (forCreation) {
      map['createdAt'] = FieldValue.serverTimestamp();
    } else if (createdAt != null) {
      map['createdAt'] = Timestamp.fromDate(createdAt!);
    }
    // Si manejas lastLoginAt:
    // map['lastLoginAt'] = lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : FieldValue.serverTimestamp();


    return map;
  }
}
