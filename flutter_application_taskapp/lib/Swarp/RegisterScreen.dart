import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:My_car_tse/Swarp/LoginScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedRole; // Variable para almacenar el rol seleccionado
  bool _isBoss = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  void _checkAdminAccess() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email != 'rai@admin.com') {
      // Si no es el administrador, regresar a la pantalla anterior
      Future.microtask(() {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Acceso no autorizado')),
        );
      });
    }
  }

  Future<void> _register() async {
    try {
      // Crear el usuario en Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Guardar la información adicional en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text,
        'name': _nameController.text,
        'isBoss': _isBoss,
        'pinnedUserIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Navegar al HomeScreen después del registro exitoso
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registrar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Correo Electrónico'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              hint: Text('Selecciona un rol'),
              value: _selectedRole,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue;
                  _isBoss = newValue == 'jefe';
                });
              },
              items: <String>['jefe', 'trabajador']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
