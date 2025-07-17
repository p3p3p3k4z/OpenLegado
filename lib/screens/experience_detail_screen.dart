import 'package:flutter/material.dart';
import '../models/experience.dart';

class ExperienceDetailScreen extends StatefulWidget {
  final Experience experience;

  const ExperienceDetailScreen({Key? key, required this.experience}) : super(key: key);

  @override
  _ExperienceDetailScreenState createState() => _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar con imagen
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Color(0xFF8B4513),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
              ),
              IconButton(
                icon: Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  // TODO: Implementar compartir
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen de fondo
                  Image.asset(
                    widget.experience.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFE67E22),
                            Color(0xFF8B4513),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  // Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Badges
                  Positioned(
                    top: 60,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.experience.isVerified)
                          _buildBadge('Verificado', Color(0xFF4CAF50), Icons.verified),
                        if (widget.experience.isFeatured)
                          _buildBadge('Destacado', Color(0xFFFF9800), Icons.star),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  _buildHeader(),
                  SizedBox(height: 24),
                  
                  // Descripción
                  _buildDescription(),
                  SizedBox(height: 24),
                  
                  // Highlights
                  _buildHighlights(),
                  SizedBox(height: 24),
                  
                  // Ubicación
                  _buildLocation(),
                  SizedBox(height: 24),
                  
                  // Precio y duración
                  _buildPriceAndDuration(),
                  SizedBox(height: 32),
                  
                  // Botón de reserva
                  _buildBookingButton(),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.experience.title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, size: 20, color: Color(0xFF8D6E63)),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.experience.location,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8D6E63),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            _buildRatingStars(),
            SizedBox(width: 8),
            Text(
              '${widget.experience.rating}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFE67E22).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.experience.category,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE67E22),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingStars() {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < widget.experience.rating.floor()
              ? Icons.star
              : index < widget.experience.rating
                  ? Icons.star_half
                  : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descripción',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        SizedBox(height: 12),
        Text(
          widget.experience.description,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF5D4037),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights() {
    if (widget.experience.highlights.isEmpty) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo que incluye',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        SizedBox(height: 12),
        ...widget.experience.highlights.map((highlight) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: Color(0xFF4CAF50),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  highlight,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Color(0xFFE67E22).withOpacity(0.1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 48,
                  color: Color(0xFFE67E22),
                ),
                SizedBox(height: 8),
                Text(
                  'Mapa Interactivo',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B4513),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Lat: ${widget.experience.latitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  'Lng: ${widget.experience.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceAndDuration() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.access_time,
                  size: 32,
                  color: Color(0xFFE67E22),
                ),
                SizedBox(height: 8),
                Text(
                  'Duración',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  widget.experience.duration,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 32,
                  color: Color(0xFF4CAF50),
                ),
                SizedBox(height: 8),
                Text(
                  'Precio',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                Text(
                  '\$${widget.experience.price}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
                Text(
                  'MXN',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          _showBookingDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFE67E22),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 20),
            SizedBox(width: 8),
            Text(
              'Reservar Experiencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          '¡Reserva Confirmada!',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Color(0xFF4CAF50),
            ),
            SizedBox(height: 16),
            Text(
              'Tu reserva para "${widget.experience.title}" ha sido confirmada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: Color(0xFFE67E22)),
            ),
          ),
        ],
      ),
    );
  }
}
