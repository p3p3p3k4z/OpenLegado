import 'package:flutter/material.dart';

class ExploreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Explorar',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: Color(0xFFE67E22)),
            onPressed: () {
              // TODO: Implementar filtros
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Mapa integrado (placeholder)
          Container(
            height: 300,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  // Placeholder del mapa
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFE67E22).withOpacity(0.8),
                          Color(0xFF8B4513).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, size: 48, color: Colors.white70),
                          SizedBox(height: 8),
                          Text(
                            'Mapa Interactivo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Controles del mapa
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        _buildMapControl(Icons.list, () {}),
                        SizedBox(height: 8),
                        _buildMapControl(Icons.sort, () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Experiencias destacadas
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Experiencias Destacadas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildFeaturedExperience(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Color(0xFFE67E22)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildFeaturedExperience() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 120,
          child: Row(
            children: [
              // Imagen
              Container(
                width: 120,
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
                    Icons.palette,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              // Contenido
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Taller de Barro Negro',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'San Bartolo Coyotepec, Oaxaca',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$350 MXN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE67E22),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              minimumSize: Size(80, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Ver más',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
