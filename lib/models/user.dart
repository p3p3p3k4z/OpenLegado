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
  final int communitiesSupported;
  final int artisansMet;
  final bool isDisabled; // <--- AÑADIR CAMPO PARA SOFT DELETE

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
    this.communitiesSupported = 0,
    this.artisansMet = 0,
    this.isDisabled = false, // <--- VALOR POR DEFECTO
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
      communitiesSupported: (data['communitiesSupported'] as num?)?.toInt() ?? 0,
      artisansMet: (data['artisansMet'] as num?)?.toInt() ?? 0,
      isDisabled: data['isDisabled'] as bool? ?? false, // <--- LEER DESDE FIRESTORE
    );
  }

  Map<String, dynamic> toMap({bool forCreation = false}) {
    final map = <String, dynamic>{ // Especificar el tipo del mapa
      'uid': uid,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'interests': interests,
      'savedExperiences': savedExperiences,
      'experiencesSubmitted': experiencesSubmitted,
      'communitiesSupported': communitiesSupported,
      'artisansMet': artisansMet,
      'isDisabled': isDisabled, // <--- AÑADIR AL MAPA
    };

    if (forCreation) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['lastLoginAt'] = FieldValue.serverTimestamp(); // También al crear
    } else {
      if (createdAt != null) {
        map['createdAt'] = Timestamp.fromDate(createdAt!);
      }
      // Considera si lastLoginAt se actualiza aquí o solo en el login real
      if (lastLoginAt != null) {
        map['lastLoginAt'] = Timestamp.fromDate(lastLoginAt!);
      }
    }
    return map;
  }
}
