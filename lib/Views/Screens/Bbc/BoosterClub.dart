import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
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

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  Map<String, dynamic> _companyData = {};
  bool _isLoading = true;
  String? _errorMessage;
  
  // For storing different sections
  String _aboutText = '';
  String _missionText = '';
  String _visionText = '';
  String _historyText = '';
  List<String> _coreValues = [];
  Map<String, String> _contactInfo = {};

  @override
  void initState() {
    super.initState();
    _fetchCompanyAboutUs();
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

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('bbc_about_us_cache');
      if (cachedStr != null) {
        final data = jsonDecode(cachedStr);
        setState(() {
          _companyData = data;
          _parseCompanyData(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading about us cache: $e');
    }
  }

  Future<void> _fetchCompanyAboutUs() async {
    await _loadCache();

    // No need to show fullscreen loader if we have cache or default texts populated!
    setState(() {
      _isLoading = _companyData.isEmpty;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      // IMPORTANT: Always pass token for authenticated endpoints
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login to view company information';
          _isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/fetch-company-about-us'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('About Us Response Status: ${response.statusCode}');
      debugPrint('About Us Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];
          setState(() {
            _companyData = data;
            _parseCompanyData(data);
            _isLoading = false;
            _errorMessage = null;
          });

          await prefs.setString('bbc_about_us_cache', jsonEncode(data));
          _showSnackBar('Fresh company information loaded');
        } else {
          _showSnackBar(json['msg'] ?? 'Failed to refresh company information. Showing cached data.');
          setState(() {
            _errorMessage = null;
            _isLoading = false;
          });
        }
      } else {
        _showSnackBar('Failed to refresh company information. Showing cached data.');
        setState(() {
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('About Us error: $e');
      _showSnackBar('Network error. Showing cached company information.');
      setState(() {
        _errorMessage = null;
        _isLoading = false;
      });
    }
  }

  void _parseCompanyData(Map<String, dynamic> data) {
    // Parse about text
    _aboutText = data['about']?.toString() ?? 
                 data['company_description']?.toString() ?? 
                 data['description']?.toString() ?? 
                 'Business Boosters Club is a premium business networking platform connecting entrepreneurs, business owners, and professionals across India.';

    // Parse mission
    _missionText = data['mission']?.toString() ?? 
                   data['company_mission']?.toString() ?? 
                   'To empower businesses by creating meaningful connections, fostering collaboration, and driving growth through innovative networking solutions.';

    // Parse vision
    _visionText = data['vision']?.toString() ?? 
                  data['company_vision']?.toString() ?? 
                  'To become India\'s most trusted business networking ecosystem where every entrepreneur finds opportunities for growth and success.';

    // Parse history
    _historyText = data['history']?.toString() ?? 
                   data['company_history']?.toString() ?? 
                   'Founded in 2018, Business Boosters Club started with a vision to bridge the gap between businesses and opportunities.';

    // Parse core values
    final values = data['core_values'] ?? data['values'];
    if (values is List) {
      _coreValues = values.map((v) => v.toString()).toList();
    } else if (values is String) {
      _coreValues = values.split(RegExp(r'[,\n]')).map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
    } else {
      _coreValues = [
        'Integrity & Transparency',
        'Collaboration over Competition',
        'Innovation & Excellence',
        'Customer First Approach',
        'Continuous Learning'
      ];
    }

    // Parse contact info
    _contactInfo = {
      'email': data['contact_email']?.toString() ?? data['email']?.toString() ?? 'info@businessboosters.club',
      'phone': data['contact_phone']?.toString() ?? data['phone']?.toString() ?? '+91-XXXXXXXXXX',
      'address': data['address']?.toString() ?? 'Business Boosters Club, India',
    };
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kBrand))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              _buildAboutSection(),
                              const SizedBox(height: 10),
                              _buildMissionVisionSection(),
                              _buildDirectorsSection(),
                              _buildCoreValuesSection(),
                              _buildHistorySection(),
                              _buildContactSection(),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
            ),
            const BbcBottomNavBar(activeTab: BbcTab.about),
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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
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
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Expanded(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Know Who\n',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            TextSpan(
              text: 'We Are',
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

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _kTextMuted),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: GoogleFonts.dmSans(fontSize: 14, color: _kTextSec, )),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchCompanyAboutUs,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Retry', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Transform.translate(
      offset: const Offset(0, 10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _kBrand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'About Us',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kTextPri,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _aboutText,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: _kTextSec,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionVisionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kBrandLight, _kBrand.withOpacity(0.2)],
                      ),
                    ),
                    child: Icon(Icons.rocket_launch_rounded, color: _kBrand, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mission',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextPri,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _missionText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _kTextSec,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kBrandLight, _kBrand.withOpacity(0.2)],
                      ),
                    ),
                    child: Icon(Icons.visibility_rounded, color: _kBrand, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vision',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextPri,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _visionText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _kTextSec,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreValuesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _kBrand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Core Values',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPri,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _coreValues.map((value) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kBrandLight, _kBrand.withOpacity(0.15)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _kBrand.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: _kBrand),
                      const SizedBox(width: 8),
                      Text(
                        value,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kBrandDeep,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _kBrand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Our Journey',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPri,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _historyText,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _kTextSec,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBrandLight, _kBrand.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBrand.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _kBrand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Get in Touch',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPri,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _contactRow(Icons.email_outlined, _contactInfo['email'] ?? 'info@businessboosters.club'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
              onPressed: () async {
  final Uri url = Uri.parse(
    'https://businessboosters.club/contact',
  );

  await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
  );
},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kBrand, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Contact Support',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kBrand,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 18, color: _kBrand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: _kTextSec,
            ),
          ),
        ),
      ],
    );
  }
 Widget _buildDirectorsSection() {
  final directors = [
    {
      'image': 'assets/images/1.png',
      'name': 'BHUPENDRA KOTWAL',
    },
    {
      'image': 'assets/images/2.png',
      'name': 'NARENDAR GEHLOT',
    },
    {
      'image': 'assets/images/3.png',
      'name': 'UMESH \n TULSYAN',
    },
  ];

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          'Our Directors',
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kTextPri,
          ),
        ),
        const SizedBox(height: 20),

        // Row layout for directors
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: directors.map((director) {
            return Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage: AssetImage(director['image']!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    director['name']!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextPri,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}
}