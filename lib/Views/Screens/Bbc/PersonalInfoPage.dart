import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yaani/Views/Screens/Bbc/LoginScreen.dart';
import 'package:yaani/Views/Screens/Bbc/activity.dart';
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
const _kWarning    = Color(0xFFF59E0B);
const _kSuccess    = Color(0xFF10B981);

class ProfilePageBBcc extends StatefulWidget {
  const ProfilePageBBcc({super.key});

  @override
  State<ProfilePageBBcc> createState() => _ProfilePageBBccState();
}

class _ProfilePageBBccState extends State<ProfilePageBBcc> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  
  // Animation controller for the animated button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _textFadeAnimation;
  
  // Membership status
  bool _isApprovedMember = false;
  String _membershipStatus = 'pending';
  
  // Editing controllers
  late TextEditingController _nameController;
  late TextEditingController _firmNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;
  late TextEditingController _anniversaryController;
  late TextEditingController _categoryController;
  late TextEditingController _productServicesController;
  late TextEditingController _addressController;
  late TextEditingController _dobDateController;
  late TextEditingController _anniversaryDateController;

  // Track original values for cancel operation
  Map<String, String> _originalValues = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchUserData();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _textFadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.repeat(reverse: true);
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _firmNameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _dobController = TextEditingController();
    _anniversaryController = TextEditingController();
    _categoryController = TextEditingController();
    _productServicesController = TextEditingController();
    _addressController = TextEditingController();
    _dobDateController = TextEditingController();
    _anniversaryDateController = TextEditingController();
  }

  String _formatDateToAPI(String dateString) {
    if (dateString.isEmpty) return '';
    
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
      return dateString;
    }
    
    if (dateString.contains('/')) {
      final parts = dateString.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2].length == 4 ? parts[2] : '20${parts[2]}';
        return '$year-$month-$day';
      }
    }
    
    try {
      DateTime? parsedDate;
      
      if (dateString.contains('-')) {
        parsedDate = DateTime.tryParse(dateString);
      }
      
      if (parsedDate == null && dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final year = parts[2].length == 4 ? parts[2] : '20${parts[2]}';
          parsedDate = DateTime.tryParse('$year-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
        }
      }
      
      if (parsedDate != null) {
        return "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
      }
    } catch (e) {
      debugPrint('Date parsing error: $e');
    }
    
    return dateString;
  }

  String _formatDateForDisplay(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dateString)) {
      return dateString;
    }
    
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
      final parts = dateString.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    
    try {
      DateTime? parsedDate;
      
      if (dateString.contains('-')) {
        parsedDate = DateTime.tryParse(dateString);
      }
      
      if (parsedDate == null && dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final year = parts[2].length == 4 ? parts[2] : '20${parts[2]}';
          parsedDate = DateTime.tryParse('$year-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
        }
      }
      
      if (parsedDate != null) {
        return "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}";
      }
    } catch (e) {
      debugPrint('Date display parsing error: $e');
    }
    
    return dateString;
  }

  Future<void> _selectDate(TextEditingController displayController, TextEditingController storageController) async {
    DateTime initialDate = DateTime.now();
    String storageValue = storageController.text.trim();
    
    if (storageValue.isNotEmpty) {
      try {
        if (storageValue.contains('-')) {
          final parts = storageValue.split('-');
          if (parts.length == 3) {
            initialDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        } else if (storageValue.contains('/')) {
          final parts = storageValue.split('/');
          if (parts.length == 3) {
            final year = parts[2].length == 4 ? parts[2] : '20${parts[2]}';
            initialDate = DateTime(
              int.parse(year),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        }
      } catch (e) {
        debugPrint('Error parsing initial date: $e');
        initialDate = DateTime.now();
      }
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kBrand,
              onPrimary: Colors.white,
              onSurface: _kTextPri,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final storageFormat = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      final displayFormat = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      
      storageController.text = storageFormat;
      displayController.text = displayFormat;
      
      debugPrint('Date selected - Storage: $storageFormat, Display: $displayFormat');
      setState(() {});
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');
      final savedUserData = prefs.getString('bbc_user_data');

      if (savedUserData != null) {
        final userData = jsonDecode(savedUserData) as Map<String, dynamic>;
        setState(() {
          _userData = userData;
          _checkMembershipStatus(userData);
          _updateControllers(userData);
          _saveOriginalValues();
          _isLoading = false;
        });
      }

      if (token != null && token.isNotEmpty) {
        await _fetchFreshUserData(token);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  void _checkMembershipStatus(Map<String, dynamic> userData) {
    final hasCompany = userData['company'] != null && userData['company'].toString().isNotEmpty;
    final hasOccupation = userData['occupation'] != null && userData['occupation'].toString().isNotEmpty;
    final hasProducts = userData['product_services'] != null && userData['product_services'].toString().isNotEmpty;
    final userType = userData['user_type']?.toString() ?? '';
    final status = userData['membership_status']?.toString() ?? '';
    
    _isApprovedMember = (hasCompany && hasOccupation && hasProducts) || userType == '2' || status == 'approved';
    _membershipStatus = status == 'approved' ? 'approved' : (hasCompany || hasOccupation ? 'approved' : 'pending');
  }

  void _saveOriginalValues() {
    _originalValues = {
      'name': _nameController.text,
      'firmName': _firmNameController.text,
      'mobile': _mobileController.text,
      'email': _emailController.text,
      'dob': _dobController.text,
      'dobDisplay': _dobDateController.text,
      'anniversary': _anniversaryController.text,
      'anniversaryDisplay': _anniversaryDateController.text,
      'category': _categoryController.text,
      'productServices': _productServicesController.text,
      'address': _addressController.text,
    };
  }

  void _restoreOriginalValues() {
    _nameController.text = _originalValues['name'] ?? '';
    _firmNameController.text = _originalValues['firmName'] ?? '';
    _mobileController.text = _originalValues['mobile'] ?? '';
    _emailController.text = _originalValues['email'] ?? '';
    _dobController.text = _originalValues['dob'] ?? '';
    _dobDateController.text = _originalValues['dobDisplay'] ?? '';
    _anniversaryController.text = _originalValues['anniversary'] ?? '';
    _anniversaryDateController.text = _originalValues['anniversaryDisplay'] ?? '';
    _categoryController.text = _originalValues['category'] ?? '';
    _productServicesController.text = _originalValues['productServices'] ?? '';
    _addressController.text = _originalValues['address'] ?? '';
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

  Future<void> _fetchFreshUserData(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/fetch-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];
          setState(() {
            _userData = data;
            _checkMembershipStatus(data);
            _updateControllers(data);
            _saveOriginalValues();
            _isLoading = false;
          });
          await _saveUserDataToPrefs(data);
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
      debugPrint('Error fetching fresh user data: $e');
      if (_userData != null) {
        _showSnackBar('Network error. Showing cached profile.');
      }
      setState(() => _isLoading = false);
    }
  }

  // --- UPDATED METHOD HERE ---
  void _updateControllers(Map<String, dynamic> userData) {
    // Check for 'dob' variants
    final rawDob = userData['person_dob']?.toString() ?? userData['dob']?.toString() ?? '';
    
    // Check for 'doa' variants (Added 'doa' key to match your JSON)
    final rawDoa = userData['person_doa']?.toString() ?? userData['doa']?.toString() ?? userData['anniversary']?.toString() ?? '';
    
    final formattedDobAPI = _formatDateToAPI(rawDob);
    final formattedDoaAPI = _formatDateToAPI(rawDoa);
    
    _dobController.text = formattedDobAPI;
    _anniversaryController.text = formattedDoaAPI;
    
    _dobDateController.text = _formatDateForDisplay(rawDob.isNotEmpty ? rawDob : formattedDobAPI);
    _anniversaryDateController.text = _formatDateForDisplay(rawDoa.isNotEmpty ? rawDoa : formattedDoaAPI);
    
    _nameController.text = userData['person_name']?.toString() ?? userData['name']?.toString() ?? '';
    _firmNameController.text = userData['person_company']?.toString() ?? userData['company']?.toString() ?? '';
    _mobileController.text = userData['person_mobile']?.toString() ?? userData['mobile']?.toString() ?? '';
    _emailController.text = userData['person_email']?.toString() ?? userData['email']?.toString() ?? '';
    
    // Check for occupation variants (Added 'occupation' key to match your JSON)
    _categoryController.text = userData['person_occupation']?.toString() ?? userData['occupation']?.toString() ?? userData['category']?.toString() ?? '';
    
    // Check for product variants (Added 'product' key to match your JSON)
    _productServicesController.text = userData['person_service']?.toString() ?? userData['product']?.toString() ?? userData['product_services']?.toString() ?? '';
    
    _addressController.text = userData['person_address']?.toString() ?? userData['address']?.toString() ?? '';
    
    debugPrint('Updated controllers - DOB storage: ${_dobController.text}, DOB display: ${_dobDateController.text}');
    debugPrint('Updated controllers - Anniversary storage: ${_anniversaryController.text}, Anniversary display: ${_anniversaryDateController.text}');
  }

  Future<void> _saveUserDataToPrefs(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bbc_user_data', jsonEncode(userData));
  }

  // --- UPDATED METHOD HERE ---
  Future<void> _updateUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      if (token == null || token.isEmpty) {
        _showSnackBar('Please login again');
        setState(() => _isLoading = false);
        return;
      }

      final formattedDob = _dobController.text.trim();
      final formattedDoa = _anniversaryController.text.trim();

      debugPrint('Submitting - DOB: $formattedDob, Anniversary: $formattedDoa');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://businessboosters.club/public/api/update-profile'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['person_name'] = _nameController.text.trim();
      request.fields['person_mobile'] = _mobileController.text.trim();
      request.fields['person_email'] = _emailController.text.trim();
      request.fields['person_company'] = _firmNameController.text.trim();
      request.fields['person_occupation'] = _categoryController.text.trim();
      request.fields['person_service'] = _productServicesController.text.trim();
      request.fields['person_address'] = _addressController.text.trim();
      request.fields['person_dob'] = formattedDob;
      request.fields['person_doa'] = formattedDoa;
      request.fields['person_area'] = '';
      request.fields['profile_tag'] = 'member';
      request.fields['referred_by_code'] = '';
      
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final json = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200 && json['code'] == 200) {
        // Ensure ALL possible API keys are updated in the local cache
        final updatedUserData = {
          ..._userData,
          'person_name': _nameController.text.trim(),
          'name': _nameController.text.trim(),
          'person_company': _firmNameController.text.trim(),
          'company': _firmNameController.text.trim(),
          'person_mobile': _mobileController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'person_email': _emailController.text.trim(),
          'email': _emailController.text.trim(),
          'person_dob': formattedDob,
          'dob': formattedDob,
          'person_doa': formattedDoa,
          'doa': formattedDoa, // Added
          'anniversary': formattedDoa,
          'person_occupation': _categoryController.text.trim(),
          'occupation': _categoryController.text.trim(), // Added
          'category': _categoryController.text.trim(),
          'person_service': _productServicesController.text.trim(),
          'product': _productServicesController.text.trim(), // Added
          'product_services': _productServicesController.text.trim(),
          'person_address': _addressController.text.trim(),
          'address': _addressController.text.trim(),
        };
        
        setState(() {
          _userData = updatedUserData;
          _checkMembershipStatus(updatedUserData);
          _updateControllers(updatedUserData);
          _saveOriginalValues();
          _isEditing = false;
          _isLoading = false;
        });
        
        await _saveUserDataToPrefs(updatedUserData);
        _showSnackBar(json['msg'] ?? 'Profile updated successfully!');
      } else {
        _showSnackBar(json['msg'] ?? 'Failed to update profile');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bbc_token');
    await prefs.remove('bbc_user_data');
    await prefs.remove('bbc_user_id');
    await prefs.remove('bbc_user_name');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,

      
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      if (token == null) {
        _showSnackBar('Please login again');
        return;
      }

      final response = await http.post(
        Uri.parse('https://businessboosters.club/public/api/delete-account'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await prefs.clear();
        if (!mounted) return;
        _showSnackBar(data['msg'] ?? 'Account deleted successfully');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        _showSnackBar(data['msg'] ?? 'Failed to delete account');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action is permanent and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToActivity() {
    HapticFeedback.lightImpact();
    _animationController.stop();
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityPage()),
    ).then((_) {
      if (mounted) {
        _animationController.repeat(reverse: true);
        // Refresh data when coming back to ensure latest data is shown
        _fetchUserData();
      }
    });
  }

  Widget _buildDatePickerRow(String label, TextEditingController displayController, TextEditingController storageController, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kInputBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _kTextMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _kTextSec,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _isEditing && _isApprovedMember
                    ? GestureDetector(
                        onTap: () => _selectDate(displayController, storageController),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _kInputBg,
                            border: Border.all(color: _kBorder, width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayController.text.isEmpty ? 'Select Date' : displayController.text,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: displayController.text.isEmpty ? _kTextMuted : _kTextPri,
                                ),
                              ),
                              Icon(Icons.calendar_today, size: 18, color: _kBrand),
                            ],
                          ),
                        ),
                      )
                    : Text(
                        displayController.text.isEmpty ? 'Not provided' : displayController.text,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: displayController.text.isEmpty ? _kTextMuted : _kTextPri,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, TextEditingController controller, IconData icon, {bool enabled = true, int maxLines = 1}) {
    if (!_isApprovedMember && label != 'Full Name' && label != 'Email' && label != 'Mobile Number') {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kInputBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _kTextMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _kTextSec,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _isEditing && enabled && _isApprovedMember
                    ? Container(
                        decoration: BoxDecoration(
                          color: _kInputBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorder, width: 1.5),
                        ),
                        child: TextFormField(
                          controller: controller,
                          maxLines: maxLines,
                          style: GoogleFonts.dmSans(fontSize: 14, color: _kTextPri),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      )
                    : Text(
                        controller.text.isEmpty ? 'Not provided' : controller.text,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: controller.text.isEmpty ? _kTextMuted : _kTextPri,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _firmNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _anniversaryController.dispose();
    _categoryController.dispose();
    _productServicesController.dispose();
    _addressController.dispose();
    _dobDateController.dispose();
    _anniversaryDateController.dispose();
    super.dispose();
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
            Expanded(child: _buildScrollBody()),
            const BbcBottomNavBar(activeTab: BbcTab.profile),
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
          colors: [_kPlum, _kBrand, Color.fromRGBO(196, 21, 110, 1)],
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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _userData['name']?.toString() ??
                              _userData['person_name']?.toString() ??
                              'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (_isApprovedMember && !_isEditing)
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return GestureDetector(
                              onTap: _navigateToActivity,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.scale(
                                      scale: _scaleAnimation.value,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color.fromRGBO(196, 21, 110, 1),
                                        ),
                                        child: const Icon(
                                          Icons.bolt_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CLICK HERE',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: const Color.fromRGBO(196, 21, 110, 1),
                                          ),
                                        ),
                                        FadeTransition(
                                          opacity: _textFadeAnimation,
                                          child: Text(
                                            'My Activity',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: const Color.fromRGBO(196, 21, 110, 1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isApprovedMember ? 'Personal Information' : 'Basic Information',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kTextPri,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your profile details',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (!_isEditing && _isApprovedMember)
                  InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => setState(() => _isEditing = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kBrand, _kPlum],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: _kBrand.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildEditableRow('Full Name', _nameController, Icons.person_outline_rounded),
            const SizedBox(height: 12),
            if (_isApprovedMember) ...[
              _buildEditableRow('Firm/Company', _firmNameController, Icons.business_outlined),
              const SizedBox(height: 12),
            ],
            _buildEditableRow('Mobile Number', _mobileController, Icons.phone_android_outlined, enabled: false),
            const SizedBox(height: 12),
            _buildEditableRow('Email', _emailController, Icons.mail_outline_rounded),
            if (_isApprovedMember) ...[
              const SizedBox(height: 12),
              _buildDatePickerRow('Date of Birth', _dobDateController, _dobController, Icons.cake_outlined),
              const SizedBox(height: 12),
              _buildDatePickerRow('Anniversary', _anniversaryDateController, _anniversaryController, Icons.favorite_border),
              const SizedBox(height: 12),
              _buildEditableRow('Category', _categoryController, Icons.category_outlined),
              const SizedBox(height: 12),
              _buildEditableRow('Products & Services', _productServicesController, Icons.inventory_2_outlined, maxLines: 3),
              const SizedBox(height: 12),
              _buildEditableRow('Address', _addressController, Icons.location_on_outlined, maxLines: 2),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 16),
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

  Widget _buildActionButtons() {
    if (!_isEditing) {
      return Column(
        children: [
          if (_isApprovedMember)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _navigateToActivity,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kBrand, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'My Activity',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _kBrand),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white),
              label: Text(
                'Logout',
                style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showDeleteAccountDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Text(
                'Delete Account',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _restoreOriginalValues();
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kTextSec, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextSec),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kBrand, _kPlum],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _kBrand.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: _updateUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}