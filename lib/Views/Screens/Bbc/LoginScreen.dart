// LoginScreen.dart - Updated with better UI/UX
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaani/Views/Screens/Bbc/Signup.dart';
import 'package:yaani/Services/NotificationService.dart';
import 'HomeBbc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('bbc_token');
    if (token != null && token.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePageBbc()));
      }
    }
  }

  // Custom OTP Dialog with better spacing
  void _showOtpDialog(String verificationId) {
    List<TextEditingController> otpControllers = List.generate(6, (_) => TextEditingController());
    List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9C3A8B), Color(0xFFB0126B), Color(0xFFC4156E)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smartphone,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verify OTP',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit code sent to',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      '+91 ${_phoneCtrl.text.trim()}',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // OTP Input Section
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    // OTP Boxes with proper spacing
                    Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: List.generate(
    6,
    (index) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        width: 40,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF4F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFB0126B).withOpacity(0.25),
            width: 1.2,
          ),
        ),
        child: TextFormField(
          controller: otpControllers[index],
          focusNode: focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A0A13),
          ),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    ),
  ),
),
                    
                    const SizedBox(height: 28),
                    
                    // Timer Row
                    StreamBuilder<int>(
                      stream: Stream.periodic(const Duration(seconds: 1), (i) => i).take(31),
                      initialData: 30,
                      builder: (context, snapshot) {
                        int seconds = 30 - (snapshot.data ?? 0);
                        if (seconds <= 0) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive the code? ",
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: const Color(0xFF7A5870),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _resendOtp();
                                },
                                child: Text(
                                  "Resend",
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFB0126B),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Text(
                          "Resend code in ${seconds}s",
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: const Color(0xFF7A5870),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          String otp = otpControllers.map((c) => c.text).join();
                          _verifyOtp(otp, verificationId, context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB0126B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'VERIFY',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Cancel Button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: const Color(0xFF7A5870),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resendOtp() async {
    final phone = _phoneCtrl.text.trim();
    setState(() => _loading = true);
    
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _loading = false);
          _snack('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _loading = false;
            _verificationId = verificationId;
          });
          _showOtpDialog(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _loading = false);
        },
      );
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error: $e');
    }
  }

  Future<void> _verifyOtp(String otp, String verificationId, BuildContext dialogContext) async {
    if (otp.length != 6) {
      _snack('Please enter 6-digit OTP');
      return;
    }

    setState(() => _loading = true);
    Navigator.pop(dialogContext);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        await _checkUserInBackend(_phoneCtrl.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      _snack(_getFirebaseErrorMessage(e.code));
      setState(() => _loading = false);
    } catch (e) {
      _snack('Verification failed: ${e.toString()}');
      setState(() => _loading = false);
    }
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again.';
      case 'session-expired':
        return 'Session expired. Please request a new OTP.';
      default:
        return 'Verification failed. Please try again.';
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }
    if (!_agreed) {
      _snack('Please agree to the terms and conditions');
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          if (userCredential.user != null) {
            await _checkUserInBackend(phone);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _loading = false);
          _snack('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _loading = false);
          _verificationId = verificationId;
          _showOtpDialog(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _loading = false);
        },
      );
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error: $e');
    }
  }

  Future<void> _checkUserInBackend(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/check-mobile'),
        body: {'mobile': phone},
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && json['code'] == 200) {
        await _loginToBackend(phone);
      } else if (json['code'] == 401) {
        _snack('Mobile number not registered. Please create an account.');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SignUpPage(mobile: phone),
            ),
          );
        }
      } else {
        _snack(json['msg'] ?? 'Something went wrong');
        setState(() => _loading = false);
      }
    } catch (e) {
      _snack('Network error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loginToBackend(String mobile) async {
    try {
      // Use the FCM token as the device identifier sent to the backend
      final fcmToken = await NotificationService.getSavedToken();

      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/login'),
        body: {
          'mobile': mobile,
          'astrologer_id': fcmToken,
        },
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && json['code'] == 200) {
        final data = json['data'] as Map<String, dynamic>;
        final token = data['token']?.toString() ?? '';
        final user = data['user'] as Map<String, dynamic>? ?? {};

        final status = user['status']?.toString().toLowerCase();
        final userStatus = user['user_status']?.toString().toLowerCase();
        if (status == 'inactive' || status == '0' || userStatus == 'inactive' || userStatus == '0') {
          _snack('Your account is inactive. Please contact admin.');
          setState(() => _loading = false);
          return;
        }

        await _saveSession(token: token, user: user);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePageBbc()),
            (_) => false,
          );
        }
      } else {
        _snack(json['msg'] ?? 'Login failed');
        setState(() => _loading = false);
      }
    } catch (e) {
      _snack('Network error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bbc_token', token);
    await prefs.setString('bbc_user_id', user['id']?.toString() ?? '');
    await prefs.setString('bbc_user_name', user['name']?.toString() ?? '');
    await prefs.setString('bbc_user_mobile', user['mobile']?.toString() ?? '');
    await prefs.setString('bbc_user_data', jsonEncode(user));
    // Store FCM token instead of Firebase Auth UID
    final fcmToken = await NotificationService.getSavedToken();
    await prefs.setString('firebase_uid', fcmToken);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFF1A0A13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F9),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF9C3A8B), Color(0xFFB0126B), Color(0xFFC4156E)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Centered Logo Section
                    _buildCenteredLogo(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MOBILE NUMBER',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                  color: const Color(0xFFB89AAE),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildPhoneField(),
                              const SizedBox(height: 8),
                              Text(
                                "We'll send a 6-digit OTP to verify your number",
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFFB89AAE),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildTermsRow(),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _sendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB0126B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Text(
                                          'Send OTP',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSecurityNote(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredLogo() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
           
            child: Center(
              child: Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/bbclogo.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business_center_rounded,
                      color: Color(0xFFB0126B),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Business Boosters Club',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'PREMIUM NETWORK',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0x1FB0126B),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFB0126B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '+91',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB0126B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 22, color: const Color(0x1FB0126B)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: const Color(0xFF1A0A13),
              ),
              decoration: const InputDecoration(
                hintText: '00000 00000',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          if (_phoneCtrl.text.length == 10)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB0126B),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTermsRow() {
    return Row(
      children: [
        Checkbox(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          activeColor: const Color(0xFFB0126B),
          checkColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          side: BorderSide(
            color: const Color(0xFFB0126B).withOpacity(0.35),
            width: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            'I agree to the Terms & Conditions and Privacy Policy',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: const Color(0xFF7A5870),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 13, color: const Color(0xFFB89AAE)),
        const SizedBox(width: 5),
        Text(
          'Secured with 256-bit encryption',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: const Color(0xFFB89AAE),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }
}