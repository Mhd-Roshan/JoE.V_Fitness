import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:slide_to_act/slide_to_act.dart';
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
          // 1. Background Image
          Image.asset(
            'assets/images/sc0.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),

          // 2. Black Gradient Overlayr
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.90),
                  Colors.black,
                ],
                stops: const [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),

          // 3. Premium Fade-In Animation
          SafeArea(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  // --- LANGUAGE SELECTOR (CLEAR GLASS) ---
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.only(top: 16, right: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Eng',
                                  style: TextStyle(
                                    fontFamily: 'WorkSans',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // --- CENTER CONTENT ---

                  // Logo
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      1.2,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1.2,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1.2,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: Image.asset(
                      'assets/images/landing_photo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // "Eyebrow" Welcome Text
                  Text(
                    'WELCOME TO',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: const Color(0xFF00CBE6).withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- JoE V FITNESS LOGO ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'JoE',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontSize: 42,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          height: 1.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4.0,
                          right: 6.0,
                          bottom: 3.0,
                        ),
                        child: SvgPicture.asset(
                          'assets/images/kettlebell-icon.svg',
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF00CBE6),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const Text(
                        'V FITNESS',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontSize: 42,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    'Experience the next level of fitness.',
                    style: TextStyle(
                      fontFamily: 'WorkSans',
                      color: Color(0xFFB0B0B0),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // --- SLIDER DESIGN ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: SlideAction(
                      outerColor: const Color(0xFF1E1E1E),
                      innerColor: const Color(0xFFBA0C19),
                      sliderButtonIconSize: 24,
                      sliderRotate: false,
                      borderRadius: 40,
                      elevation: 0,
                      animationDuration: const Duration(milliseconds: 300),
                      sliderButtonIcon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 28,
                      ),
                      // FIX: Using child instead of text removes the transparent animation completely
                      child: const Text(
                        'Swipe to Get Started  > > >',
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onSubmit: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: const OnboardingScreen(),
                                    ),
                          ),
                        );
                        return Future.value();
                      },
                    ),
                  ),

                  const SizedBox(height: 35),

                  // --- LOGIN LINK ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          color: Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: const LoginScreen(),
                                      ),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontFamily: 'WorkSans',
                            color: Color(0xFF00CBE6),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF00CBE6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
