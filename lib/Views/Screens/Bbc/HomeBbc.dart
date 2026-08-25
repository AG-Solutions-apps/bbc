import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:new_version_plus/new_version_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaani/Views/Screens/Bbc/BoosterClub.dart';
import 'package:yaani/Views/Screens/Bbc/JoinBBc.dart';
import 'package:yaani/Views/Screens/Bbc/PersonalInfoPage.dart';
import 'package:yaani/Views/Screens/Bbc/profilebbc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'BbcBottomNavBar.dart';

// ─── Brand tokens ──────────────────────────────────────────────────────────────
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

// Birthday & Anniversary theme colors
const _kBirthdayGold   = Color(0xFFFFD700);
const _kBirthdayOrange = Color(0xFFFF8C42);
const _kBirthdayPink   = Color(0xFFFF6B6B);
const _kAnniversaryPurple = Color(0xFF9B59B6);
const _kAnniversaryRose   = Color(0xFFE84393);

// Base URL for images
const String _imageBaseUrl =
    'http://businessboosters.club/public/images/user_images/';

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => message;
}

class HomePageBbc extends StatefulWidget {
  const HomePageBbc({super.key});

  @override
  State<HomePageBbc> createState() => _HomePageBbcState();
}

class _HomePageBbcState extends State<HomePageBbc> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _birthdayMembers = [];
  List<Map<String, dynamic>> _anniversaryMembers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _userId;
  String? _userName;
  bool _showUpdateBar = false;
  bool _isFetchingMembers = false;
  DateTime? _lastPressedAt;
  int _retryCooldownSeconds = 0;
  Timer? _cooldownTimer;
 
  // Lead creation dialog controllers
  final TextEditingController _leadAmountController = TextEditingController();
  String? _selectedMemberId;
  Map<String, dynamic>? _selectedMember;

  // Cache for member details
  final Map<String, Map<String, dynamic>> _memberDetailsCache = {};

  // Scroll controller
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  
  // Slider data
  List<Map<String, dynamic>> _sliderItems = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isCurrentUserBirthday = false;
  bool _isCurrentUserAnniversary = false;
  bool _showCelebrationGif = false;
  



Future<void> _checkForUpdate() async {
  final newVersion = NewVersionPlus(
    androidId: "com.bbc.agsolutions",
  );

  final status = await newVersion.getVersionStatus();

  if (status == null) return;

  if (status.canUpdate && mounted) {
    setState(() {
      _showUpdateBar = true;
    });
  }
}

  @override
  void initState() {
    super.initState();


    
    _getUserIdAndFetchMembers();
    _fetchSliders();



  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkForUpdate();
  });

    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _searchFocusNode.dispose();
    _leadAmountController.dispose();
    _scrollController.dispose();

    _searchController.dispose();
    super.dispose();
  }



  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _getUserIdAndFetchMembers() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('bbc_user_id');
    _userName = prefs.getString('bbc_user_name');
    await _fetchMembers();
  }

  // New method to clear all cache and refresh
  Future<void> _clearCacheAndRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Clear local memory cache
      _memberDetailsCache.clear();

      // Safe image cache clear
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (e) {
        debugPrint('Image cache clear error: $e');
      }

      // Safe network image cache clear
      try {
        await DefaultCacheManager().emptyCache();
      } catch (e) {
        debugPrint('Network cache clear error: $e');
      }

      // Safe temp directory delete
      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('Temp directory delete error: $e');
      }

      _showSnackBar('Cache cleared successfully');
    } catch (e) {
      debugPrint('Cache clear error: $e');
    } finally {
      // Always fetch data even if cache clearing fails
      await Future.wait([
        _fetchMembers(),
        _fetchSliders(),
      ]);

      if (mounted) {
        setState(() {
          _searchQuery = '';
          _isRefreshing = false;
        });
        _searchController.clear();
        _showSnackBar('Fresh data loaded');
      }
    }
  }

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

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedMembersStr = prefs.getString('bbc_members_cache');
      final cachedDetailsStr = prefs.getString('bbc_member_details_cache');

      if (cachedDetailsStr != null) {
        final Map<String, dynamic> decodedDetails = jsonDecode(cachedDetailsStr);
        decodedDetails.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _memberDetailsCache[key] = value;
          }
        });
        
        // Also populate birthday and anniversary members from the loaded cache
        _birthdayMembers.clear();
        _anniversaryMembers.clear();
      }

      if (cachedMembersStr != null) {
        final List<dynamic> decodedMembers = jsonDecode(cachedMembersStr);
        final List<Map<String, dynamic>> loadedMembers = List<Map<String, dynamic>>.from(
          decodedMembers.map((m) => Map<String, dynamic>.from(m)),
        );
        
        setState(() {
          _members = loadedMembers;
          _isLoading = false;
          
          // Recalculate birthday/anniversary members from cache details
          for (var member in _members) {
            final memberId = member['id'];
            final cached = _memberDetailsCache[memberId];
            final wishes = member['wishes']?.toString().toLowerCase() ?? '';
            final dob = cached?['dob']?.toString();
            final doa = cached?['doa']?.toString();
            
            final isBday = wishes.contains('birthday') || _isBirthdayToday(dob);
            final isAnni = wishes.contains('anniversary') || _isAnniversaryToday(doa);
            
            if (isBday && memberId != _userId) {
              _birthdayMembers.add(cached != null ? {...member, ...cached} : member);
            }
            if (isAnni && memberId != _userId) {
              _anniversaryMembers.add(cached != null ? {...member, ...cached} : member);
            }
          }
          _checkCurrentUserCelebration();
        });
      }
    } catch (e) {
      debugPrint('Error loading persistent cache: $e');
    }
  }

  Future<void> _fetchMembers() async {
    if (_isFetchingMembers) return;
    _isFetchingMembers = true;

    // Load from cache first if members list is empty
    if (_members.isEmpty) {
      await _loadCache();
    }

    if (_members.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }
    setState(() {
      _errorMessage = null;
      _birthdayMembers.clear();
      _anniversaryMembers.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        _isFetchingMembers = false;
        return;
      }

      List<Map<String, dynamic>> allMembers = [];
      bool isApiSuccess = false;
      String? errorMessage;

      try {
        final response = await http.post(
          Uri.parse('https://businessboosters.club/public/api/fetch-user'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final membersData = json['data'] ?? [];

          if (membersData is List) {
            isApiSuccess = true;
            final Set<String> seenIds = {};
            for (var member in membersData) {
              final memberId = member['id']?.toString() ?? '';
              final cached = _memberDetailsCache[memberId];

              if (seenIds.contains(memberId)) {
                // Merge wishes if duplicate user exists in API response
                final existingIndex = allMembers.indexWhere((m) => m['id'] == memberId);
                if (existingIndex != -1) {
                  final existingWishes = allMembers[existingIndex]['wishes']?.toString() ?? '';
                  final newWishes = member['wishes']?.toString() ?? '';
                  final Set<String> wishesSet = {};
                  if (existingWishes.isNotEmpty) wishesSet.addAll(existingWishes.split(',').map((w) => w.trim().toLowerCase()));
                  if (newWishes.isNotEmpty) wishesSet.addAll(newWishes.split(',').map((w) => w.trim().toLowerCase()));
                  allMembers[existingIndex]['wishes'] = wishesSet.join(', ');
                }
                continue;
              }
              seenIds.add(memberId);

              allMembers.add({
                'id': memberId,
                'name': member['name']?.toString() ?? 'Unknown User',
                'mobile': member['mobile']?.toString() ?? '',
                'whatsapp_number':
                    member['whatsapp_number']?.toString() ??
                        member['mobile']?.toString() ??
                        '',
                'email': member['email']?.toString() ?? '',
                'company': cached?['company'] ??
                    member['company']?.toString() ??
                    'Loading...',
                'occupation': cached?['occupation'] ??
                    member['occupation']?.toString() ??
                    'Loading...',
                'product_services': cached?['product_services'] ??
                    member['product']?.toString() ??
                    '',
                'profile_image': cached?['profile_image'] ?? '',
                'image_loaded': cached != null,
                'dob': cached?['dob'] ?? '',
                'doa': cached?['doa'] ?? '',
                'wishes': member['wishes']?.toString() ?? '',
                'address': cached?['address'] ?? '',
                'area': member['area']?.toString() ?? '',
                'company_short':
                    member['company_short']?.toString() ?? '',
                'profile_tag': member['profile_tag']?.toString() ?? '',
                'referral_code':
                    member['referral_code']?.toString() ?? '',
                'is_current_user':
                    memberId == _userId,
              });
            }
            debugPrint(
                'Found ${membersData.length} members from fetch-user API');
          } else {
            errorMessage = 'Invalid data format from server';
          }
        } else if (response.statusCode == 401) {
          errorMessage = 'Session expired. Please login again.';
        } else if (response.statusCode == 429) {
          errorMessage = 'Too many requests. Please try again in a few moments.';
        } else {
          errorMessage = 'Server error (${response.statusCode}). Please try again later.';
        }
      } on SocketException catch (e) {
        debugPrint('SocketException fetching members: $e');
        errorMessage = 'No internet connection. Please check your network and retry.';
      } on TimeoutException catch (e) {
        debugPrint('TimeoutException fetching members: $e');
        errorMessage = 'Connection timed out. Please try again.';
      } catch (e) {
        debugPrint('Error fetching members: $e');
        errorMessage = 'An unexpected error occurred: $e';
      }

      if (!isApiSuccess) {
        _startRetryCooldown();
        _isFetchingMembers = false;

        if (_members.isNotEmpty) {
          // If we already have members loaded from cache, just show a SnackBar and DO NOT show full-screen error view
          _showSnackBar(errorMessage != null ? '$errorMessage Showing cached data.' : 'Failed to refresh members. Showing cached data.');
          setState(() {
            _errorMessage = null;
            _isLoading = false;
            
            // Re-populate birthdays & anniversaries from the cached data we kept
            for (var member in _members) {
              final cached = _memberDetailsCache[member['id']];
              final wishes = member['wishes']?.toString().toLowerCase() ?? '';
              final dob = cached?['dob']?.toString();
              final doa = cached?['doa']?.toString();

              final isBday = wishes.contains('birthday') || _isBirthdayToday(dob);
              final isAnni = wishes.contains('anniversary') || _isAnniversaryToday(doa);

              if (isBday && member['id'] != _userId && !_birthdayMembers.any((m) => m['id'] == member['id'])) {
                _birthdayMembers.add(cached != null ? {...member, ...cached} : member);
              }
              if (isAnni && member['id'] != _userId && !_anniversaryMembers.any((m) => m['id'] == member['id'])) {
                _anniversaryMembers.add(cached != null ? {...member, ...cached} : member);
              }
            }
            _checkCurrentUserCelebration();
          });
        } else {
          // Show full-screen error if no cache exists
          setState(() {
            _errorMessage = errorMessage ?? 'Failed to load members';
            _isLoading = false;
          });
        }
        return;
      }

      if (allMembers.isEmpty) {
        setState(() {
          _members = [];
          _isLoading = false;
          _errorMessage = null; // Clear error to show standard empty view
          _birthdayMembers.clear();
          _anniversaryMembers.clear();
        });
        
        // Clear persistent cache since the list is empty now
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('bbc_members_cache');
        } catch (e) {
          debugPrint('Error clearing members cache: $e');
        }

        _isFetchingMembers = false;
        return;
      }

      setState(() {
        _members = allMembers;
        _isLoading = false;

        // Immediately re-populate birthday and anniversary lists from local cache details
        _birthdayMembers.clear();
        _anniversaryMembers.clear();
        for (var member in allMembers) {
          final cached = _memberDetailsCache[member['id']];
          final wishes = member['wishes']?.toString().toLowerCase() ?? '';
          final dob = cached?['dob']?.toString();
          final doa = cached?['doa']?.toString();

          final isBday = wishes.contains('birthday') || _isBirthdayToday(dob);
          final isAnni = wishes.contains('anniversary') || _isAnniversaryToday(doa);

          if (isBday && member['id'] != _userId) {
            _birthdayMembers.add(cached != null ? {...member, ...cached} : member);
          }
          if (isAnni && member['id'] != _userId) {
            _anniversaryMembers.add(cached != null ? {...member, ...cached} : member);
          }
        }
        _checkCurrentUserCelebration();
      });

      // Save to persistent cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bbc_members_cache', jsonEncode(allMembers));
      } catch (e) {
        debugPrint('Error saving members cache: $e');
      }

      _showSnackBar('Fresh data loaded from server');
      _loadMissingDetails(token);
    } catch (e) {
      debugPrint('Fetch members error: $e');
      
      _startRetryCooldown();
      if (_members.isNotEmpty) {
        _showSnackBar('Network error. Showing cached data.');
        setState(() {
          _errorMessage = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    } finally {
      _isFetchingMembers = false;
    }
  }

  void _startRetryCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _retryCooldownSeconds = 10;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_retryCooldownSeconds > 0) {
          _retryCooldownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _loadMissingDetails(String token) async {
    bool detailsUpdated = false;
    for (int i = 0; i < _members.length; i++) {
      final memberId = _members[i]['id'];

      if (_memberDetailsCache.containsKey(memberId)) continue;

      try {
        final details = await _fetchMemberDetails(memberId, token);
        if (details != null && mounted) {
          _memberDetailsCache[memberId] = details;
          detailsUpdated = true;

          setState(() {
            final index =
                _members.indexWhere((m) => m['id'] == memberId);
            if (index != -1) {
              _members[index]['company'] =
                  details['company'] ?? 'Business Professional';
              _members[index]['occupation'] =
                  details['occupation'] ?? 'Member';
              _members[index]['email'] = details['email'] ?? '';
              _members[index]['address'] = details['address'] ?? '';
              _members[index]['product_services'] =
                  details['product_services'] ?? '';
              _members[index]['profile_image'] =
                  details['profile_image'] ?? '';
              _members[index]['image_loaded'] = true;
              _members[index]['dob'] = details['dob'] ?? '';
              _members[index]['doa'] = details['doa'] ?? '';
            }

            if (index != -1) {
              final wishes = _members[index]['wishes']?.toString().toLowerCase() ?? '';
              final hasBirthday = wishes.contains('birthday') || _isBirthdayToday(details['dob']);
              final hasAnniversary = wishes.contains('anniversary') || _isAnniversaryToday(details['doa']);

              if (hasBirthday && memberId != _userId) {
                final memberData = {..._members[index], ...details};
                if (!_birthdayMembers.any((m) => m['id'] == memberId)) {
                  _birthdayMembers.add(memberData);
                }
              }

              if (hasAnniversary && memberId != _userId) {
                final memberData = {..._members[index], ...details};
                if (!_anniversaryMembers.any((m) => m['id'] == memberId)) {
                  _anniversaryMembers.add(memberData);
                }
              }
            }
            _checkCurrentUserCelebration();
          });
        }
      } on RateLimitException catch (e) {
        debugPrint('Rate limit hit in _loadMissingDetails: $e. Stopping detail fetches.');
        if (mounted) {
          _startRetryCooldown();
          _showSnackBar('Rate limit reached. Some member details could not be loaded.');
        }
        break; // Stop loop immediately
      } catch (e) {
        debugPrint('Error loading member $memberId: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (detailsUpdated) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bbc_member_details_cache', jsonEncode(_memberDetailsCache));
      } catch (e) {
        debugPrint('Error saving details cache: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchMemberDetails(
      String memberId, String token) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://businessboosters.club/public/api/fetch-user-by-id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': memberId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) {
        throw RateLimitException('Rate limit exceeded');
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];

          String profileImage = '';
          final imageFileName =
              data['profile_image']?.toString() ??
                  data['image']?.toString() ??
                  '';
          if (imageFileName.isNotEmpty &&
              imageFileName != 'no_images.png' &&
              imageFileName != 'null') {
            profileImage = '$_imageBaseUrl$imageFileName';
          }

          return {
            'id': data['id']?.toString() ?? memberId,
            'name': data['person_name']?.toString() ??
                data['name']?.toString() ??
                'Unknown',
            'mobile': data['person_mobile']?.toString() ??
                data['mobile']?.toString() ??
                '',
            'company': data['person_company']?.toString() ??
                data['company']?.toString() ??
                'Business Professional',
            'occupation': data['person_occupation']?.toString() ??
                data['occupation']?.toString() ??
                'Member',
            'email': data['person_email']?.toString() ??
                data['email']?.toString() ??
                '',
            'address': data['person_address']?.toString() ??
                data['address']?.toString() ??
                '',
            'product_services': data['person_service']?.toString() ??
                data['product']?.toString() ??
                data['product_services']?.toString() ??
                '',
            'profile_image': profileImage,
            'dob': data['person_dob']?.toString() ??
                data['dob']?.toString() ??
                '',
            'doa': data['person_doa']?.toString() ??
                data['anniversary']?.toString() ??
                '',
          };
        }
      }
    } on RateLimitException {
      rethrow;
    } catch (e) {
      debugPrint('Error fetching member details for $memberId: $e');
    }
    return null;
  }

  Future<void> _refreshMembers() async {
    setState(() => _isRefreshing = true);
    await _fetchMembers();
    setState(() => _isRefreshing = false);
  }

  Future<void> _createLead(String toUserId) async {
    if (_leadAmountController.text.trim().isEmpty) {
      _showSnackBar('Please enter lead amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');
      final userId = prefs.getString('bbc_user_id');

      if (token == null || userId == null) {
        _showSnackBar('Please login again');
        setState(() => _isLoading = false);
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://businessboosters.club/public/api/create-lead'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['lead_date'] =
          DateTime.now().toIso8601String().split('T')[0];
      request.fields['lead_from_id'] = userId;
      request.fields['lead_to_id'] = toUserId;
      request.fields['lead_amount'] =
          _leadAmountController.text.trim();

      final streamedResponse = await request.send();
      await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        _showSnackBar('Lead sent successfully!');
        if (mounted) Navigator.pop(context);
        _leadAmountController.clear();
        _selectedMember = null;
        _selectedMemberId = null;
      } else {
        _showSnackBar('Failed to send lead. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSliders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('bbc_token');

      final response = await http.post(
        Uri.parse(
            'https://businessboosters.club/public/api/fetch-slider'),
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('Slider Response Status: ${response.statusCode}');
      debugPrint('Slider Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? [];

        setState(() {
          _sliderItems = List<Map<String, dynamic>>.from(
            data.map((e) => {
              'imageUrl': 'https://businessboosters.club/public/images/slider_images/${e['slider_image']}',
              'link': e['slider_link']?.toString() ?? '',
              'heading': e['slider_heading']?.toString() ?? '',
              'buttonText': e['slider_button_text']?.toString() ?? '',
            }),
          );
        });
        
      }
    } catch (e) {
      debugPrint('Slider Error: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      _showSnackBar('No link available for this banner');
      return;
    }
    
    try {
      // Fix the URL if needed
      String finalUrl = url;
      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        finalUrl = 'https://$finalUrl';
      }
      
      final Uri uri = Uri.parse(finalUrl);
      
      // Use launchUrl with forceWebView for better compatibility
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        // Fallback: Try to launch with webview
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        } else {
          _showSnackBar('Cannot open link. Please check your connection.');
        }
      }
    } catch (e) {
      debugPrint('URL Launch Error: $e');
      _showSnackBar('Unable to open link: ${e.toString()}');
    }
  }

  void _showLeadDialog(Map<String, dynamic> member) {
    setState(() {
      _selectedMember = member;
      _selectedMemberId = member['id'];
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kBrand, _kPlum],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send Lead',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _kTextPri,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kBrandLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          const Icon(Icons.close, size: 18, color: _kBrand),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kBrandLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildSmallAvatar(member['name'],
                        member['profile_image'], member['image_loaded'] ?? false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTextPri,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member['company'],
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _kTextSec),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Lead Amount',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kTextSec,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder, width: 1.5),
                ),
                child: TextFormField(
                  controller: _leadAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style:
                      GoogleFonts.inter(fontSize: 16, color: _kTextPri),
                  decoration: InputDecoration(
                    hintText: 'Enter amount in INR',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14, color: _kTextMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    prefixIcon: const Icon(Icons.currency_rupee,
                        size: 20, color: _kBrand),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _leadAmountController.clear();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTextSec,
                        side: const BorderSide(color: _kBorder),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _createLead(member['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Send Lead',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
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

  Widget _buildSmallAvatar(
      String name, String? imageUrl, bool imageLoaded) {
    if (imageLoaded && imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildSmallTextAvatar(name),
        ),
      );
    }
    return _buildSmallTextAvatar(name);
  }

  Widget _buildSmallTextAvatar(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kPlum.withOpacity(0.8),
            _kBrand.withOpacity(0.8)
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
        backgroundColor: _kTextPri,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((member) {
      return member['name']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          member['company']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          member['product_services']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (member['mobile']
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isHeaderCollapsed = _scrollOffset > 80;

    // Dynamically construct a flat list of items to display in the main ScrollView.
    final List<Map<String, dynamic>> displayItems = [];

    if (_isCurrentUserBirthday || _isCurrentUserAnniversary) {
      displayItems.add({'type': 'wishing_message'});
    }

    if (_birthdayMembers.isNotEmpty) {
      displayItems.add({'type': 'birthday'});
    }
    if (_anniversaryMembers.isNotEmpty) {
      displayItems.add({'type': 'anniversary'});
    }

    final membersList = _filteredMembers;
    if (_sliderItems.isNotEmpty) {
      int memberCount = 0;
      for (int i = 0; i < membersList.length; i++) {
        displayItems.add({
          'type': 'member',
          'member': membersList[i],
          'index': i,
        });
        memberCount++;
        // Insert a banner after every 5 members, but only if it's not the very last element
        if (memberCount % 5 == 0 && i != membersList.length - 1) {
          displayItems.add({'type': 'banner'});
        }
      }
    } else {
      for (int i = 0; i < membersList.length; i++) {
        displayItems.add({
          'type': 'member',
          'member': membersList[i],
          'index': i,
        });
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final now = DateTime.now();
          final backButtonHasNotBeenPressedOrExpired =
              _lastPressedAt == null ||
                  now.difference(_lastPressedAt!) > const Duration(seconds: 2);

          if (backButtonHasNotBeenPressedOrExpired) {
            _lastPressedAt = now;
            _showSnackBar('Press back again to exit');
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: _kBg,
          body: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(isHeaderCollapsed),
                  _buildSearchBar(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _kBrand))
                        : _errorMessage != null
                            ? _buildErrorView()
                            : _filteredMembers.isEmpty
                                ? _buildEmptyView()
                                : RefreshIndicator(
                                    onRefresh: _refreshMembers,
                                    color: _kBrand,
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 80),
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: displayItems.length,
                                      itemBuilder: (context, index) {
                                        final item = displayItems[index];
                                        switch (item['type']) {
                                          case 'wishing_message':
                                            return _buildCurrentUserWishingCard();
                                          case 'birthday':
                                            return _buildBirthdaySection();
                                          case 'anniversary':
                                            return _buildAnniversarySection();
                                          case 'banner':
                                            return BbcBannerCarousel(
                                                sliderItems: _sliderItems);
                                          case 'member':
                                            return _buildMemberCard(
                                                item['member'], item['index']);
                                          default:
                                            return const SizedBox.shrink();
                                        }
                                      },
                                    ),
                                  ),
                  ),
                  const BbcBottomNavBar(activeTab: BbcTab.home),
                ],
              ),
              if (_showCelebrationGif) const ConfettiWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCollapsed) {
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, isCollapsed ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: isCollapsed ? 50 : 70,
                    height: isCollapsed ? 50 : 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/bbclogo.png',
                        width: isCollapsed ? 40 : 55,
                        height: isCollapsed ? 40 : 55,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.business_center_rounded,
                          color: _kBrand,
                          size: isCollapsed ? 30 : 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Boosters Club',
                          style: GoogleFonts.poppins(
                            fontSize: isCollapsed ? 14 : 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PREMIUM BUSINESS NETWORK',
                            style: GoogleFonts.inter(
                              fontSize: isCollapsed ? 8 : 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh Button
                  // Refresh Button
                  GestureDetector(
                    onTap: (_isRefreshing || _retryCooldownSeconds > 0)
                        ? null
                        : _clearCacheAndRefresh,
                    child: Container(
                      width: isCollapsed ? 40 : 45,
                      height: isCollapsed ? 40 : 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isRefreshing || _retryCooldownSeconds > 0)
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: (_isRefreshing || _retryCooldownSeconds > 0)
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : _retryCooldownSeconds > 0
                              ? Center(
                                  child: Text(
                                    '${_retryCooldownSeconds}s',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: isCollapsed ? 10 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: isCollapsed ? 20 : 24,
                                ),
                    ),
                  ),
                ],
              ),
              if (!isCollapsed) ...[
               
               
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) =>
                    setState(() => _searchQuery = value),
                style:
                    GoogleFonts.inter(fontSize: 14, color: _kTextPri),
                decoration: InputDecoration(
                  hintText:
                      'Search by name, company, products or mobile...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: _kTextMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 22, color: _kTextMuted),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: Icon(Icons.close_rounded,
                    size: 20, color: _kTextMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdaySection() {
    if (_birthdayMembers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kBirthdayOrange, _kBirthdayPink]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cake_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Birthday Celebrations 🎂',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kTextPri)),
                    Text('Wish our members on their special day',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kTextMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _birthdayMembers.length,
              itemBuilder: (context, index) =>
                  _buildBirthdayCard(_birthdayMembers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnniversarySection() {
    if (_anniversaryMembers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      _kAnniversaryPurple,
                      _kAnniversaryRose
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anniversary Celebrations 💕',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kTextPri)),
                    Text('Celebrating love and commitment',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kTextMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _anniversaryMembers.length,
              itemBuilder: (context, index) =>
                  _buildAnniversaryCard(_anniversaryMembers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayCard(Map<String, dynamic> member) =>
      _buildCelebrationCard(member, true);

  Widget _buildAnniversaryCard(Map<String, dynamic> member) =>
      _buildCelebrationCard(member, false);

  Widget _buildCelebrationCard(
      Map<String, dynamic> member, bool isBirthday) {
    final imageLoaded = member['image_loaded'] ?? false;
    final badgeColor = isBirthday ? const Color(0xFFF96D34) : const Color(0xFFE91E63);
    final tagBgColor = isBirthday ? const Color(0xFFFFB300).withOpacity(0.2) : const Color(0xFFE91E63).withOpacity(0.2);
    final tagTextColor = isBirthday ? const Color(0xFFFFD54F) : const Color(0xFFF48FB1);

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 32;

    return Container(
      width: cardWidth,
      height: 180,
      margin: const EdgeInsets.only(right: 16, bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: AssetImage(isBirthday
              ? 'assets/images/birthday_card_bg.png'
              : 'assets/images/anniversary_card_bg.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          // Left side: user profile and actions (fixed width to prevent layout overflow)
          Container(
            width: 145,
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar with Badge Stack
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: imageLoaded &&
                                member['profile_image'] != null &&
                                member['profile_image']
                                    .toString()
                                    .isNotEmpty
                            ? Image.network(
                                member['profile_image'],
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildCelebrationAvatarText(
                                        member['name'], isBirthday),
                              )
                            : _buildCelebrationAvatarText(
                                member['name'], isBirthday),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        isBirthday
                            ? Icons.cake_rounded
                            : Icons.people_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                // Name and Tag Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member['name'].length > 15
                          ? '${member['name'].substring(0, 12)}...'
                          : member['name'],
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member['occupation'] == 'Loading...'
                            ? 'Member'
                            : member['occupation'],
                        style: GoogleFonts.dmSans(
                            fontSize: 9,
                            color: tagTextColor,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // "Wish Now" Capsule Button
                GestureDetector(
                  onTap: () => isBirthday
                      ? _showBirthdayWishDialog(member)
                      : _showAnniversaryWishDialog(member),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                            Icons.celebration_rounded,
                            size: 13,
                            color: Color(0xFFE91E63)),
                        const SizedBox(width: 5),
                       TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 5),
  duration: const Duration(milliseconds: 700),
  curve: Curves.easeInOut,
  builder: (context, value, child) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Wish Now',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE91E63),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 3),
        Transform.translate(
          offset: Offset(value, 0),
          child: const Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: Color(0xFFE91E63),
          ),
        ),
      ],
    );
  },
)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Right side: Spacer for background illustration
          const Expanded(
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationAvatarText(String name, bool isBirthday) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBirthday
              ? [_kBirthdayGold, _kBirthdayOrange]
              : [_kAnniversaryPurple, _kAnniversaryRose],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),
    );
  }

  void _showBirthdayWishDialog(Map<String, dynamic> member) =>
      _showWishDialog(member, true);

  void _showAnniversaryWishDialog(Map<String, dynamic> member) =>
      _showWishDialog(member, false);

  void _showWishDialog(Map<String, dynamic> member, bool isBirthday) {
    showDialog(
      context: context,
      builder: (context) => WishDialog(
        member: member,
        isBirthday: isBirthday,
        senderName: _userName ?? 'Member',
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _kTextMuted),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: _kTextSec),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_retryCooldownSeconds > 0 || _isLoading)
                ? null
                : _fetchMembers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
                _retryCooldownSeconds > 0
                    ? 'Retry in ${_retryCooldownSeconds}s'
                    : 'Retry',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: _kTextMuted),
          const SizedBox(height: 16),
          Text('No members found',
              style:
                  GoogleFonts.inter(fontSize: 14, color: _kTextSec)),
          const SizedBox(height: 8),
          Text('Pull down to refresh',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _kTextMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMembers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Refresh',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
    final isLoading = member['company'] == 'Loading...';
    final imageLoaded = member['image_loaded'] ?? false;
    final isCurrentUser = member['id'] == _userId;
    final wishes =
        member['wishes']?.toString().toLowerCase() ?? '';
    final isAnniversaryWish = wishes.contains('anniversary');
    final isBirthdayWish = wishes.contains('birthday');

    final bool showBirthdayRibbon = isBirthdayWish;
    final bool showAnniversaryRibbon =
        !isBirthdayWish && isAnniversaryWish;

    return GestureDetector(
      onTap: () {
        _closeSearch();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileDetailPage(memberData: member),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 158,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: 90,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _kBrand.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: imageLoaded &&
                                  member['profile_image'] != null &&
                                  member['profile_image']
                                      .toString()
                                      .isNotEmpty
                              ? Image.network(
                                  member['profile_image'],
                                  width: 80,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, progress) =>
                                          progress == null
                                              ? child
                                              : Container(
                                                  decoration:
                                                      BoxDecoration(
                                                    gradient:
                                                        LinearGradient(
                                                      colors: [
                                                        _kPlum
                                                            .withOpacity(
                                                                0.8),
                                                        _kBrand
                                                            .withOpacity(
                                                                0.8),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                                14),
                                                  ),
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          _buildAvatarInitials(
                                              member['name']),
                                )
                              : _buildAvatarInitials(member['name']),
                        ),
                      ),
                    ),
                    if (showBirthdayRibbon)
                      Positioned(
                        bottom: 0,
                        left: -12,
                        right: -15,
                        child: Image.asset(
                          'assets/images/bd.png',
                          height: 60,
                          errorBuilder: (_, __, ___) =>
                              _buildFallbackRibbon(true),
                        ),
                      ),
                    if (showAnniversaryRibbon)
                      Positioned(
                        bottom: 0,
                        left: -12,
                        right: -15,
                        child: Image.asset(
                          'assets/images/anni.png',
                          height: 60,
                          errorBuilder: (_, __, ___) =>
                              _buildFallbackRibbon(false),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: _kTextPri,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kBrand,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    if (isBirthdayWish && isAnniversaryWish) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kBrandLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _kBrand.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.celebration_rounded,
                                size: 12, color: _kBrand),
                            const SizedBox(width: 4),
                            Text(
                              'Double Celebration! 🎂💕',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _kBrand),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.business_center_rounded,
                      isLoading ? 'Loading...' : member['company'],
                      isLoading ? _kTextMuted : _kBrand,
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.work_outline,
                      isLoading
                          ? 'Business Professional'
                          : member['occupation'],
                      _kTextSec,
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.inventory_2_outlined,
                      isLoading ||
                              member['product_services']
                                  .toString()
                                  .isEmpty
                          ? 'No services listed'
                          : (member['product_services']
                                          .toString()
                                          .length >
                                      40
                              ? '${member['product_services'].toString().substring(0, 40)}...'
                              : member['product_services']
                                  .toString()),
                      _kTextMuted,
                      maxLines: 2,
                      fontSize: 11,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        
                        GestureDetector(
                          onTap: () {
                            _closeSearch();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailPage(
                                    memberData: member),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kBrand, _kPlum]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _kBrand.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.visibility,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'View',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _infoRow(
    IconData icon,
    String text,
    Color textColor, {
    int maxLines = 1,
    double fontSize = 12,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _kBrandLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: _kBrand),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarInitials(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPlum, _kBrand],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackRibbon(bool isBirthday) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBirthday
              ? [_kBirthdayGold, _kBirthdayOrange]
              : [_kAnniversaryPurple, _kAnniversaryRose],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Center(
        child: Text(
          isBirthday ? '🎂 Birthday' : '💕 Anniversary',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }



  Widget _buildBannerCarousel() {
    return BbcBannerCarousel(sliderItems: _sliderItems);
  }

  void _checkCurrentUserCelebration() {
    bool bday = false;
    bool anni = false;
    
    for (var member in _members) {
      if (member['id'] == _userId) {
        final cached = _memberDetailsCache[_userId];
        final wishes = member['wishes']?.toString().toLowerCase() ?? '';
        final dob = cached?['dob']?.toString() ?? member['dob']?.toString();
        final doa = cached?['doa']?.toString() ?? member['doa']?.toString();

        bday = wishes.contains('birthday') || _isBirthdayToday(dob);
        anni = wishes.contains('anniversary') || _isAnniversaryToday(doa);
        break;
      }
    }
    
    if (bday || anni) {
      if (!_isCurrentUserBirthday && !_isCurrentUserAnniversary) {
        setState(() {
          _isCurrentUserBirthday = bday;
          _isCurrentUserAnniversary = anni;
          _showCelebrationGif = true;
        });
        // Hide celebration GIF overlay after 10 seconds
        Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _showCelebrationGif = false;
            });
          }
        });
      }
    }
  }

  Widget _buildCurrentUserWishingCard() {
    if (!_isCurrentUserBirthday && !_isCurrentUserAnniversary) return const SizedBox.shrink();
    
    final title = _isCurrentUserBirthday 
        ? 'Happy Birthday, ${_userName ?? "Member"}! 🎂'
        : 'Happy Anniversary, ${_userName ?? "Member"}! 💕';
        
    final message = _isCurrentUserBirthday
        ? 'We wish you a fantastic year ahead filled with success, good health, and happiness! Enjoy your special day! 🎉'
        : 'Wishing you another year of love, laughter, and happiness together. Happy Anniversary! 🥂';

    final gradient = _isCurrentUserBirthday
        ? const LinearGradient(colors: [_kBirthdayOrange, _kBirthdayPink])
        : const LinearGradient(colors: [_kAnniversaryPurple, _kAnniversaryRose]);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('🎉', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }
}

class BbcBannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> sliderItems;

  const BbcBannerCarousel({
    super.key,
    required this.sliderItems,
  });

  @override
  State<BbcBannerCarousel> createState() => _BbcBannerCarouselState();
}

class _BbcBannerCarouselState extends State<BbcBannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _stopAutoSlide();
    if (widget.sliderItems.isEmpty) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (widget.sliderItems.isNotEmpty && mounted && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % widget.sliderItems.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link available for this banner')),
      );
      return;
    }
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sliderItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: widget.sliderItems.length,
            itemBuilder: (context, index) {
              final sliderItem = widget.sliderItems[index];
              final imageUrl = sliderItem['imageUrl'] ?? '';
              final link = sliderItem['link'] ?? '';

              return GestureDetector(
                onTap: () => _launchUrl(link),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: _kBrand,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.sliderItems.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.sliderItems.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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