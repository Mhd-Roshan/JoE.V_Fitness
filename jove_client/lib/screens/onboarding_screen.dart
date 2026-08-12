import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  bool _showDetails = false;
  Timer? _autoPopTimer;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/sc2.png',
      'title': 'Transform Your\nBody & Mind',
      'subtitle': 'Experience trainer at your home',
      'quote':
          '"Improve your flexibility, build strength, reduce stress, and find inner peace through expert-guided yoga sessions designed for all experience levels."',
    },
    {
      'image': 'assets/images/sc3.png',
      'title': 'Dance Your Way\nto Fitness',
      'subtitle': 'Follow expert Zumba routines',
      'quote':
          '"Burn calories, improve heart health, boost energy, strengthen your body, enhance flexibility and coordination, reduce stress, increase stamina, and make fitness fun."',
    },
    {
      'image': 'assets/images/sc4.png',
      'title': 'Health Metrics &\nFitness Analytics',
      'subtitle': 'Track progress with analytics',
      'quote':
          '"Track your workouts, monitor your progress, measure key health metrics, and gain insights to achieve your fitness goals."',
    },
    {
      'image': 'assets/images/sc5.png',
      'title': 'Nutrition & Diet\nGuidance',
      'subtitle': 'Personalized nutrition guidance',
      'quote':
          '"Follow personalized meal plans, monitor your trainer\'s diet recommendations, and maintain healthy eating habits to support your fitness goals."',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPopTimer(); // Start the timer on the very first screen
  }

  @override
  void dispose() {
    _autoPopTimer?.cancel(); // Cancel timer if user leaves the screen
    super.dispose();
  }

  // --- THIS FUNCTION HANDLES THE AUTOMATIC POP-UP ---
  void _startAutoPopTimer() {
    _autoPopTimer?.cancel();
    setState(() {
      _showDetails = false; // Reset to clean image
    });

    // Wait for 1.5 seconds, then automatically pop up the text and enable buttons
    _autoPopTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showDetails = true;
        });
      }
    });
  }

  void _nextAction() {
    if (_currentPage < _pages.length - 1) {
      setState(() {
        _currentPage++;
      });
      _startAutoPopTimer(); // Restart the process for the next page
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _previousAction() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _startAutoPopTimer(); // Restart the process for the previous page
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image with Premium Fade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Image.asset(
              page['image']!,
              key: ValueKey<String>(page['image']!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // 2. Ultra-Smooth Animated Blur Effect
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: _showDetails ? 12.0 : 0.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, blurValue, child) {
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                child: Container(
                  color: Colors.black.withValues(
                    alpha: _showDetails ? 0.5 : 0.0,
                  ),
                ),
              );
            },
          ),

          // 3. Dark Bottom Gradient (Always visible for readability)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 1.0),
                ],
                stops: const [0.0, 0.5, 0.8, 1.0],
              ),
            ),
          ),

          // 4. UI Content (Text)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Modern Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      page['title']!,
                      key: ValueKey<String>(page['title']!),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated Quote Text (Slides up & Fades in automatically!)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _showDetails ? 1.0 : 0.0,
                    curve: Curves.easeOut,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 600),
                      offset: _showDetails ? Offset.zero : const Offset(0, 0.2),
                      curve: Curves.easeOut,
                      child: Column(
                        children: [
                          // Modern Subtitle
                          Text(
                            page['subtitle']!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: const Color(
                                0xFF00CBE6,
                              ), // A sleek neon cyan accent
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Quote Text
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              page['quote']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 140), // Space for bottom buttons
                ],
              ),
            ),
          ),

          // 5. PROGRESS BARS & MODERN BUTTONS
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Progress Lines
                Padding(
                  padding: const EdgeInsets.only(
                    top: 20.0,
                    left: 24,
                    right: 24,
                  ),
                  child: Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Buttons (They "Pop" in only when details are shown)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30.0,
                    left: 24,
                    right: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _showDetails ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 400),
                          scale: _showDetails ? 1.0 : 0.8,
                          curve: Curves.easeOutBack,
                          child: SizedBox(
                            width: 120,
                            height: 65,
                            child: ElevatedButton(
                              onPressed: _showDetails ? _previousAction : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              child: const Icon(Icons.arrow_back, size: 26),
                            ),
                          ),
                        ),
                      ),

                      // Next Button
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _showDetails ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 400),
                          scale: _showDetails ? 1.0 : 0.8,
                          curve: Curves.easeOutBack,
                          child: SizedBox(
                            width: 120,
                            height: 65,
                            child: ElevatedButton(
                              onPressed: _showDetails ? _nextAction : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Icon(Icons.arrow_forward, size: 26),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
