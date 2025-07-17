import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mi perfil',
          style: TextStyle(
            color: Color(0xFF8B4513),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Color(0xFFE67E22)),
            onPressed: () {
              // TODO: Implementar configuración
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Header del perfil
            _buildProfileHeader(),
            SizedBox(height: 24),
            
            // Estadísticas
            _buildStatsSection(),
            SizedBox(height: 24),
            
            // Experiencias favoritas
            _buildFavoritesSection(),
            SizedBox(height: 24),
            
            // Opciones del perfil
            _buildProfileOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFF8DC),
            Color(0xFFF5E6D3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE67E22),
                  Color(0xFF8B4513),
                ],
              ),
            ),
            child: Center(
              child: Text(
                'AH',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          
          // Nombre y nivel
          Text(
            'Alejandro Hernández',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFE67E22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Explorador Cultural',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('5', 'Experiencias\nCompletadas', Icons.check_circle)),
        SizedBox(width: 12),
        Expanded(child: _buildStatCard('3', 'Comunidades\nApoyadas', Icons.people)),
        SizedBox(width: 12),
        Expanded(child: _buildStatCard('12', 'Artesanos\nConocidos', Icons.handshake)),
      ],
    );
  }

  Widget _buildStatCard(String number, String label, IconData icon) {
    return Container(
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
            icon,
            size: 24,
            color: Color(0xFFE67E22),
          ),
          SizedBox(height: 8),
          Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D4037),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF8D6E63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis Experiencias Favoritas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return _buildFavoriteCard(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteCard(int index) {
    final favorites = [
      {'title': 'Barro Negro', 'rating': '4.8'},
      {'title': 'Mole Poblano', 'rating': '4.9'},
      {'title': 'Sarapes', 'rating': '4.7'},
    ];

    final favorite = favorites[index];
    
    return Container(
      width: 100,
      margin: EdgeInsets.only(right: 12),
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
        child: Column(
          children: [
            // Imagen
            Expanded(
              child: Container(
                width: double.infinity,
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
                    Icons.favorite,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Info
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(
                    favorite['title']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.amber,
                      ),
                      SizedBox(width: 2),
                      Text(
                        favorite['rating']!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOptions() {
    return Column(
      children: [
        _buildOptionItem(Icons.bookmark, 'Experiencias Guardadas', () {}),
        _buildOptionItem(Icons.history, 'Historial de Reservas', () {}),
        _buildOptionItem(Icons.payment, 'Métodos de Pago', () {}),
        _buildOptionItem(Icons.notifications, 'Notificaciones', () {}),
        _buildOptionItem(Icons.help, 'Ayuda y Soporte', () {}),
        _buildOptionItem(Icons.privacy_tip, 'Privacidad', () {}),
        _buildOptionItem(Icons.logout, 'Cerrar Sesión', () {}, isDestructive: true),
      ],
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : Color(0xFFE67E22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Color(0xFF5D4037),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Color(0xFF8D6E63),
        ),
        onTap: onTap,
      ),
    );
  }
}
