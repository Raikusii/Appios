import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:My_car_tse/Swarp/LoginScreen.dart';
import 'package:My_car_tse/Swarp/RegisterScreen.dart';
import 'package:My_car_tse/Swarp/ExpensesReportScreen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()!;
  }

  Future<void> _changePassword(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay usuario autenticado')),
        );
        return;
      }

      final currentPasswordController = TextEditingController();
      final newPasswordController = TextEditingController();
      final confirmPasswordController = TextEditingController();

      final formKey = GlobalKey<FormState>();

      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Cambiar contraseña'),
            content: _PasswordChangeForm(
              formKey: formKey,
              currentPasswordController: currentPasswordController,
              newPasswordController: newPasswordController,
              confirmPasswordController: confirmPasswordController,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Cambiar'),
              ),
            ],
          );
        },
      );

      if (result == true) {
        if (newPasswordController.text != confirmPasswordController.text) {
          throw 'Las contraseñas no coinciden';
        }

        final credential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: currentPasswordController.text,
        );

        await currentUser.reauthenticateWithCredential(credential);
        await currentUser.updatePassword(newPasswordController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: const Text('¡Contraseña actualizada con éxito!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error desconocido';
      switch (e.code) {
        case 'wrong-password':
          message = 'Contraseña actual incorrecta';
          break;
        case 'weak-password':
          message = 'La nueva contraseña es muy débil';
          break;
        default:
          message = e.message ?? 'Error al cambiar la contraseña';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectUserToPin(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final List<String> currentPinnedUsers = 
          List<String>.from(currentUserDoc.data()?['pinnedUserIds'] ?? []);

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isNotEqualTo: currentUser.email)
          .get();

      final result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Fijar Usuario'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: usersSnapshot.docs.length,
                itemBuilder: (context, index) {
                  final userData = usersSnapshot.docs[index].data();
                  final userId = usersSnapshot.docs[index].id;
                  final bool isAlreadyPinned = currentPinnedUsers.contains(userId);

                  return ListTile(
                    leading: Icon(
                      isAlreadyPinned ? Icons.person_pin : Icons.person,
                      color: isAlreadyPinned ? Colors.green : null,
                    ),
                    title: Text(userData['name'] ?? 'Sin nombre'),
                    subtitle: Text(userData['email'] ?? 'Sin email'),
                    onTap: () => Navigator.pop(context, userId),
                    trailing: isAlreadyPinned 
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (result != null) {
        if (currentPinnedUsers.contains(result)) {
          // Si el usuario ya está fijado, lo removemos
          currentPinnedUsers.remove(result);
        } else {
          // Si no está fijado, lo agregamos
          currentPinnedUsers.add(result);
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'pinnedUserIds': currentPinnedUsers});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lista de usuarios fijados actualizada')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar usuarios fijados: $e')),
      );
    }
  }

  Future<void> _unpinAllUsers(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'pinnedUserIds': []});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se han desfijado todos los usuarios')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al desfijar usuarios: $e')),
      );
    }
  }

  bool _isAdmin(String email) {
    return email == 'rai@admin.com';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final userData = snapshot.data!;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildUserInfoCard(userData),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildAccountOptions(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic> userData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(userData['name'] ?? 'Nombre no disponible'),
              subtitle: const Text('Nombre completo'),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(userData['email'] ?? 'Correo no disponible'),
              subtitle: const Text('Correo electrónico'),
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: Text(userData['isBoss'] == true ? 'Jefe' : 'Trabajador'),
              subtitle: const Text('Rol en la aplicación'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountOptions(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = currentUser != null && _isAdmin(currentUser.email ?? '');

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return ListView();

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final isBoss = userData['isBoss'] ?? false;

        return ListView(
          children: [
            _buildSectionHeader('Opciones de cuenta'),
            _buildOptionTile(
              context: context,
              icon: Icons.settings,
              title: 'Configuración',
              onTap: () {}, // Agregar navegación luego
            ),
            _buildOptionTile(
              context: context,
              icon: Icons.history,
              title: 'Historial de actividades',
              onTap: () {},
            ),
            _buildSectionHeader('Seguridad'),
            _buildOptionTile(
              context: context,
              icon: Icons.lock,
              title: 'Cambiar contraseña',
              onTap: () => _changePassword(context),
            ),
            if (isAdmin || isBoss || true) ...[
              _buildSectionHeader('Reportes'),
              _buildOptionTile(
                context: context,
                icon: Icons.analytics,
                title: 'Reporte de Gastos',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ExpensesReportScreen()),
                  );
                },
              ),
            ],
            if (isAdmin) ...[
              _buildSectionHeader('Opciones de Administrador'),
              _buildOptionTile(
                context: context,
                icon: Icons.person_add,
                title: 'Registrar Nueva Cuenta',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
              ),
            ],
            _buildSectionHeader('Usuarios Fijados'),
            _buildPinnedUsersSection(context),
            _buildOptionTile(
              context: context,
              icon: Icons.logout,
              title: 'Cerrar sesión',
              color: Colors.red,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Estás seguro de que quieres salir?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Salir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al cerrar sesión: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).iconTheme.color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildPinnedUsersSection(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();

        final pinnedUserIds = List<String>.from(snapshot.data!.get('pinnedUserIds') ?? []);

        if (pinnedUserIds.isEmpty) {
          return _buildOptionTile(
            context: context,
            icon: Icons.person_add,
            title: 'Fijar usuarios',
            onTap: () => _selectUserToPin(context),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Usuarios Fijados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: pinnedUserIds.length,
              itemBuilder: (context, index) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(pinnedUserIds[index])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || userSnapshot.data == null) {
                      return ListTile(
                        leading: Icon(Icons.error),
                        title: Text('Error al cargar usuario'),
                        subtitle: Text('El usuario ya no existe o fue eliminado'),
                      );
                    }

                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    
                    if (userData == null) {
                      return ListTile(
                        leading: Icon(Icons.error),
                        title: Text('Usuario no disponible'),
                        subtitle: Text('No se encontraron datos del usuario'),
                      );
                    }

                    return ListTile(
                      leading: Icon(Icons.person_pin),
                      title: Text(userData['name'] ?? 'Usuario fijado'),
                      subtitle: Text(userData['email'] ?? ''),
                    );
                  },
                );
              },
            ),
            _buildOptionTile(
              context: context,
              icon: Icons.person_add,
              title: 'Fijar más usuarios',
              onTap: () => _selectUserToPin(context),
            ),
            _buildOptionTile(
              context: context,
              icon: Icons.person_remove,
              title: 'Desfijar todos los usuarios',
              onTap: () => _unpinAllUsers(context),
              color: Colors.red,
            ),
          ],
        );
      },
    );
  }
}

class _PasswordChangeForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;

  const _PasswordChangeForm({
    required this.formKey,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: Icon(Icons.lock),
              ),
              validator: (value) => value?.isEmpty ?? true 
                  ? 'Campo obligatorio' 
                  : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Campo obligatorio';
                if (value.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value != newPasswordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
} 