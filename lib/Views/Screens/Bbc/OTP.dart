// OTP.dart - Updated with Firebase OTP verification
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaani/Views/Screens/Bbc/HomeBbc.dart';
import 'package:yaani/Services/NotificationService.dart';
import 'Signup.dart';

class OtpScreen2 extends StatefulWidget {
  final String mobile;
  final String verificationId; // Firebase verification ID

  const OtpScreen2({
    super.key,
    required this.mobile,
    required this.verificationId,
  });

  @override
  State<OtpScreen2> createState() => _OtpScreen2State();
}

class _OtpScreen2State extends State<OtpScreen2> {
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers = List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  
  bool _isLoading = false;
  int _resendSeconds = 30;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _resendSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  // Firebase OTP Verification
  Future<void> _verifyOtp() async {
    if (_otp.length < _otpLength) {
      setState(() => _errorMessage = "Please enter the complete OTP");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create credential from SMS code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otp,
      );

      // Sign in with credential
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Check if user exists in your backend
        await _checkUserInBackend(user.phoneNumber ?? widget.mobile);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Verification failed: ${e.toString()}";
        _isLoading = false;
      });
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

  Future<void> _checkUserInBackend(String mobile) async {
    try {
      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/check-mobile'),
        body: {'mobile': mobile.replaceAll('+91', '')},
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && json['code'] == 200) {
        // User exists - login
        await _loginToBackend(mobile.replaceAll('+91', ''));
      } else if (json['code'] == 401) {
        // User doesn't exist - go to signup
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SignUpPage(mobile: mobile.replaceAll('+91', '')),
            ),
          );
        }
      } else {
        _showSnack(json['msg'] ?? 'Something went wrong');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnack('Network error: $e');
      setState(() => _isLoading = false);
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
          'firebase_uid': fcmToken,
        },
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && json['code'] == 200) {
        final data = json['data'] as Map<String, dynamic>;
        final token = data['token']?.toString() ?? '';
        final user = data['user'] as Map<String, dynamic>? ?? {};

        await _saveSession(token: token, user: user);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePageBbc()),
            (_) => false,
          );
        }
      } else {
        _showSnack(json['msg'] ?? 'Login failed');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnack('Network error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${widget.mobile}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = _getFirebaseErrorMessage(e.code);
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _startTimer();
            _showSnack('OTP resent successfully!');
            for (var c in _controllers) c.clear();
            _focusNodes[0].requestFocus();
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to resend OTP";
        _isLoading = false;
      });
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
    await prefs.setString('bbc_user_data', jsonEncode(user));
    // Store FCM token instead of Firebase Auth UID
    final fcmToken = await NotificationService.getSavedToken();
    await prefs.setString('firebase_uid', fcmToken);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB0126B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9C3A8B),
      body: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 45),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(120),
                bottomRight: Radius.circular(120),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 35),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: "OTP ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                        TextSpan(text: "Verification", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFB0126B))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Enter the code sent to +91${widget.mobile}",
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Edit Number",
                          style: TextStyle(color: Color(0xFFB0126B), fontSize: 13, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_otpLength, (i) => _buildOtpBox(i)),
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Center(
                    child: _resendSeconds > 0
                        ? Text(
                            "Didn't receive the OTP? Resend in ${_resendSeconds}s",
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Didn't receive the OTP? ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                              GestureDetector(
                                onTap: _resendOtp,
                                child: const Text(
                                  "Resend",
                                  style: TextStyle(color: Color(0xFFB0126B), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Spacer(),
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB0126B),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("VERIFY", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 45),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 46,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFB0126B), width: 2)),
      ),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty && index < _otpLength - 1) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }
}