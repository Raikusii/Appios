import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryConfig {
  static final cloudinary = CloudinaryPublic(
    'dx3v8fsot',  // Reemplaza con tu cloud name de Cloudinary
    'tu-upload-preset', // Reemplaza con tu upload preset
    cache: false,
  );
} 