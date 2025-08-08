import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase de modelo para representar una experiencia cultural en la aplicación Legado.
class Experience {
  final String id;
  final String title;
  final String description;
  final String imageAsset; // Ruta del asset local o URL de imagen
  final String location;
  final double rating; // Calificación promedio de todas las reseñas
  final int price; // Precio en MXN
  final String duration;
  final List<String> highlights; // Lista de puntos destacados
  final double latitude;
  final double longitude;
  final String category; // Categoría de la experiencia

  // Nuevos campos para la gestión y el feedback
  final bool isVerified; // Si la experiencia ha sido verificada por un admin
  final bool isFeatured; // Si la experiencia se destaca en la página principal
  final int maxCapacity; // Cupo máximo de personas
  final int bookedTickets; // Número de boletos ya reservados
  final int reviewsCount; // Cantidad de comentarios

  /// Constructor principal para crear una instancia de Experience.
  const Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.location,
    this.rating = 0.0,
    this.price = 0,
    required this.duration,
    this.isVerified = false,
    this.isFeatured = false,
    this.highlights = const [],
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.category,
    this.maxCapacity = 0,
    this.bookedTickets = 0,
    this.reviewsCount = 0,
  });

  /// Constructor de fábrica para crear una instancia de Experience desde un DocumentSnapshot de Firestore.
  factory Experience.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return Experience(
      id: doc.id,
      title: data?['title'] as String? ?? 'Sin título',
      description: data?['description'] as String? ?? 'Sin descripción',
      imageAsset: data?['imageAsset'] as String? ?? 'assets/placeholder.jpg',
      location: data?['location'] as String? ?? 'Ubicación desconocida',
      rating: (data?['rating'] as num?)?.toDouble() ?? 0.0,
      price: (data?['price'] as num?)?.toInt() ?? 0,
      duration: data?['duration'] as String? ?? 'N/A',
      isVerified: data?['isVerified'] as bool? ?? false,
      isFeatured: data?['isFeatured'] as bool? ?? false,
      highlights: List<String>.from(data?['highlights'] ?? []),
      latitude: (data?['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data?['longitude'] as num?)?.toDouble() ?? 0.0,
      category: data?['category'] as String? ?? 'General',
      maxCapacity: (data?['maxCapacity'] as num?)?.toInt() ?? 0,
      bookedTickets: (data?['bookedTickets'] as num?)?.toInt() ?? 0,
      reviewsCount: (data?['reviewsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Clase con datos estáticos para experiencias.
class ExperienceData {
  static final List<Experience> _allExperiences = [
    Experience(
      id: 'exp001',
      title: 'Taller de Barro Negro',
      description: 'Sumérgete en el arte ancestral del barro negro de Oaxaca. Aprende las técnicas tradicionales de moldeo y bruñido para crear tu propia pieza única bajo la guía de maestros artesanos.',
      imageAsset: 'assets/barro_negro.jpg',
      location: 'San Bartolo Coyotepec, Oaxaca',
      rating: 4.8,
      price: 350,
      duration: '3 horas',
      isVerified: true,
      isFeatured: true,
      highlights: ['Materiales incluidos', 'Guía experto', 'Tu pieza de barro'],
      latitude: 16.9602,
      longitude: -96.6908,
      category: 'Arte y Artesanía',
      maxCapacity: 10,
      bookedTickets: 5,
      reviewsCount: 25,
    ),
    Experience(
      id: 'exp002',
      title: 'Cocina de Mole en Cazuela',
      description: 'Descubre los secretos del mole poblano auténtico. Participa en la preparación de este platillo icónico desde la selección de ingredientes hasta su cocción lenta en cazuela de barro.',
      imageAsset: 'assets/mole_poblano.jpg',
      location: 'Puebla, Puebla',
      rating: 4.9,
      price: 420,
      duration: '4 horas',
      isVerified: true,
      isFeatured: false,
      highlights: ['Recetas tradicionales', 'Degustación', 'Libro de recetas'],
      latitude: 19.0414,
      longitude: -98.2063,
      category: 'Gastronomía',
      maxCapacity: 8,
      bookedTickets: 8,
      reviewsCount: 30,
    ),
    Experience(
      id: 'exp003',
      title: 'Tejido de Sarapes',
      description: 'Conoce el arte del tejido de sarapes en Teotitlán del Valle. Aprende sobre los tintes naturales y la simbología de los diseños mientras creas un pequeño telar.',
      imageAsset: 'assets/sarapes.jpg',
      location: 'Teotitlán del Valle, Oaxaca',
      rating: 4.7,
      price: 380,
      duration: '3.5 horas',
      isVerified: true,
      isFeatured: true,
      highlights: ['Tintes naturales', 'Técnicas de telar', 'Tu propio diseño'],
      latitude: 17.0371,
      longitude: -96.5369,
      category: 'Arte y Artesanía',
      maxCapacity: 12,
      bookedTickets: 3,
      reviewsCount: 15,
    ),
    Experience(
      id: 'exp004',
      title: 'Ruta del Mezcal Artesanal',
      description: 'Explora los palenques tradicionales de mezcal en Oaxaca. Aprende sobre el proceso de elaboración, desde el agave hasta la degustación.',
      imageAsset: 'assets/mezcal.jpg',
      location: 'Santiago Matatlán, Oaxaca',
      rating: 4.6,
      price: 500,
      duration: '5 horas',
      isVerified: false,
      isFeatured: false,
      highlights: ['Visita a palenque', 'Degustación guiada', 'Historia del mezcal'],
      latitude: 16.9023,
      longitude: -96.3845,
      category: 'Gastronomía',
      maxCapacity: 15,
      bookedTickets: 12,
      reviewsCount: 50,
    ),
    Experience(
      id: 'exp005',
      title: 'Danza de los Diablos',
      description: 'Una inmersión en la vibrante Danza de los Diablos de Cuajinicuilapa. Conoce la historia, el vestuario y los pasos de este baile afro-mexicano.',
      imageAsset: 'assets/danza.jpg',
      location: 'Cuajinicuilapa, Guerrero',
      rating: 4.5,
      price: 250,
      duration: '2 horas',
      isVerified: false,
      isFeatured: false,
      highlights: ['Clase de danza', 'Historia cultural', 'Interacción con bailarines'],
      latitude: 16.4468,
      longitude: -98.4061,
      category: 'Música y Danza',
      maxCapacity: 20,
      bookedTickets: 18,
      reviewsCount: 10,
    ),
    Experience(
      id: 'exp006',
      title: 'Ceremonia de Temazcal',
      description: 'Experimenta una antigua ceremonia de temazcal para la purificación del cuerpo y el espíritu, guiada por un chamán tradicional.',
      imageAsset: 'assets/temazcal.jpg',
      location: 'Tepoztlán, Morelos',
      rating: 4.9,
      price: 600,
      duration: '4 horas',
      isVerified: true,
      isFeatured: true,
      highlights: ['Purificación', 'Conexión espiritual', 'Guía chamánica'],
      latitude: 18.9863,
      longitude: -99.0963,
      category: 'Bienestar',
      maxCapacity: 6,
      bookedTickets: 2,
      reviewsCount: 40,
    ),
  ];

  static List<Experience> getExperiencesByCategory(String category) {
    if (category == 'Todas') {
      return _allExperiences;
    } else {
      return _allExperiences.where((exp) => exp.category == category).toList();
    }
  }

  static List<String> getCategories() {
    return [
      'Todas',
      'Gastronomía',
      'Arte y Artesanía',
      'Patrimonio',
      'Naturaleza y Aventura',
      'Música y Danza',
      'Bienestar',
    ];
  }

  static List<Experience> getFeaturedExperiences() {
    return _allExperiences.where((exp) => exp.isFeatured).toList();
  }
}
