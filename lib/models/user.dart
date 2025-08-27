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
  final bool isDisabled;

  // --- NUEVOS CAMPOS AÑADIDOS ---
  final String? bio;                     // Para la biografía del usuario/artesano
  final List<String> galleryImageUrls;  // Para la galería de muestra del artesano

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
    this.isDisabled = false,
    // --- INICIALIZACIÓN DE NUEVOS CAMPOS ---
    this.bio,                            // Puede ser nulo si no se proporciona
    List<String>? galleryImageUrls,      // Puede ser nulo si no se proporciona
  })  : interests = interests ?? [],
        savedExperiences = savedExperiences ?? [],
  // Inicializar la lista de galería vacía si es nula
        galleryImageUrls = galleryImageUrls ?? []; // Asegura que siempre sea una lista

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento de usuario vacío para uid: ${snapshot.id}");

    return AppUser(
      uid: snapshot.id,
      email: data['email'] as String?,
      username: data['username'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?, // Usaremos este para la foto de perfil
      role: data['role'] as String? ?? 'user',
      interests: List<String>.from(data['interests'] as List<dynamic>? ?? []),
      savedExperiences: List<String>.from(data['savedExperiences'] as List<dynamic>? ?? []),
      experiencesSubmitted: (data['experiencesSubmitted'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      communitiesSupported: (data['communitiesSupported'] as num?)?.toInt() ?? 0,
      artisansMet: (data['artisansMet'] as num?)?.toInt() ?? 0,
      isDisabled: data['isDisabled'] as bool? ?? false,
      // --- LECTURA DE NUEVOS CAMPOS DESDE FIRESTORE ---
      bio: data['bio'] as String?, // Leer la biografía
      // Leer la lista de URLs de la galería, asegurando que sea una lista de Strings
      galleryImageUrls: List<String>.from(data['galleryImageUrls'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toMap({bool forCreation = false}) {
    final map = <String, dynamic>{
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
      'isDisabled': isDisabled,
      // --- AÑADIR NUEVOS CAMPOS AL MAPA PARA GUARDAR EN FIRESTORE ---
      'bio': bio,
      'galleryImageUrls': galleryImageUrls,
    };

    if (forCreation) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['lastLoginAt'] = FieldValue.serverTimestamp();
      // Podrías inicializar 'bio' y 'galleryImageUrls' con valores por defecto si lo deseas al crear
      // map['bio'] = map['bio'] ?? ''; // Asegura que no sea nulo si no se proporcionó
      // map['galleryImageUrls'] = map['galleryImageUrls'] ?? []; // Asegura que no sea nulo
    } else {
      if (createdAt != null) {
        map['createdAt'] = Timestamp.fromDate(createdAt!);
      }
      if (lastLoginAt != null) {
        map['lastLoginAt'] = Timestamp.fromDate(lastLoginAt!);
      }
    }
    // No eliminar campos nulos aquí a menos que tengas una razón específica,
    // Firestore maneja bien los campos nulos o puedes usar FieldValue.delete() si quieres borrarlos.
    // Si 'bio' es null, se guardará como null. Si es una cadena vacía, se guardará como "".
    return map;
  }
}
