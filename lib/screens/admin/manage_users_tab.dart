import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart'; // Ajusta la ruta a tu modelo AppUser
// Importa la pantalla/dialogo de edición si lo creas por separado
// import 'edit_user_dialog.dart';

class ManageUsersTab extends StatefulWidget {
  // Si esta tab forma parte de un panel de admin que ya verifica el rol,
  // podríamos no necesitar pasar currentUserRole y currentUserId aquí.
  // Pero si es independiente o queremos lógica específica, es útil.
  // final String currentUserRole;
  // final String currentUserId;

  const ManageUsersTab({
    super.key,
    // required this.currentUserRole,
    // required this.currentUserId,
  });

  @override
  State<ManageUsersTab> createState() => _ManageUsersTabState();
}

enum UserAction { edit, toggleDisable, changeRole }

class _ManageUsersTabState extends State<ManageUsersTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _roles = ['user', 'creator', 'moderator', 'admin'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'all'; // 'all', 'user', 'creator', etc.
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'disabled'


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateUserField(String userId, String field, dynamic value, String userIdentifier) async {
    try {
      await _firestore.collection('users').doc(userId).update({field: value});
      _showSnackBar('Usuario $userIdentifier: campo "$field" actualizado.');
    } catch (e) {
      _showSnackBar('Error al actualizar $field para $userIdentifier: $e', isError: true);
    }
  }


  Future<void> _changeUserRole(AppUser user, String newRole) async {
    if (user.role == newRole) return;

    if (newRole == 'admin' || user.role == 'admin' || newRole == 'moderator') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmar Cambio de Rol Crítico'),
          content: Text('¿Estás seguro de que quieres cambiar el rol de "${user.email ?? user.username}" de "${user.role}" a "$newRole"?'),
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
    _updateUserField(user.uid, 'role', newRole, user.email ?? user.username ?? user.uid);
  }

  Future<void> _toggleUserDisabledStatus(AppUser user) async {
    final newDisabledStatus = !user.isDisabled;
    final actionText = newDisabledStatus ? "deshabilitar" : "habilitar";

    // Prevenir que un admin se deshabilite a sí mismo si es el único (lógica más compleja no implementada aquí)
    // if (user.uid == widget.currentUserId && newDisabledStatus && user.role == 'admin') {
    //   _showSnackBar('No puedes deshabilitarte a ti mismo como administrador.', isError: true);
    //   return;
    // }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar ${actionText.replaceFirst(actionText[0], actionText[0].toUpperCase())} Usuario'),
        content: Text('¿Estás seguro de que quieres $actionText al usuario "${user.email ?? user.username}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionText.replaceFirst(actionText[0], actionText[0].toUpperCase()), style: TextStyle(color: newDisabledStatus ? Colors.red : Colors.green)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    _updateUserField(user.uid, 'isDisabled', newDisabledStatus, user.email ?? user.username ?? user.uid);
  }

  Future<void> _editUserDialog(AppUser user) async {
    final TextEditingController usernameController = TextEditingController(text: user.username);
    final TextEditingController emailController = TextEditingController(text: user.email);
    // Añade más controladores para otros campos si es necesario

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar Usuario: ${user.email ?? user.username}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Nombre de usuario'),
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  // Podrías añadir validación o hacer este campo de solo lectura si
                  // el cambio de email tiene implicaciones con Firebase Auth.
                ),
                // Aquí podrías añadir campos para profileImageUrl, interests, etc.
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Guardar Cambios'),
              onPressed: () {
                // Validación básica
                if (usernameController.text.isEmpty) {
                  // _showSnackBar('El nombre de usuario no puede estar vacío.', isError: true); // No funciona bien dentro del dialog
                  print("El nombre de usuario no puede estar vacío");
                  return;
                }
                Navigator.of(context).pop({
                  'username': usernameController.text,
                  'email': emailController.text,
                  // ... otros campos
                });
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      Map<String, dynamic> updates = {};
      if (result['username'] != user.username) {
        updates['username'] = result['username'];
      }
      if (result['email'] != user.email) {
        // CUIDADO: Cambiar el email aquí solo afecta Firestore.
        // Si el email es usado para login con Firebase Auth, necesitarías
        // llamar a user.updateEmail() de Firebase Auth y manejar la reautenticación.
        // Por simplicidad, aquí solo actualizamos Firestore.
        updates['email'] = result['email'];
        print("ADVERTENCIA: El email se ha modificado solo en Firestore. La autenticación de Firebase puede no reflejar este cambio sin pasos adicionales.");
      }

      if (updates.isNotEmpty) {
        try {
          await _firestore.collection('users').doc(user.uid).update(updates);
          _showSnackBar('Usuario "${user.email ?? user.username}" actualizado.');
        } catch (e) {
          _showSnackBar('Error al actualizar usuario: $e', isError: true);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar por email, nombre de usuario o rol',
                  hintText: 'Ej: "admin" o "juanperez"',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedRoleFilter,
                      decoration: InputDecoration(
                        labelText: 'Filtrar por Rol',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      isDense: true,
                      items: ['all', ..._roles].map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role == 'all' ? 'Todos los Roles' : role, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedRoleFilter = value!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatusFilter,
                      decoration: InputDecoration(
                        labelText: 'Filtrar por Estado',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todos', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'active', child: Text('Activos', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'disabled', child: Text('Deshabilitados', style: TextStyle(fontSize: 14))),
                      ],
                      onChanged: (value) => setState(() => _selectedStatusFilter = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('users').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error al cargar usuarios: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay usuarios para mostrar.'));
              }

              List<AppUser> users = snapshot.data!.docs
                  .map((doc) => AppUser.fromFirestore(doc))
                  .toList();

              // Aplicar filtros
              if (_selectedRoleFilter != 'all') {
                users = users.where((user) => user.role == _selectedRoleFilter).toList();
              }
              if (_selectedStatusFilter != 'all') {
                users = users.where((user) => (_selectedStatusFilter == 'active' && !user.isDisabled) || (_selectedStatusFilter == 'disabled' && user.isDisabled)).toList();
              }

              // Aplicar búsqueda
              if (_searchQuery.isNotEmpty) {
                users = users.where((user) {
                  final emailMatch = user.email?.toLowerCase().contains(_searchQuery) ?? false;
                  final usernameMatch = user.username?.toLowerCase().contains(_searchQuery) ?? false;
                  final roleMatch = user.role.toLowerCase().contains(_searchQuery);
                  return emailMatch || usernameMatch || roleMatch;
                }).toList();
              }

              if (users.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Ningún usuario coincide con los filtros y la búsqueda actual.', textAlign: TextAlign.center),
                ));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final userIdentifier = user.email ?? user.username ?? user.uid;
                  final initials = (user.username?.isNotEmpty == true ? user.username![0] : (user.email?.isNotEmpty == true ? user.email![0] : 'U')).toUpperCase();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: user.isDisabled ? Colors.grey.shade300 : theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 12.0), // Ajustar padding para PopupMenuButton
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: user.isDisabled ? Colors.grey.shade500 : theme.primaryColorLight,
                            backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                                ? NetworkImage(user.profileImageUrl!)
                                : null,
                            child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                                ? Text(initials, style: TextStyle(color: user.isDisabled ? Colors.white70 : theme.primaryColorDark, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username ?? (user.email ?? 'Usuario desconocido'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    decoration: user.isDisabled ? TextDecoration.lineThrough : null,
                                    color: user.isDisabled ? Colors.black54 : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if(user.username != null && user.email != null)
                                  Text(user.email!, style: TextStyle(fontSize: 13, color: user.isDisabled ? Colors.black45 : theme.textTheme.bodySmall?.color)),
                                Text('Rol: ${user.role}', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: user.isDisabled ? Colors.black45 : theme.textTheme.bodySmall?.color)),
                                if (user.isDisabled)
                                  const Text('(Deshabilitado)', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Dropdown para cambiar rol y Menú para otras acciones
                          SizedBox(
                            width: 120, // Ajustar ancho si es necesario
                            child: DropdownButtonFormField<String>(
                              initialValue: user.role,
                              isDense: true,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                fillColor: user.isDisabled ? Colors.grey.shade400 : null,
                                filled: user.isDisabled,
                              ),
                              items: _roles.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: user.isDisabled ? null : (String? newRole) { // Deshabilitar si el usuario está deshabilitado
                                if (newRole != null && newRole != user.role) {
                                  _changeUserRole(user, newRole);
                                }
                              },
                            ),
                          ),
                          PopupMenuButton<UserAction>(
                            icon: Icon(Icons.more_vert, color: user.isDisabled ? Colors.black45 : null),
                            onSelected: (UserAction action) {
                              switch (action) {
                                case UserAction.edit:
                                  _editUserDialog(user);
                                  break;
                                case UserAction.toggleDisable:
                                  _toggleUserDisabledStatus(user);
                                  break;
                                case UserAction.changeRole:
                                // El Dropdown ya maneja esto. Se podría quitar de aquí
                                // o abrir un dialogo específico si se prefiere.
                                  break;
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<UserAction>>[
                              const PopupMenuItem<UserAction>(
                                value: UserAction.edit,
                                child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar Usuario')),
                              ),
                              PopupMenuItem<UserAction>(
                                value: UserAction.toggleDisable,
                                child: ListTile(
                                  leading: Icon(user.isDisabled ? Icons.check_circle_outline : Icons.block_outlined, color: user.isDisabled ? Colors.green : Colors.red),
                                  title: Text(user.isDisabled ? 'Habilitar Usuario' : 'Deshabilitar Usuario'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
