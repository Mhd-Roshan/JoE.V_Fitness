import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'onboarding_screen.dart';
import 'auth/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/sc1.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),

          // Black Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),

          // UI Content
          SafeArea(
            child: Column(
              children: [
                // Language Selector
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 16, right: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          size: 16,
                          color: Color(0xFF1E3A8A),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Eng',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Brightened Logo
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    1.2, 0, 0, 0, 0, // Boost Red brightness
                    0, 1.2, 0, 0, 0, // Boost Green brightness
                    0, 0, 1.2, 0, 0, // Boost Blue brightness
                    0, 0, 0, 1, 0, // Keep Alpha same
                  ]),
                  child: Image.asset(
                    'assets/images/landing_photo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 15),

                // Welcome Text - Extra Bold Italic
                const Text(
                  'Welcome',
                  style: TextStyle(
                    color: Color(0xFF00CBE6),
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                // --- CUSTOM TEXT WITH KETTLEBELL ICON & WORKSANS FONT ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'JoE',
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        color: Colors.white,
                        fontSize: 34,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                        letterSpacing:
                            2.0, // Keeps the letters spaced out nicely
                      ),
                    ),
                    Padding(
                      // 👇 REDUCED GAP: Changed from 6.0 down to 2.0 to pull the icon and text tightly together!
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Transform.translate(
                        offset: const Offset(0, 6),
                        child: SvgPicture.asset(
                          'assets/images/kettlebell-icon.svg',
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'V FITNESS',
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        color: Colors.white,
                        fontSize: 34,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),

                // ---------------------------------------------
                const SizedBox(height: 4),

                // Experience Text - Extra Bold Italic
                const Text(
                  'Experience the next level of fitness',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 35),

                // Get Started Button -> Goes to Onboarding
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnboardingScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA0C19),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Login Link -> Goes directly to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have account? ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color(0xFF00CBE6),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
