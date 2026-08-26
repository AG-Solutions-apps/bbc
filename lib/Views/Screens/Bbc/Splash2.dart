import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'LoginScreen.dart';
import 'OnBoardingSlider.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── Brand palette ────────────────────────────────────────────────────────────
const _kBrand     = Color(0xFFB0126B);
const _kBrandDeep = Color(0xFF8A0D55);
const _kPlum      = Color(0xFF9C3A8B);
const _kBlue      = Color(0xFF2196F3);
const _kBlueLight  = Color(0xFF64B5F6);
const _kBlueDark   = Color(0xFF1976D2);
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen2 extends StatefulWidget {
  const SplashScreen2({super.key});

  @override
  State<SplashScreen2> createState() => _SplashScreen2State();
}

class _SplashScreen2State extends State<SplashScreen2>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // ── Individual animation handles ─────────────────────────────────────────
  late Animation<double>  _logoFade;
  late Animation<double>  _logoScale;
  late Animation<double>  _badgeFade;
  late Animation<double>  _badgeScale;
  late Animation<double>  _loaderFade;
  late Animation<double>  _agFade;
  late Animation<Offset>  _agSlide;
  late Animation<double>  _chipsFade;
  late Animation<Offset>  _chipsSlide;
  late Animation<double>  _loveFade;
  late Animation<Offset>  _loveSlide;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    // BBC logo – drops in first
    _logoFade = _curve(0.00, 0.45, Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.00, 0.55, curve: Curves.easeOutBack)));

    // Trust badge
    _badgeFade  = _curve(0.45, 0.75, Curves.easeIn);
    _badgeScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.45, 0.75, curve: Curves.easeOutBack)));

    // Loading spinner
    _loaderFade = _curve(0.60, 0.85, Curves.easeIn);

    // AG Solutions logo
    _agFade  = _curve(0.65, 0.90, Curves.easeIn);
    _agSlide = _slide(0.65, 0.90, dy: 0.3);

    // Service chips
    _chipsFade  = _curve(0.75, 1.00, Curves.easeIn);
    _chipsSlide = _slide(0.75, 1.00, dy: 0.5);
    
    // Love text
    _loveFade = _curve(0.85, 1.00, Curves.easeIn);
    _loveSlide = _slide(0.85, 1.00, dy: 0.3);

    _ctrl.forward();

    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Animation<double> _curve(double from, double to, Curve curve) =>
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _ctrl, curve: Interval(from, to, curve: curve)));

  Animation<Offset> _slide(double from, double to,
          {double dx = 0, double dy = 0}) =>
      Tween<Offset>(begin: Offset(dx, dy), end: Offset.zero).animate(
          CurvedAnimation(
              parent: _ctrl,
              curve: Interval(from, to, curve: Curves.easeOutCubic)));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top / Center logo section
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                // ── BBC LOGO (centered) ───────────
                                FadeTransition(
                                  opacity: _logoFade,
                                  child: ScaleTransition(
                                    scale: _logoScale,
                                    child: Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kBrand.withOpacity(0.12),
                                            blurRadius: 40,
                                            spreadRadius: 8,
                                          ),
                                          BoxShadow(
                                            color: _kPlum.withOpacity(0.08),
                                            blurRadius: 60,
                                            spreadRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        "assets/images/bbclogo.png",
                                        height: 170,
                                        width: 170,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 30),

                                // Powered by 100+ Business
                                FadeTransition(
                                  opacity: _badgeFade,
                                  child: ScaleTransition(
                                    scale: _badgeScale,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 22, vertical: 11),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [_kBrandDeep, _kPlum],
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kBrand.withOpacity(0.35),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.verified_rounded,
                                              size: 18, color: Colors.white),
                                          SizedBox(width: 9),
                                          Text(
                                            "Powered by 100+ Business",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // Loading Indicator
                                FadeTransition(
                                  opacity: _loaderFade,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(_kBrand),
                                          backgroundColor: _kBrand.withOpacity(0.12),
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        "Loading Amazing Experience...",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _kBrand.withOpacity(0.55),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),

                          // Bottom Footer Section
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── DIVIDER ──
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 30),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: const Color.fromARGB(255, 33, 150, 243).withOpacity(0.2),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _kBlue.withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: _kBlue.withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Crafted with Love Text + AG Solutions Logo
                              SlideTransition(
                                position: _loveSlide,
                                child: FadeTransition(
                                  opacity: _loveFade,
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "This app is Crafted with",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black.withOpacity(0.5),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.favorite,
                                            size: 15,
                                            color: Color.fromARGB(255, 255, 0, 0),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "by",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black.withOpacity(0.5),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Image.asset(
                                        "assets/images/ag1.png",
                                        height: 55,
                                        width: 170,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Service Chips (Blue themed)
                              SlideTransition(
                                position: _chipsSlide,
                                child: FadeTransition(
                                  opacity: _chipsFade,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _blueChip(Icons.public, "Web"),
                                        _blueChip(Icons.phone_android, "Mobile App"),
                                        _blueChip(Icons.web, "Web App"),
                                        _blueChip(Icons.design_services, "UI/UX"),
                                        _blueChip(Icons.trending_up, "Digital Marketing"),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Blue themed chip widget for AG Solutions section
  Widget _blueChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 255, 255, 255),
            const Color.fromARGB(255, 255, 255, 255).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color.fromARGB(255, 33, 150, 243).withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 33, 150, 243).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color.fromARGB(255, 255, 255, 255), const Color.fromARGB(255, 255, 255, 255)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              size: 14, 
              color: const Color.fromARGB(255, 33, 150, 243),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: const Color.fromARGB(255, 0, 0, 0),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}