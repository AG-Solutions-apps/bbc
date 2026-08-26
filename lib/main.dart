import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaani/firebase_options.dart';
import 'package:yaani/Services/NotificationService.dart';
import 'dart:ui' show ImageFilter;

import 'Views/Screens/Bbc/Splash2.dart';
import 'Views/Screens/Bbc/OnBoardingSlider.dart';
import 'Views/Screens/Bbc/BbcConfig.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Business Boosters Club',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      builder: (context, child) => GlobalSessionCheck(child: child),
      home: const SplashScreen2(),
    );
  }
}

class GlobalSessionCheck extends StatefulWidget {
  final Widget? child;
  const GlobalSessionCheck({super.key, this.child});

  @override
  State<GlobalSessionCheck> createState() => _GlobalSessionCheckState();
}

class _GlobalSessionCheckState extends State<GlobalSessionCheck> {
  Timer? _pollingTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Poll user account active status every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkUserStatus();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');
      if (token == null || token.isEmpty) {
        _isChecking = false;
        return; // User is not logged in, skip checks
      }

      final response = await http.post(
        Uri.parse('${BbcConfig.apiBaseUrl}/fetch-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];
          final status = data['status']?.toString().toLowerCase();
          final userStatus = data['user_status']?.toString().toLowerCase();

          // Check if status reports inactive or disabled (0)
          if (status == 'inactive' || status == '0' || userStatus == 'inactive' || userStatus == '0') {
            await _handleDeactivation();
          }
        }
      } else if (response.statusCode == 401) {
        // Unauthenticated session, perform auto-logout
        await _handleDeactivation();
      }
    } catch (e) {
      debugPrint('Error polling user session: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _handleDeactivation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bbc_token');
    await prefs.remove('bbc_user_id');
    await prefs.remove('bbc_user_name');
    await prefs.remove('bbc_user_mobile');
    await prefs.remove('bbc_user_data');
    await prefs.remove('bbc_members_cache');
    await prefs.remove('bbc_member_details_cache');

    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );

      final currentContext = navigatorKey.currentContext;
      if (currentContext != null) {
        ScaffoldMessenger.of(currentContext).clearSnackBars();
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  color: const Color(0xFF2D3142).withOpacity(0.65),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your account has been deactivated. Please contact admin.',
                          style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}
