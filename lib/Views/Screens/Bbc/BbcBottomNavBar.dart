import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'HomeBbc.dart';
import 'JoinBBc.dart';
import 'BoosterClub.dart';
import 'PersonalInfoPage.dart';

enum BbcTab { home, member, about, profile }

class BbcBottomNavBar extends StatelessWidget {
  final BbcTab activeTab;

  const BbcBottomNavBar({
    super.key,
    required this.activeTab,
  });

  void _navigateToTab(BuildContext context, BbcTab tab) {
    if (activeTab == tab) return;

    PageRouteBuilder _buildPageRoute(Widget page) {
      return PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    switch (tab) {
      case BbcTab.home:
        // Pop back to root (Home)
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case BbcTab.member:
        if (activeTab == BbcTab.home) {
          Navigator.push(
            context,
            _buildPageRoute(const JoinAsMemberPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            _buildPageRoute(const JoinAsMemberPage()),
          );
        }
        break;
      case BbcTab.about:
        if (activeTab == BbcTab.home) {
          Navigator.push(
            context,
            _buildPageRoute(const AboutUsPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            _buildPageRoute(const AboutUsPage()),
          );
        }
        break;
      case BbcTab.profile:
        if (activeTab == BbcTab.home) {
          Navigator.push(
            context,
            _buildPageRoute(const ProfilePageBBcc()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            _buildPageRoute(const ProfilePageBBcc()),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFFB0126B);
    const Color mutedColor = Color(0xFFB89AAE);

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Home Tab
          GestureDetector(
            onTap: () => _navigateToTab(context, BbcTab.home),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home_filled,
                    color: activeTab == BbcTab.home ? brandColor : mutedColor,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Home',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: activeTab == BbcTab.home ? brandColor : mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Member Tab
          GestureDetector(
            onTap: () => _navigateToTab(context, BbcTab.member),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: activeTab == BbcTab.member ? 1.0 : 0.5,
                    child: Image.asset(
                      'assets/images/bbclogo.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Member',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: activeTab == BbcTab.member ? brandColor : mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // About Tab
          GestureDetector(
            onTap: () => _navigateToTab(context, BbcTab.about),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link,
                    color: activeTab == BbcTab.about ? brandColor : mutedColor,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'About',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: activeTab == BbcTab.about ? brandColor : mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Profile Tab
          GestureDetector(
            onTap: () => _navigateToTab(context, BbcTab.profile),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    color: activeTab == BbcTab.profile ? brandColor : mutedColor,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Profile',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: activeTab == BbcTab.profile ? brandColor : mutedColor,
                      fontWeight: FontWeight.w500,
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
}
