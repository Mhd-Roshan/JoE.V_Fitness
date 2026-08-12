import 'package:flutter/material.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation; // Added for smooth zooming

  @override
  void initState() {
    super.initState();

    // QUICKER: Sped up the animation to 600ms
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // SMOOTHER: Uses easeOut curve so it slows down beautifully at the end
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // SMOOTHER: A very subtle zoom-in effect while it fades
    _scaleAnimation =
        Tween<double>(
          begin: 0.85, // Starts at 85% size
          end: 1.0, // Finishes at 100% size
        ).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutCubic, // Buttery smooth deceleration
          ),
        );

    _fadeController.forward();
    _navigateToWelcome();
  }

  Future<void> _navigateToWelcome() async {
    // QUICKER: Reduced waiting time from 2200ms to just 1400ms!
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        // QUICKER: Faster transition into the Welcome Screen
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(opacity: animation, child: const WelcomeScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Light/Clean)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB9CCF2),
                  Colors.white,
                  Colors.white,
                  Color(0xFFF2C6CB),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          // INSTAGRAM STYLE: Center Logo with Smooth Zoom & Fade
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation, // Applied the new smooth scale
                child: Image.asset(
                  'assets/images/landing_photo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // INSTAGRAM STYLE: Bottom Branding Text with Smooth Zoom & Fade
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation, // Applied the new smooth scale
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- KERALA'S 1ST HOME FITNESS TAGLINE ---
                      Text(
                        "Kerala's 1st",
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          color: Color(0xFFBA0C19), // Brand Red
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "HOME FITNESS",
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          color: Color(0xFF001A4D), // Deep Dark Blue
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ],
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
