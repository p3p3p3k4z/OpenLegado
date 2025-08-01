import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para interactuar con Firebase Firestore.
/// Centraliza la lógica de acceso a la base de datos para mantener
/// el resto del código limpio y reutilizable.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene un Stream de un documento de usuario por su UID.
  /// Esto es útil para escuchar cambios en el rol del usuario en tiempo real.
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

// Aquí podrías agregar más métodos para otras colecciones,
// como obtener experiencias, reservas, etc.
}
