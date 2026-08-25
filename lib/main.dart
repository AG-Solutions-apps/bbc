import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:yaani/firebase_options.dart';
import 'package:yaani/Services/NotificationService.dart';
import 'Views/Screens/Bbc/Splash2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler (must be top-level function)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize FCM + local notifications, fetch & save token
  await NotificationService.initialize();

  // Print FCM token to console for easy testing
  final fcmToken = await NotificationService.getSavedToken();
  print('============================================================');
  print('🔑 FCM TOKEN: $fcmToken');
  print('============================================================');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Business Boosters Club',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen2(),
    );
  }
}
