import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/cloudinary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RegisterTollScreen extends StatefulWidget {
  @override
  _RegisterTollScreenState createState() => _RegisterTollScreenState();
}

class _RegisterTollScreenState extends State<RegisterTollScreen> {
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController(); // Nuevo campo para la ubicación del peaje
  List<File> _images = [];
  DateTime _selectedDate = DateTime.now();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectImages() async {
    final pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _images = pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se seleccionaron imágenes.')),
      );
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se tomó ninguna foto.')),
      );
    }
  }

  Future<void> _registerToll() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, seleccione al menos una imagen')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    List<String> imageUrls = [];

    try {
      for (var image in _images) {
        String imageUrl = await _cloudinaryService.uploadImage(image);
        imageUrls.add(imageUrl);
      }

      if (imageUrls.length != _images.length) {
        throw Exception('No se pudieron subir todas las imágenes');
      }

      await FirebaseFirestore.instance.collection('sales').add({
        'type': 'Peaje', // Tipo fijo para peajes
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'location': _locationController.text, // Nueva campo para la ubicación
        'images': imageUrls,
        'status': 'no revisado',
        'timestamp': Timestamp.fromDate(_selectedDate),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      });

      Navigator.of(context).pop(); // Cierra el indicador de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Peaje registrado correctamente')),
      );

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pop();
      }

    } catch (e) {
      Navigator.of(context).pop(); // Cierra el indicador de carga
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar el peaje: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registrar Peaje')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Ubicación del Peaje',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Nota',
                prefixIcon: Icon(Icons.note),
              ),
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Precio',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Fecha',
                hintText: DateFormat('dd/MM/yyyy').format(_selectedDate),
                prefixIcon: Icon(Icons.calendar_today),
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _selectImages,
                  icon: Icon(Icons.photo_library),
                  label: Text('Seleccionar Imágenes'),
                ),
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: Icon(Icons.camera_alt),
                  label: Text('Tomar Foto'),
                ),
              ],
            ),
            if (_images.isNotEmpty) ...[
              SizedBox(height: 20),
              Wrap(
                spacing: 8.0,
                children: _images.map((image) {
                  return Stack(
                    children: [
                      Image.file(image, height: 100, width: 100, fit: BoxFit.cover),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _images.remove(image);
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _registerToll,
              icon: Icon(Icons.save),
              label: Text('Registrar Peaje'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
