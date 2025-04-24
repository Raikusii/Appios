import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import '../constants/cloudinary_constants.dart';

class CloudinaryService {
  final cloudinary = CloudinaryPublic(
    CloudinaryConstants.cloudName, 
    CloudinaryConstants.uploadPreset,
    cache: false,
  );

  Future<String> uploadImage(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Error al subir la imagen: $e');
    }
  }
} 