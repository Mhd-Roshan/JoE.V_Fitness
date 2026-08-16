import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/sc2.jpg',
      'title': 'Transform Your\nBody & Mind',
      'quote':
          'Improve your flexibility, build strength, reduce stress, and find inner peace through expert-guided yoga sessions designed for all experience levels.',
    },
    {
      'image': 'assets/images/sc3.jpg',
      'title': 'Dance Your Way\nto Fitness',
      'quote':
          'Burn calories, improve heart health, boost energy, strengthen your body, enhance flexibility and coordination, reduce stress, increase stamina, and make fitness fun.',
    },
    {
      'image': 'assets/images/sc4.jpg',
      'title': 'Health Metrics &\nFitness Analytics',
      'quote':
          'Track your workouts, monitor your progress, measure key health metrics, and gain insights to achieve your fitness goals.',
    },
    {
      'image': 'assets/images/sc5.jpg',
      'title': 'Nutrition & Diet\nGuidance',
      'quote':
          'Follow personalized meal plans, monitor your trainer\'s diet recommendations, and maintain healthy eating habits to support your fitness goals.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextAction() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
          // 1. Swipeable Background Images
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return Image.asset(
                _pages[index]['image']!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              );
            },
          ),

          // 2. LIQUID FROSTED GLASS (Darkened for better text readability)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.55,
            child: ClipRect(
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.15],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: BackdropFilter(
                  // 60.0 creates the heavy Apple-style color melt
                  filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
                  child: Container(
                    // INCREASED DARKNESS HERE so white text is crystal clear
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(
                            alpha: 0.6,
                          ), // Darker tint behind the text
                          Colors.black.withValues(
                            alpha: 0.9,
                          ), // Darkest at the bottom for buttons
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. UI Content (Text + Navigation)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Title
                  Text(
                    page['title']!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      // Boosted the text shadow for extra readability
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      page['quote']!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.8,
                        // Boosted the text shadow for extra readability
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),

                  // 4. Bottom Row (Indicators & BUTTON)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left Side: Page Indicators
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_pages.length, (index) {
                          bool isActive = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            height: 8,
                            width: isActive ? 24 : 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),

                      // Right Side: GLASS BUTTON
                      GestureDetector(
                        onTap: _nextAction,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 15.0,
                              sigmaY: 15.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentPage == _pages.length - 1
                                        ? 'START'
                                        : 'NEXT',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
