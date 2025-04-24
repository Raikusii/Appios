import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:My_car_tse/Swarp/LoginScreen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAhovKMm-WQnDfCBpXzNdmHti0E74kosSY", // Tu API key de google-services.json
        appId: "1:377588711811:android:542034c5644fe62e4f76b6", // Tu App ID de google-services.json
        messagingSenderId: "377588711811", // Tu project number de google-services.json
        projectId: "tseapp-c2759", // Tu project ID de google-services.json
        storageBucket: "tseapp-c2759.firebasestorage.app" // Tu storage bucket de google-services.json
      ),
    );
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSE',
      debugShowCheckedModeBanner: false, // Quitar banner de debug
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginScreen(),
    );
  }
}
