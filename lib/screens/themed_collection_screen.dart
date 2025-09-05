// lib/screens/themed_collection_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Asegúrate que las rutas de importación sean correctas para tu proyecto:
import '../models/experience.dart'; // <<< TU MODELO EXPERIENCE
import '../models/themed_collection.dart'; // <<< TU MODELO THEMEDCOLLECTION
import 'experience_detail_screen.dart'; // <<< TU PANTALLA DE DETALLE DE EXPERIENCIA

// Constantes de estilo
const Color kAppAccentColor = Color(0xFF4E1E0A);
const Color kAppTextColor = Color(0xFF311F14);
const String kAppFontFamily = 'Montserrat';

class ThemedCollectionScreen extends StatefulWidget {
  final ThemedCollection collection;

  const ThemedCollectionScreen({super.key, required this.collection});

  @override
  State<ThemedCollectionScreen> createState() => _ThemedCollectionScreenState();
}

class _ThemedCollectionScreenState extends State<ThemedCollectionScreen> {
  late Future<List<Experience>> _experiencesFuture;

  @override
  void initState() {
    super.initState();
    _experiencesFuture = _fetchExperiencesForCollection();
  }

  Future<List<Experience>> _fetchExperiencesForCollection() async {
    if (widget.collection.experienceIds.isEmpty) {
      print("INFO (ThemedCollectionScreen): Colección '${widget.collection.title}' no tiene IDs de experiencias.");
      return [];
    }

    List<Experience> fetchedExperiences = [];
    List<Future<DocumentSnapshot<Map<String, dynamic>>>> experienceFutures = [];
    print("INFO (ThemedCollectionScreen): Buscando ${widget.collection.experienceIds.length} experiencias para '${widget.collection.title}'. IDs: ${widget.collection.experienceIds}");

    for (String id in widget.collection.experienceIds) {
      if (id.trim().isNotEmpty) {
        experienceFutures.add(FirebaseFirestore.instance.collection('experiences').doc(id.trim()).get());
      }
    }

    if (experienceFutures.isEmpty) return [];

    try {
      final List<DocumentSnapshot<Map<String, dynamic>>> documents = await Future.wait(experienceFutures);
      for (var doc in documents) {
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['status'] == 'approved') {
            try {
              fetchedExperiences.add(Experience.fromFirestore(doc as DocumentSnapshot<Map<String,dynamic>>)); // Cast explícito
            } catch (e) {
              print("ERROR (ThemedCollectionScreen): Fallo al deserializar la experiencia ID: ${doc.id}. Error: $e");
            }
          } else {
            print("INFO (ThemedCollectionScreen): Experiencia ID: ${doc.id} no aprobada (status: ${data?['status']}) o datos nulos.");
          }
        } else {
          print("WARN (ThemedCollectionScreen): Documento de experiencia no encontrado para ID: ${doc.id}.");
        }
      }
    } catch (e, stackTrace) {
      print("ERROR_CRITICO (ThemedCollectionScreen): Fallo al obtener docs de experiencias: $e");
      print(stackTrace);
    }
    print("INFO (ThemedCollectionScreen): ${fetchedExperiences.length} experiencias cargadas para '${widget.collection.title}'.");
    return fetchedExperiences;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: kAppAccentColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 12.0),
              title: Text(
                widget.collection.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontSize: 17.0, fontWeight: FontWeight.bold, fontFamily: kAppFontFamily,
                  shadows: [Shadow(blurRadius: 2.0, color: Colors.black54, offset: Offset(1,1))],
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              background: widget.collection.coverImageUrl.isNotEmpty
                  ? Image.network(
                widget.collection.coverImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(color:kAppAccentColor))),
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))),
              )
                  : Container(color: kAppAccentColor.withOpacity(0.6), child: const Center(child: Icon(Icons.collections_bookmark_outlined, size: 70, color: Colors.white60))),
              stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
              child: Text(
                widget.collection.description,
                style: TextStyle(fontSize: 15, color: Colors.grey[800], fontFamily: kAppFontFamily, height: 1.4),
              ),
            ),
          ),
          FutureBuilder<List<Experience>>(
            future: _experiencesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: kAppAccentColor)));
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('Error al cargar experiencias.\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontFamily: kAppFontFamily)),
                )));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No hay experiencias disponibles en "${widget.collection.title}" en este momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16, fontFamily: kAppFontFamily),
                  ),
                )));
              }
              final experiences = snapshot.data!;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                      return _buildExperienceListItem(context, experiences[index]);
                    },
                    childCount: experiences.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceListItem(BuildContext context, Experience experience) {
    // --- LÓGICA DE IMAGEN AJUSTADA ---
    // Asume que 'experience.imageAsset' es el campo que contiene la URL o ruta del asset.
    Widget imageWidget;
    if (experience.imageAsset.isNotEmpty) {
      if (experience.imageAsset.startsWith('http')) {
        imageWidget = Image.network(
          experience.imageAsset,
          width: 90, height: 90, fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(width: 90, height: 90, color: Colors.grey[100], child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kAppAccentColor))),
          errorBuilder: (ctx, err, stack) => Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24)),
        );
      } else { // Asume que es un asset local si no empieza con http
        imageWidget = Image.asset(
          experience.imageAsset, // O 'assets/images/${experience.imageAsset}' si solo guardas el nombre del archivo
          width: 90, height: 90, fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24)),
        );
      }
    } else { // Fallback si imageAsset está vacío
      imageWidget = Image.asset(
        'assets/images/placeholder.png', // <<< ASEGÚRATE DE TENER ESTE ASSET
        width: 90, height: 90, fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24)),
      );
    }
    // --- FIN DE LÓGICA DE IMAGEN AJUSTADA ---

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ExperienceDetailScreen(experience: experience)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: imageWidget,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kAppTextColor, fontFamily: kAppFontFamily),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.location, // Asumiendo que tu Experience tiene 'location'
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: kAppFontFamily),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // Asumiendo que tu Experience tiene 'price'
                      '\$${experience.price.toStringAsFixed(2)} MXN',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kAppAccentColor, fontFamily: kAppFontFamily),
                    ),
                    // Mostrar rating si tu Experience tiene 'rating' y es mayor a 0
                    if (experience.rating > 0) ...[ // El '...' es el operador spread
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            experience.rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500, fontFamily: kAppFontFamily),
                          ),
                          // Mostrar número de reseñas si tu Experience tiene 'reviewsCount' y es mayor a 0
                          // if (experience.reviewsCount > 0) // Comentado por si no tienes 'reviewsCount'
                          //   Text(" (${experience.reviewsCount})", style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: kAppFontFamily)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
