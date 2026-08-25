import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

// ─── Brand tokens ──────────────────────────────────────────────────────────────
const _kBrand       = Color(0xFFB0126B);
const _kBrandDeep   = Color(0xFF8A0D55);
const _kPlum        = Color(0xFF9C3A8B);
const _kBrandLight  = Color(0xFFFCE8F3);
const _kBrandMid    = Color(0xFFF3C4DF);
const _kBg          = Color(0xFFF7F3F6);
const _kCardBg      = Color(0xFFFFFFFF);
const _kTextPri     = Color(0xFF1A0A13);
const _kTextSec     = Color(0xFF7A5870);
const _kTextMuted   = Color(0xFFB89AAE);
const _kBorder      = Color(0x18B0126B);
const _kInputBg     = Color(0xFFFDF4F9);

// Action colours
const _kCall        = Color(0xFF4C6EF5);
const _kEmail       = Color(0xFFE53935);
const _kChat        = Color(0xFF20C997);
const _kWhatsApp    = Color(0xFF25D366);

class ProfileDetailPage extends StatefulWidget {
  final Map<String, dynamic>? memberData;
  const ProfileDetailPage({super.key, this.memberData});

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _memberData = {};
  bool _isLoading = false;
  List<String> _productsServices = [];

  final TextEditingController _leadAmountController = TextEditingController();
  late AnimationController _headerAnim;
  late Animation<double> _fadeAnim;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();

    if (widget.memberData != null) {
      _memberData = widget.memberData!;
      _parseProductsServices();
    }
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('bbc_user_id');
        _currentUserName = prefs.getString('bbc_user_name');
      });
    }
  }

  @override
  void dispose() {
    _leadAmountController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  void _parseProductsServices() {
    final raw = _memberData['person_service']?.toString() ??
        _memberData['product']?.toString() ??
        _memberData['product_services']?.toString() ??
        _memberData['services']?.toString() ??
        '';
    _productsServices = raw.isNotEmpty && raw != 'No services listed'
        ? raw.split(RegExp(r'[,\n;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get _name => _memberData['name'] ?? 'Unknown User';
  String get _company => _memberData['company'] ?? '';
  String get _occupation => _memberData['occupation'] ?? '';
  String get _mobile => _memberData['mobile']?.toString() ?? '';
  String get _email => _memberData['email']?.toString() ?? '';
  String get _address => _memberData['address']?.toString() ?? '';
  String get _imageUrl => _memberData['profile_image']?.toString() ?? '';
  String get _referredBy => _memberData['referred_by']?.toString() ?? _memberData['referred_by_code']?.toString() ?? '';

  // ─── Share Function with Image ────────────────────────────────────────────────

  Future<void> _shareProfile() async {
    // Build the share text message
    String shareMessage = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🌟 BUSINESS PROFILE 🌟
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📌 NAME: $_name

🏢 COMPANY: $_company

💼 OCCUPATION: $_occupation

📞 MOBILE: $_mobile
📧 EMAIL: $_email

🛠️ PRODUCTS/SERVICES:
${_productsServices.isNotEmpty ? _productsServices.map((s) => "   • $s").join('\n') : "   • Not specified"}

${_referredBy.isNotEmpty ? "🔗 REFERRED BY: $_referredBy\n" : ""}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🚀 Business Boosters Club
    Premium Business Network
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ''';
    
    // If there's a profile image, try to share it with the message
    if (_imageUrl.isNotEmpty) {
      try {
        // Download the image
        final response = await http.get(Uri.parse(_imageUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/profile_${_memberData['id']}.jpg');
          await file.writeAsBytes(response.bodyBytes);
          
          // Share with image
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/jpeg')],
            text: shareMessage,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error sharing image: $e');
      }
    }
    
    // Fallback: share only text
    await Share.share(shareMessage);
  }

  // ─── API Calls ─────────────────────────────────────────────────────────────────

  Future<void> _createLead() async {
    if (_leadAmountController.text.trim().isEmpty) {
      _showSnackBar('Please enter lead amount');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final prefs  = await SharedPreferences.getInstance();
      final token  = prefs.getString('bbc_token');
      final userId = prefs.getString('bbc_user_id');
      if (token == null || userId == null) {
        _showSnackBar('Please login again');
        setState(() => _isLoading = false);
        return;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://businessboosters.club/public/api/create-lead'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['lead_date']    = DateTime.now().toIso8601String().split('T')[0];
      request.fields['lead_from_id'] = userId;
      request.fields['lead_to_id']   = _memberData['id']?.toString() ?? '';
      request.fields['lead_amount']  = _leadAmountController.text.trim();

      final streamedResponse = await request.send();
      final responseBody     = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        _showSnackBar('Lead sent successfully!');
        if (mounted) Navigator.pop(context);
        _leadAmountController.clear();
      } else {
        try {
          final json = jsonDecode(responseBody);
          _showSnackBar(json['msg'] ?? 'Failed to send lead');
        } catch (_) {
          _showSnackBar('Lead sent successfully!');
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Launch Functions ─────────────────────────────────────────────────────────

  Future<void> _makePhoneCall() async {
    if (_mobile.isEmpty) {
      _showSnackBar('No phone number available');
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: _mobile);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('Could not launch phone dialer');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _sendEmail() async {
    if (_email.isEmpty) {
      _showSnackBar('No email address available');
      return;
    }
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=Business Opportunity from Business Boosters Club&body=Hello $_name,%0A%0AI came across your profile on Business Boosters Club.%0A%0ACompany: $_company%0AOccupation: $_occupation%0A%0AWould love to connect and explore business opportunities!%0A%0AThanks',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showSnackBar('Could not launch email app');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_mobile.isEmpty) {
      _showSnackBar('No phone number available');
      return;
    }
    // Clean mobile number
    String cleanMobile = _mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanMobile.startsWith('0')) cleanMobile = cleanMobile.substring(1);
    if (!cleanMobile.startsWith('91')) cleanMobile = '91$cleanMobile';
    
    final String message = 'Hello $_name,%0A%0A'
        'I came across your profile on Business Boosters Club.%0A'
        'Company: $_company%0A'
        'Occupation: $_occupation%0A%0A'
        'Would love to connect and explore business opportunities!';
    
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanMobile?text=$message');
    
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        _showSnackBar('WhatsApp is not installed');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  // ─── Snack bar ────────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white))),
        ]),
        backgroundColor: _kTextPri,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────────

  void _showLeadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LeadSheet(
          memberData: _memberData,
          leadAmountController: _leadAmountController,
          onSend: _createLead,
          isLoading: _isLoading,
        ),
      ),
    );
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: _kCardBg,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCall.withOpacity(0.1),
                ),
                child: Icon(Icons.phone_in_talk_rounded, color: _kCall, size: 30),
              ),
              const SizedBox(height: 18),
              Text('Call $_name?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kTextPri)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _kCall.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_mobile,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _kCall)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.dmSans(color: _kTextSec, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _makePhoneCall();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kCall,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Call Now',
                          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: _kCardBg,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kEmail.withOpacity(0.1),
                ),
                child: Icon(Icons.email_rounded, color: _kEmail, size: 30),
              ),
              const SizedBox(height: 18),
              Text('Email $_name?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kTextPri)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _kEmail.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_email,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _kEmail)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.dmSans(color: _kTextSec, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendEmail();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kEmail,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Send Email',
                          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatsAppDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: _kCardBg,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kWhatsApp.withOpacity(0.1),
                ),
                child: Icon(Icons.chat_bubble_rounded, color: _kWhatsApp, size: 30),
              ),
              const SizedBox(height: 18),
              Text('WhatsApp $_name?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _kTextPri)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _kWhatsApp.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_mobile,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _kWhatsApp)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.dmSans(color: _kTextSec, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendWhatsApp();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kWhatsApp,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('WhatsApp',
                          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wishes = _memberData['wishes']?.toString().toLowerCase() ?? '';
    final dob = _memberData['dob']?.toString();
    final doa = _memberData['doa']?.toString();
    final isBirthday = wishes.contains('birthday') || _isBirthdayToday(dob);
    final isAnniversary = wishes.contains('anniversary') || _isAnniversaryToday(doa);
    final hasCelebration = isBirthday || isAnniversary;
    final isCurrentUser = _currentUserId != null && _memberData['id']?.toString() == _currentUserId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        if (hasCelebration && !isCurrentUser) _buildCelebrationWishBox(isBirthday, isAnniversary),
                        if (_productsServices.isNotEmpty)
                          _buildSection(
                            label: 'Products & Services',
                            icon: Icons.inventory_2_outlined,
                            child: _buildServicesBody(),
                          ),
                        if (_company.isNotEmpty || _address.isNotEmpty || _referredBy.isNotEmpty)
                          _buildSection(
                            label: 'Company Details',
                            icon: Icons.business_center_rounded,
                            child: _buildCompanyBody(),
                          ),
                        const SizedBox(height: 24), // Reduced from 100 to 24 to remove extra spacing
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(),
              ],
            ),
            if (hasCelebration) const ConfettiWidget(),
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
          colors: [Color(0xFF7B1F6A), _kBrand, Color(0xFFC4156E)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _fog(200, 0.05)),
            Positioned(bottom: 0, left: -20, child: _fog(110, 0.04)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _headerCircleBtn(
                          Icons.arrow_back_rounded, () => Navigator.pop(context)),
                      const SizedBox(width: 40), // Empty space for alignment
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row with Name and Occupation on left, Avatar on right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_occupation.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _occupation,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Mobile Number
                            if (_mobile.isNotEmpty)
                              _contactInfoRow(
                                icon: Icons.phone_rounded,
                                value: _mobile,
                                onTap: _makePhoneCall,
                              ),
                            const SizedBox(height: 12),
                            // Email
                            if (_email.isNotEmpty)
                              _contactInfoRow(
                                icon: Icons.email_rounded,
                                value: _email,
                                onTap: _sendEmail,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Profile photo on the right side with 90x160 size
                      _buildLargeAvatar(),
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

  Widget _contactInfoRow({
    required IconData icon,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
       
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _fog(double size, double opacity) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(opacity)));

  Widget _buildLargeAvatar() {
  return Transform.translate(
    offset: const Offset(0, -20), // push up
    child: Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 220,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [_kBrandMid, _kBrand],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.all(Radius.circular(21)),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: _imageUrl.isNotEmpty
                  ? Image.network(
                      _imageUrl,
                      width: 120,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) =>
                          prog == null ? child : _textAvatar(100),
                      errorBuilder: (_, __, ___) =>
                          _textAvatar(100),
                    )
                  : _textAvatar(100),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E),
              border: Border.all(
                color: _kCardBg,
                width: 2.5,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
  
  Widget _textAvatar(double size) {
    return Container(
      width: size, 
      height: 160,
      color: _kBrandLight,
      child: Center(
        child: Text(
          _initials(_name),
          style: GoogleFonts.dmSans(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              color: _kBrand),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _kBrandLight),
                  child: Icon(icon, size: 16, color: _kBrand),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTextPri)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_company.isNotEmpty) ...[
          _detailRow(
            icon: Icons.business_center_outlined,
            label: 'Company Name',
            value: _company,
          ),
          if (_address.isNotEmpty || _referredBy.isNotEmpty) const SizedBox(height: 14),
        ],
        if (_address.isNotEmpty)
          _detailRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: _address,
          ),
        if (_referredBy.isNotEmpty && (_company.isNotEmpty || _address.isNotEmpty)) 
          const SizedBox(height: 14),
        if (_referredBy.isNotEmpty)
          _detailRow(
            icon: Icons.card_giftcard_outlined,
            label: 'Referred By',
            value: _referredBy,
          ),
      ],
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11), color: _kBrandLight),
          child: Icon(icon, size: 18, color: _kBrand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: _kTextMuted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3)),
              const SizedBox(height: 3),
              Text(value,
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kTextPri,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesBody() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _productsServices.asMap().entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _kBrandLight,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _kBrandMid, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kBrand),
                child: Center(
                  child: Text('${e.key + 1}',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 7),
              Text(e.value,
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _kBrandDeep,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
        boxShadow: [
          BoxShadow(
              color: _kBrand.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _iconActionBtn(
                icon: Icons.chat_bubble_outline_rounded,
                color: _kWhatsApp,
                label: 'WhatsApp',
                onTap: _showWhatsAppDialog,
              ),
            ),
            Expanded(
              child: _iconActionBtn(
                icon: Icons.email_outlined,
                color: _kEmail,
                label: 'Email',
                onTap: _showEmailDialog,
              ),
            ),
            Expanded(
              child: _iconActionBtn(
                icon: Icons.phone_outlined,
                color: _kCall,
                label: 'Call',
                onTap: _showCallDialog,
              ),
            ),
            Expanded(
              child: _iconActionBtn(
                icon: Icons.share_rounded,
                color: const Color(0xFFB0126B),
                label: 'Share',
                onTap: _shareProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconActionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.15),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Celebration Options & Helpers ───────────────────────────────────────────

  bool _isBirthdayToday(String? dob) {
    if (dob == null || dob.isEmpty) return false;
    try {
      final today = DateTime.now();
      final separator = dob.contains('-') ? '-' : (dob.contains('/') ? '/' : null);
      if (separator != null) {
        final parts = dob.split(separator);
        if (parts.length == 3) {
          int? day, month;
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            month = int.tryParse(parts[1]);
            day = int.tryParse(parts[2]);
          } else if (parts[2].length == 4) {
            // DD-MM-YYYY
            month = int.tryParse(parts[1]);
            day = int.tryParse(parts[0]);
          }
          if (month != null && day != null) {
            return today.month == month && today.day == day;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing birthday: $e');
    }
    return false;
  }

  bool _isAnniversaryToday(String? doa) {
    if (doa == null || doa.isEmpty) return false;
    try {
      final today = DateTime.now();
      final separator = doa.contains('-') ? '-' : (doa.contains('/') ? '/' : null);
      if (separator != null) {
        final parts = doa.split(separator);
        if (parts.length == 3) {
          int? day, month;
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            month = int.tryParse(parts[1]);
            day = int.tryParse(parts[2]);
          } else if (parts[2].length == 4) {
            // DD-MM-YYYY
            month = int.tryParse(parts[1]);
            day = int.tryParse(parts[0]);
          }
          if (month != null && day != null) {
            return today.month == month && today.day == day;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing anniversary: $e');
    }
    return false;
  }



  Widget _buildCelebrationWishBox(bool isBirthday, bool isAnniversary) {
    final colors = isBirthday
        ? [const Color(0xFFF96D34), const Color(0xFFE5A93C)]
        : [const Color(0xFFE91E63), const Color(0xFFC4156E)];
        
    final title = isBirthday && isAnniversary
        ? 'Double Celebration! 🎉'
        : (isBirthday ? 'Happy Birthday! 🎂' : 'Happy Anniversary! 💕');
        
    final subtitle = isBirthday && isAnniversary
        ? 'Celebrate both their Birthday & Wedding Anniversary today!'
        : (isBirthday ? 'Wish $_name a wonderful happy birthday!' : 'Wish $_name a beautiful wedding anniversary!');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors[0].withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            colors[0].withOpacity(0.04),
            colors[1].withOpacity(0.06),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors[0].withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBirthday ? Icons.cake_rounded : Icons.favorite_rounded,
                  color: colors[0],
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kTextPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _kTextSec,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (isBirthday)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => WishDialog(
                          member: _memberData,
                          isBirthday: true,
                          senderName: _currentUserName ?? 'Member',
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF96D34),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cake_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Wish Birthday',
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isBirthday && isAnniversary) const SizedBox(width: 10),
              if (isAnniversary)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => WishDialog(
                          member: _memberData,
                          isBirthday: false,
                          senderName: _currentUserName ?? 'Member',
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Wish Anniversary',
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Lead bottom sheet ────────────────────────────────────────────────────────

class _LeadSheet extends StatelessWidget {
  final Map<String, dynamic> memberData;
  final TextEditingController leadAmountController;
  final VoidCallback onSend;
  final bool isLoading;

  const _LeadSheet({
    required this.memberData,
    required this.leadAmountController,
    required this.onSend,
    required this.isLoading,
  });

  String get _name => memberData['name'] ?? 'Unknown';
  String get _company => memberData['company'] ?? '';
  String get _mobile => memberData['mobile']?.toString() ?? '';
  String get _imageUrl => memberData['profile_image']?.toString() ?? '';

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38, height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: _kBrandMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kBrandLight),
                child: const Icon(Icons.send_rounded, color: _kBrand, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Send Lead',
                      style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _kTextPri)),
                  Text('Business Boosters Club',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: _kTextMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBrandLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _kCardBg),
                  child: ClipOval(
                    child: _imageUrl.isNotEmpty
                        ? Image.network(_imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _miniTextAvatar())
                        : _miniTextAvatar(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sending to',
                          style: GoogleFonts.dmSans(
                              fontSize: 10, color: _kTextMuted)),
                      Text(_name,
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kBrandDeep)),
                      if (_mobile.isNotEmpty)
                        Text(_mobile,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: _kTextSec)),
                    ],
                  ),
                ),
                if (_company.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kBrand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_company.length > 14
                        ? '${_company.substring(0, 12)}…'
                        : _company,
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: _kBrand,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Lead Amount',
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kTextPri)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _kInputBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('₹',
                      style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kBrand)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: leadAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _kTextPri),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kTextMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    leadAmountController.clear();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.dmSans(
                          color: _kTextSec, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Send Lead',
                                style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTextAvatar() {
    return Container(
      color: _kBrandLight,
      child: Center(
        child: Text(_initials(_name),
            style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _kBrand)),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: _kBorder);
}

// Confetti Particle System for Full-Screen Celebrations
class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({super.key});

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        _updateParticles();
      });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        for (int i = 0; i < 85; i++) {
          _particles.add(_Particle(
            x: _random.nextDouble() * size.width,
            y: -20 - _random.nextDouble() * 120,
            vx: (_random.nextDouble() - 0.5) * 3.5,
            vy: 2 + _random.nextDouble() * 5.5,
            color: HSVColor.fromAHSV(
              1.0,
              _random.nextDouble() * 360,
              0.8,
              0.9,
            ).toColor(),
            size: 6 + _random.nextDouble() * 11,
            rotation: _random.nextDouble() * math.pi * 2,
            rotationSpeed: (_random.nextDouble() - 0.5) * 0.12,
          ));
        }
        _controller.repeat();
        
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            _controller.stop();
            setState(() {
              _particles.clear();
            });
          }
        });
      }
    });
  }

  void _updateParticles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      for (var p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.rotation += p.rotationSpeed;
        
        if (p.y > size.height && _controller.isAnimating) {
          p.y = -20;
          p.x = _random.nextDouble() * size.width;
          p.vy = 2 + _random.nextDouble() * 5.5;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(_particles),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WishDialog extends StatefulWidget {
  final Map<String, dynamic> member;
  final bool isBirthday;
  final String senderName;

  const WishDialog({
    super.key,
    required this.member,
    required this.isBirthday,
    required this.senderName,
  });

  @override
  State<WishDialog> createState() => _WishDialogState();
}

class _WishDialogState extends State<WishDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromptAndGenerateText();
  }

  Future<void> _fetchPromptAndGenerateText() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      final response = await http.get(
        Uri.parse('https://businessboosters.club/public/api/fetch-message-prompt'),
        headers: {'Authorization': 'Bearer $token'},
      );

      String wishText = '';
      bool useGemini = false;
      String promptTemplate = '';
      String apiKey = '';

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        final promptStatus = data['prompt_status']?.toString().toLowerCase() ?? 'no';
        apiKey = data['api_key'] ?? data['gemini_api_key'] ?? 'AIzaSyAeg_D1p3v1fgPn7EyGf40e49GkjVVo7L8';
        
        promptTemplate = widget.isBirthday
            ? (data['prompt_birthday']?.toString() ?? '')
            : (data['prompt_anniversary']?.toString() ?? '');

        if (promptStatus == 'yes') {
          useGemini = true;
        }
      }

      final recipientName = widget.member['name'] ?? 'Member';
      final senderName = widget.senderName;

      // Replace placeholders in the prompt template
      String processedPrompt = promptTemplate
          .replaceAll('[Recipient]', recipientName)
          .replaceAll('[Sender]', senderName)
          .replaceAll('Recipient', recipientName)
          .replaceAll('Sender', senderName);

      if (useGemini && processedPrompt.isNotEmpty && apiKey.isNotEmpty) {
        String queryText = processedPrompt + 
            "\n\nWrite a highly warm, personalized, unique wish from '$senderName' to '$recipientName'. "
            "Use natural formatting with paragraph breaks, include relevant emojis, and vary the wording so it is unique. "
            "Do not use markdown formatting, quotes, or asterisks (*).";

        final geminiResponse = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': queryText}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 1.0
            }
          }),
        );

        if (geminiResponse.statusCode == 200) {
          final geminiJson = jsonDecode(geminiResponse.body);
          final generatedText = geminiJson['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString();
          if (generatedText != null && generatedText.trim().isNotEmpty) {
            wishText = generatedText.trim();
          }
        } else {
          debugPrint('Gemini API failed with status ${geminiResponse.statusCode}: ${geminiResponse.body}. Falling back to prompt.');
        }
      }

      if (wishText.isEmpty) {
        wishText = processedPrompt;
      }

      if (wishText.isEmpty) {
        wishText = widget.isBirthday
            ? '🎂 Happy Birthday $recipientName! 🎉🥳\n\nWishing you a fantastic year ahead filled with success, happiness, and prosperity.\n\nWarm Regards,\n$senderName'
            : '💕 Happy Anniversary $recipientName! 💑\n\nWishing you both a lifetime of love, happiness, and togetherness.\n\nWarm Regards,\n$senderName';
      }

      if (mounted) {
        setState(() {
          _textCtrl.text = wishText;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating wish: $e');
      final recipientName = widget.member['name'] ?? 'Member';
      if (mounted) {
        setState(() {
          _textCtrl.text = widget.isBirthday
              ? 'Happy Birthday, $recipientName! 🎂'
              : 'Happy Anniversary, $recipientName! 💕';
          _loading = false;
        });
      }
    }
  }

  void _sendWish() async {
    final mobile = widget.member['whatsapp_number'] ?? widget.member['mobile'];
    if (mobile == null || mobile.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp number is not available')),
      );
      return;
    }
    
    String cleanMobile = mobile.toString().replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanMobile.startsWith('91') && cleanMobile.length == 10) {
      cleanMobile = '91$cleanMobile';
    }

    final message = Uri.encodeComponent(_textCtrl.text.trim());
    final url = 'https://wa.me/$cleanMobile?text=$message';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isBirthday
        ? [const Color(0xFFF96D34), const Color(0xFFE5A93C)]
        : [const Color(0xFFE91E63), const Color(0xFFC4156E)];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors[0].withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isBirthday ? Icons.cake_rounded : Icons.favorite_rounded,
                    color: colors[0],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isBirthday ? 'Happy Birthday!' : 'Happy Anniversary!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'To: ${widget.member['name']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: colors[0]),
                    const SizedBox(height: 14),
                    Text(
                      'Generating custom wish...',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _textCtrl,
                maxLines: 6,
                minLines: 4,
                style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors[0]),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sendWish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors[0],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Send Wish',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}