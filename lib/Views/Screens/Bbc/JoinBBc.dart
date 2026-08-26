import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'BbcBottomNavBar.dart';
import 'dart:ui' show ImageFilter;

// ─── Brand tokens (identical across all BBC screens) ──────────────────────────
const _kBrand      = Color(0xFFB0126B);
const _kBrandDeep  = Color(0xFF8A0D55);
const _kPlum       = Color(0xFF9C3A8B);
const _kBrandLight = Color(0xFFFCE8F3);
const _kBg         = Color(0xFFFAF7F9);
const _kTextPri    = Color(0xFF1A0A13);
const _kTextSec    = Color(0xFF7A5870);
const _kTextMuted  = Color(0xFFB89AAE);
const _kBorder     = Color(0x1FB0126B);
const _kInputBg    = Color(0xFFFDF4F9);
const _kSuccess    = Color(0xFF10B981);
const _kWarning    = Color(0xFFF59E0B);

class JoinAsMemberPage extends StatefulWidget {
  const JoinAsMemberPage({super.key});

  @override
  State<JoinAsMemberPage> createState() => _JoinAsMemberPageState();
}

class _JoinAsMemberPageState extends State<JoinAsMemberPage> {
  // Controllers
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = false;
  bool _agreed = false;
  
  // User membership status
  bool _isCheckingMembership = true;
  bool _isApprovedMember = false;
  String _userReferralCode = '';
  String _userName = '';
  int _userType = 0;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkUserMembership();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _occupationController.dispose();
    _serviceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedProfileStr = prefs.getString('bbc_profile_cache');
      if (cachedProfileStr != null) {
        final data = jsonDecode(cachedProfileStr);
        setState(() {
          _userType = data['user_type']?.toInt() ?? 1;
          _isApprovedMember = _userType == 2;
          _userReferralCode = data['referral_code']?.toString() ?? '';
          _userName = data['name']?.toString() ?? data['person_name']?.toString() ?? 'Member';
          _userData = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile cache: $e');
    }
  }

  Future<void> _checkUserMembership() async {
    await _loadCache();

    setState(() {
      _isCheckingMembership = _userData == null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _isCheckingMembership = false;
          _isApprovedMember = false;
        });
        return;
      }

      // Fetch user profile to check membership status
      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/fetch-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Fetch Profile Response: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];
          
          setState(() {
            _userType = data['user_type']?.toInt() ?? 1;
            _isApprovedMember = _userType == 2;
            _userReferralCode = data['referral_code']?.toString() ?? '';
            _userName = data['name']?.toString() ?? data['person_name']?.toString() ?? 'Member';
            _userData = data;
          });

          await prefs.setString('bbc_profile_cache', jsonEncode(data));
          _showSnackBar('Fresh profile data loaded');
        } else {
          if (_userData != null) {
            _showSnackBar('Failed to refresh profile. Showing cached data.');
          }
        }
      } else {
        if (_userData != null) {
          _showSnackBar('Failed to refresh profile. Showing cached data.');
        }
      }
    } catch (e) {
      debugPrint('Error checking membership: $e');
      if (_userData != null) {
        _showSnackBar('Network error. Showing cached profile.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingMembership = false;
        });
      }
    }
  }

  Future<void> _submitJoinRequest() async {
    // Validation
    if (_companyController.text.trim().isEmpty) {
      _showSnackBar('Please enter your company name');
      return;
    }
    if (_occupationController.text.trim().isEmpty) {
      _showSnackBar('Please enter your occupation');
      return;
    }
    if (_serviceController.text.trim().isEmpty) {
      _showSnackBar('Please enter your products/services');
      return;
    }
    if (!_agreed) {
      _showSnackBar('Please agree to the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      if (token == null || token.isEmpty) {
        _showSnackBar('Please login first');
        setState(() => _isLoading = false);
        return;
      }

      // Create form data for join request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://businessboosters.club/public/api/create-join'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['person_company'] = _companyController.text.trim();
      request.fields['person_occupation'] = _occupationController.text.trim();
      request.fields['person_service'] = _serviceController.text.trim();
      request.fields['person_message'] = _messageController.text.trim().isEmpty 
          ? 'I want to join Business Boosters Club' 
          : _messageController.text.trim();

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      debugPrint('Join Response Status: ${streamedResponse.statusCode}');
      debugPrint('Join Response Body: $responseBody');

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        try {
          final json = jsonDecode(responseBody);
          if (json['code'] == 200) {
            _showSuccessDialog();
            // After successful submission, update user data
            await _refreshUserProfile(token);
          } else {
            _showSnackBar(json['msg'] ?? 'Join request submitted successfully!');
            _clearForm();
          }
        } catch (e) {
          _showSuccessDialog();
          _clearForm();
        }
      } else {
        _showSnackBar('Failed to submit request. Please try again.');
      }
    } catch (e) {
      debugPrint('Join error: $e');
      _showSnackBar('Network error: Please check your connection');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUserProfile(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/fetch-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];
          _userType = data['user_type']?.toInt() ?? 1;
          _isApprovedMember = _userType == 2;
          _userReferralCode = data['referral_code']?.toString() ?? '';
          _userName = data['name']?.toString() ?? data['person_name']?.toString() ?? 'Member';
          _userData = data;
          
          // Update local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bbc_user_data', jsonEncode(data));
          
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Refresh profile error: $e');
    }
  }

  void _clearForm() {
    _companyController.clear();
    _occupationController.clear();
    _serviceController.clear();
    _messageController.clear();
    setState(() => _agreed = false);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_kBrand, _kPlum],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                'Request Submitted!',
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kTextPri,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your membership request has been sent successfully.\nOur team will review and get back to you soon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: _kTextSec,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              color: const Color(0xFF2D3142).withOpacity(0.65),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _shareReferralCode() async {
    final String shareMessage = '''
Hello,

Our app includes over 120 businesses offering everything you need for your home & business.

Click the link to download: https://play.google.com/store/apps/details?id=com.bbc.agsolutions

Use my referral code to sign up: ${_userReferralCode.isNotEmpty ? _userReferralCode : 'Use the app directly'}

Thanks & Regards,
$_userName
    ''';
    
    try {
      await Share.share(shareMessage);
    } catch (e) {
      Clipboard.setData(ClipboardData(text: shareMessage));
      _showSnackBar('Referral message copied! Share it with your friends.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isCheckingMembership
                  ? const Center(
                      child: CircularProgressIndicator(color: _kBrand),
                    )
                  : _isApprovedMember
                      ? _buildApprovedMemberView()
                      : _buildScrollBody(),
            ),
            const BbcBottomNavBar(activeTab: BbcTab.member),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPlum, _kBrand, Color(0xFFC4156E)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -40,
              child: _circle(180, Colors.white.withOpacity(0.06))),
            Positioned(
              bottom: 8, left: 14,
              child: _circle(90, Colors.white.withOpacity(0.04))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                     
                    ],
                  ),
                 
                  Row(
                    children: [
                      
                   
                     
                    ],
                  ),
                 
                 
                 
                Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Expanded(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: _isApprovedMember
                  ? 'Welcome Back,\n'
                  : 'Become a\n',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            TextSpan(
              text: _isApprovedMember
                  ? 'Member'
                  : 'Premium Member',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: const Color(0xFFFFDCF0).withOpacity(0.95),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(width: 16),

    Transform.translate(
  offset: const Offset(0, -40), // move entire container up
  child: Container(
    width: 130,
    height: 130,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(0.92),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset(
        'assets/images/bbclogo.png',
        fit: BoxFit.contain,
        width: 120,
        height: 120,
        errorBuilder: (_, __, ___) => Icon(
          Icons.business_center_rounded,
          color: _kBrand,
          size: 80,
        ),
      ),
    ),
  ),
)
  ],
),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  // View for approved members (user_type == 2)
  Widget _buildApprovedMemberView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      transform: Matrix4.translationValues(0, -22, 0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kSuccess.withOpacity(0.1),
                ),
                child: Icon(Icons.verified_user_rounded, size: 44, color: _kSuccess),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Hello $_userName',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kTextPri,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _kSuccess.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: _kSuccess),
                    const SizedBox(width: 6),
                    Text(
                      'Approved Member',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kSuccess,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Our app includes over 120 businesses offering everything you need for your home & business.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _kTextSec,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Referral Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kBrandLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 22, color: _kBrand),
                      const SizedBox(width: 10),
                      Text(
                        'Your Referral Code',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kTextPri,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Referral Code Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBrand.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share this code',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _kTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _userReferralCode.isNotEmpty ? _userReferralCode : 'Not available',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _kBrand,
                                letterSpacing: 2,
                              ),
                            ),
                            if (_userReferralCode.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _userReferralCode));
                                  _showSnackBar('Referral code copied!');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_kBrand, _kPlum],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Copy',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Share this code with friends to invite them to the club',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Download App Info
          
          
            
            // Share Referral Button
            if (_userReferralCode.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareReferralCode,
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  label: Text(
                    'Invite Friends with Referral Code',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Go back button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Go to Home',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextSec,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollBody() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      transform: Matrix4.translationValues(0, -22, 0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepPills(),
            const SizedBox(height: 24),

            _sectionLabel('Business Details'),
            const SizedBox(height: 12),

            _buildField(
              ctrl: _companyController,
              hint: 'Company / Firm Name',
              icon: Icons.business_center_outlined,
              isRequired: true,
            ),
            const SizedBox(height: 12),

            _buildField(
              ctrl: _occupationController,
              hint: 'Occupation / Designation',
              icon: Icons.work_outline,
              isRequired: true,
            ),
            const SizedBox(height: 12),

            _buildField(
              ctrl: _serviceController,
              hint: 'Products / Services Offered',
              icon: Icons.inventory_2_outlined,
              isRequired: true,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            _buildField(
              ctrl: _messageController,
              hint: 'Additional Message (Optional)',
              icon: Icons.message_outlined,
              isOptional: true,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            _buildTermsRow(),

            const SizedBox(height: 24),

            _buildSubmitButton(),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBrandLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: _kBrand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your request will be reviewed by our team. Once approved, you\'ll get full access to the network.',
                      style: GoogleFonts.dmSans(fontSize: 12, color: _kTextSec, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: _kTextMuted),
                  const SizedBox(width: 5),
                  Text('Secured with 256-bit encryption',
                      style: GoogleFonts.dmSans(fontSize: 11, color: _kTextMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPills() {
    return Row(
      children: List.generate(3, (i) {
        final active = i < 1;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: active ? _kBrand : _kBorder,
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: _kTextMuted),
      );

  Widget _buildField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool readOnly = false,
    bool isOptional = false,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, size: 18, color: _kTextMuted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: inputType,
                  readOnly: readOnly,
                  inputFormatters: formatters,
                  maxLines: maxLines,
                  minLines: maxLines == 1 ? 1 : 2,
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: _kTextPri,
                      fontWeight: FontWeight.w400),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w300),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (isOptional)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBrandLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Optional',
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _kTextSec)),
                ),
              if (isRequired)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBrand,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Required',
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _agreed ? _kBrandLight.withOpacity(0.5) : _kInputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _agreed ? _kBrand.withOpacity(0.32) : _kBorder,
              width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _agreed ? _kBrand : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _agreed ? _kBrand : _kBrand.withOpacity(0.35),
                    width: 1.5),
              ),
              child: _agreed
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: _kTextSec, height: 1.5),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kBrand,
                          decoration: TextDecoration.underline,
                          decorationColor: _kBrand.withOpacity(0.35)),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kBrand,
                          decoration: TextDecoration.underline,
                          decorationColor: _kBrand.withOpacity(0.35)),
                    ),
                    const TextSpan(text: ' of Business Boosters Club.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _agreed
                ? [_kBrand, _kPlum]
                : [_kBrand.withOpacity(0.4), _kPlum.withOpacity(0.4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _agreed
              ? [
                  BoxShadow(
                    color: _kBrand.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: (_agreed && !_isLoading) ? _submitJoinRequest : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            padding: EdgeInsets.zero,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Submit Membership Request',
                        style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}