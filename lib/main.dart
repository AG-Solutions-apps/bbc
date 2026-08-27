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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _showUpdateNotification = false;
  String? _storeVersion;
  String? _updateUrl;

  @override
  void initState() {
    super.initState();
    // Poll user account active status every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkUserStatus();
    });
    // Check for updates globally on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdate();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  bool _isVersionOlder(String local, String latest) {
    try {
      final localParts = local.split('+')[0].split('.').map(int.parse).toList();
      final latestParts = latest.split('+')[0].split('.').map(int.parse).toList();
      
      for (int i = 0; i < latestParts.length; i++) {
        final localPart = i < localParts.length ? localParts[i] : 0;
        final latestPart = latestParts[i];
        if (localPart < latestPart) return true;
        if (localPart > latestPart) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }

  Future<void> _checkAppUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;
      
      if (_isVersionOlder(localVersion, BbcConfig.latestAppVersion)) {
        setState(() {
          _storeVersion = BbcConfig.latestAppVersion;
          _updateUrl = BbcConfig.playStoreUrl;
          _showUpdateNotification = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
    }
  }

  Future<void> _redirectToPlayStore() async {
    if (_updateUrl != null && _updateUrl!.isNotEmpty) {
      final uri = Uri.parse(_updateUrl!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Could not launch Play Store: $e');
      }
    }
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

  Widget _buildGlobalUpdateOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.6),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Header Icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB0126B), Color(0xFFE91E63)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB0126B).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'Time to Update!',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A0A13),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A new version (${_storeVersion ?? "latest"}) is available. Update now to enjoy the latest features and optimizations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.45,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 18),
                  // What's new box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB0126B).withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "WHAT'S NEW",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB0126B),
                            letterSpacing: 1.2,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...BbcConfig.updateFeatures.map((feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Icon(Icons.circle, size: 6, color: Color(0xFFB0126B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7A5870),
                                        height: 1.3,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      // Later Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showUpdateNotification = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[750],
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Update Button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB0126B), Color(0xFFE91E63)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB0126B).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _redirectToPlayStore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Update Now',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        if (_showUpdateNotification) _buildGlobalUpdateOverlay(),
      ],
    );
  }
}
