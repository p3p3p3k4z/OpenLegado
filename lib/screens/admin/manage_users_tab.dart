import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart'; // Ajusta la ruta a tu modelo AppUser

class ManageUsersTab extends StatefulWidget {
  const ManageUsersTab({super.key});

  @override
  State<ManageUsersTab> createState() => _ManageUsersTabState();
}

class _ManageUsersTabState extends State<ManageUsersTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _roles = ['user', 'creator', 'moderator', 'admin'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();


  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changeUserRole(String userId, String currentEmail, String newRole) async {
    // Confirmación para roles sensibles
    if (newRole == 'admin' || newRole == 'moderator') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmar Cambio de Rol Crítico'),
          content: Text('¿Estás seguro de que quieres asignar el rol "$newRole" al usuario $currentEmail?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirmar', style: TextStyle(color: Colors.orange.shade700)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({'role': newRole});
      _showSnackBar('Rol de $currentEmail actualizado a "$newRole".');
    } catch (e) {
      _showSnackBar('Error al actualizar rol: $e', isError: true);
    }
  }

  // Opcional: Función para "eliminar" o "deshabilitar" usuario
  Future<void> _disableUser(String userId, String currentEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Deshabilitación'),
        content: Text('¿Estás seguro de que quieres deshabilitar al usuario $currentEmail? Esta acción podría ser reversible o implicar eliminar sus datos según tu política.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deshabilitar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Implementación de deshabilitación:
      // Opción 1: Marcar como deshabilitado (necesitarás un campo 'isDisabled' en AppUser)
      // await _firestore.collection('users').doc(userId).update({'isDisabled': true, 'role': 'guest'});
      // Opción 2: Eliminar (¡CUIDADO! Esto es permanente y podría tener implicaciones con datos referenciados)
      // await _firestore.collection('users').doc(userId).delete();
      // Por ahora, solo un mensaje:
      _showSnackBar('Funcionalidad de deshabilitar/eliminar usuario "$currentEmail" no implementada completamente.', isError: true);
      print("Lógica para deshabilitar usuario $userId (${currentEmail}) aquí.");
    } catch (e) {
      _showSnackBar('Error al intentar deshabilitar usuario: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar usuarios por email o rol',
              hintText: 'Ej: "usuario@ejemplo.com" o "creator"',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay usuarios registrados.'));
              }

              List<AppUser> users = snapshot.data!.docs
                  .map((doc) => AppUser.fromFirestore(doc))
                  .toList();

              if (_searchQuery.isNotEmpty) {
                users = users.where((user) =>
                (user.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                    user.role.toLowerCase().contains(_searchQuery) ||
                    (user.username?.toLowerCase().contains(_searchQuery) ?? false)
                ).toList();
              }
              if (users.isEmpty) {
                return const Center(child: Text('Ningún usuario coincide con la búsqueda.'));
              }


              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColorLight,
                        child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                            ? ClipOval(child: Image.network(user.profileImageUrl!, fit: BoxFit.cover, width: 40, height: 40))
                            : Text(user.email?.substring(0, 1).toUpperCase() ?? 'U', style: TextStyle(color: Theme.of(context).primaryColorDark)),
                      ),
                      title: Text(user.email ?? user.username ?? 'Usuario sin email', style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('Rol actual: ${user.role}'),
                      trailing: SizedBox(
                        width: 130, // Ancho para el Dropdown
                        child: DropdownButtonFormField<String>(
                          value: user.role,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _roles.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (String? newRole) {
                            if (newRole != null && newRole != user.role) {
                              _changeUserRole(user.uid, user.email ?? user.uid, newRole);
                            }
                          },
                          // Opcional: añadir un botón de "eliminar" o "deshabilitar" usuario
                          // icon: IconButton(icon: Icon(Icons.more_vert), onPressed: () { /* Mostrar menú */}),
                        ),
                      ),
                      // onLongPress: () => _disableUser(user.uid, user.email ?? user.uid), // Opcional
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
