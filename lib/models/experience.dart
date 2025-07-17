class Experience {
  final String id;
  final String title;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final int price;
  final String duration;
  final String category;
  final String imageAsset;
  final double rating;
  final bool isVerified;
  final bool isFeatured;
  final List<String> highlights;

  Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.duration,
    required this.category,
    required this.imageAsset,
    required this.rating,
    this.isVerified = false,
    this.isFeatured = false,
    this.highlights = const [],
  });

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'price': price,
      'duration': duration,
      'category': category,
      'imageAsset': imageAsset,
      'rating': rating,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      'highlights': highlights,
    };
  }

  // Crear desde JSON
  factory Experience.fromJson(Map<String, dynamic> json) {
    return Experience(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      price: json['price'] ?? 0,
      duration: json['duration'] ?? '',
      category: json['category'] ?? '',
      imageAsset: json['imageAsset'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      isVerified: json['isVerified'] ?? false,
      isFeatured: json['isFeatured'] ?? false,
      highlights: List<String>.from(json['highlights'] ?? []),
    );
  }
}

// Datos de ejemplo - en una app real vendrían de una API
class ExperienceData {
  static List<Experience> getSampleExperiences() {
    return [
      Experience(
        id: '1',
        title: 'Taller de Barro Negro',
        description: 'Aprende la técnica ancestral del barro negro en San Bartolo Coyotepec, una tradición que ha pasado de generación en generación.',
        location: 'San Bartolo Coyotepec, Oaxaca',
        latitude: 16.9481,
        longitude: -96.6906,
        price: 350,
        duration: '2h',
        category: 'Arte y Artesanía',
        imageAsset: 'assets/barro_negro.jpg',
        rating: 4.8,
        isVerified: true,
        isFeatured: true,
        highlights: [
          'Técnica ancestral zapoteca',
          'Materiales incluidos',
          'Certificado de autenticidad',
        ],
      ),
      Experience(
        id: '2',
        title: 'Cocina de Mole en Cazuela',
        description: 'Sumérgete en los secretos del mole poblano tradicional, preparado con ingredientes locales y técnicas centenarias.',
        location: 'Puebla, Puebla',
        latitude: 19.0414,
        longitude: -98.2063,
        price: 420,
        duration: '3h',
        category: 'Gastronomía',
        imageAsset: 'assets/mole_poblano.jpg',
        rating: 4.9,
        isVerified: false,
        isFeatured: true,
        highlights: [
          'Ingredientes orgánicos',
          'Receta familiar secreta',
          'Degustación incluida',
        ],
      ),
      Experience(
        id: '3',
        title: 'Tejido de Sarapes',
        description: 'Descubre el arte del tejido tradicional en telar de cintura, una técnica milenaria que aún se practica en Teotitlán del Valle.',
        location: 'Teotitlán del Valle, Oaxaca',
        latitude: 16.9167,
        longitude: -96.5500,
        price: 380,
        duration: '2h',
        category: 'Arte y Artesanía',
        imageAsset: 'assets/sarapes.jpg',
        rating: 4.7,
        isVerified: true,
        isFeatured: false,
        highlights: [
          'Telar de cintura auténtico',
          'Tintes naturales',
          'Llévate tu creación',
        ],
      ),
      Experience(
        id: '4',
        title: 'Ruta del Mezcal Artesanal',
        description: 'Recorrido por las palenques tradicionales donde se produce el mezcal artesanal, con degustación y maridaje.',
        location: 'Santiago Matatlán, Oaxaca',
        latitude: 16.8667,
        longitude: -96.3833,
        price: 580,
        duration: '4h',
        category: 'Gastronomía',
        imageAsset: 'assets/fondo_mexicano.jpg',
        rating: 4.9,
        isVerified: true,
        isFeatured: true,
        highlights: [
          'Visita a 3 palenques',
          'Degustación de 8 mezcales',
          'Maridaje con comida local',
          'Transporte incluido',
        ],
      ),
      Experience(
        id: '5',
        title: 'Medicina Tradicional Maya',
        description: 'Aprende sobre las plantas medicinales y técnicas de curación ancestrales de la cultura maya.',
        location: 'Yaxunah, Yucatán',
        latitude: 20.7167,
        longitude: -88.9500,
        price: 280,
        duration: '2.5h',
        category: 'Bienestar',
        imageAsset: 'assets/fondo-mexico.webp',
        rating: 4.6,
        isVerified: false,
        isFeatured: false,
        highlights: [
          'Guía curandero local',
          'Plantas medicinales',
          'Temazcal opcional',
        ],
      ),
    ];
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

  static List<Experience> getExperiencesByCategory(String category) {
    final experiences = getSampleExperiences();
    if (category == 'Todas') {
      return experiences;
    }
    return experiences.where((exp) => exp.category == category).toList();
  }

  static List<Experience> getFeaturedExperiences() {
    return getSampleExperiences().where((exp) => exp.isFeatured).toList();
  }

  static List<Experience> getVerifiedExperiences() {
    return getSampleExperiences().where((exp) => exp.isVerified).toList();
  }
}
