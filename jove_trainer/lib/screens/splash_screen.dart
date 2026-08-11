import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // The Telegram Animation sequences for Logo (Center)
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _positionAnimation;
  late final Animation<double> _opacityAnimation;

  // The Instagram Animation sequences for Text (Bottom)
  late final Animation<double> _textOpacityAnimation;
  late final Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    // SPEED UPDATE: Cut from 2200ms to 1500ms (1.5 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // ---------------------------------------------------------
    // 1. CENTER LOGO: TELEGRAM TAKEOFF PHYSICS
    // ---------------------------------------------------------
    _scaleAnimation = TweenSequence<double>([
      // Pop in with a quick bounce
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30.0,
      ),
      // Idle / Wait (to read text)
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 45.0),
      // Anticipation Squeeze (whips back)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.7,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 15.0,
      ),
      // Shrink as it flies off
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.7,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10.0,
      ),
    ]).animate(_controller);

    _positionAnimation = TweenSequence<Offset>([
      // Stay centered
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 85.0,
      ),
      // Shoots aggressively up and to the right (lightning fast)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(1.5, -2.0),
        ).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 15.0,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10.0,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 80.0),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10.0,
      ),
    ]).animate(_controller);

    // ---------------------------------------------------------
    // 2. BOTTOM TEXT: INSTAGRAM FADE & SLIDE UP
    // ---------------------------------------------------------
    _textOpacityAnimation = TweenSequence<double>([
      // Wait for logo to start popping in
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 20.0),
      // Fade in fast
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15.0,
      ),
      // Stay visible
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 45.0),
      // Fade out before logo flies away
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10.0,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 10.0),
    ]).animate(_controller);

    _textSlideAnimation = TweenSequence<Offset>([
      // Start slightly lower
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.0, 0.5)),
        weight: 20.0,
      ),
      // Slide up gently to default position
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.0, 0.5),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15.0,
      ),
      // Hold position
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 65.0,
      ),
    ]).animate(_controller);

    // Start the animation and navigate to Login
    _controller.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          // Lightning-fast crossfade into the app (250ms)
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle background gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFFE8F0FE),
                  Colors.white,
                  Colors.white,
                  Color(0xFFFDE8EA),
                ],
                stops: [0.0, 0.4, 0.6, 1.0],
              ),
            ),
          ),

          // 1. CENTER: The Telegram-style animated logo
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: SlideTransition(
                    position: _positionAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Image.asset(
                'assets/images/landing_photo.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 2. BOTTOM: The Instagram-style Tagline Text
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacityAnimation.value,
                    child: SlideTransition(
                      position:
                          _textSlideAnimation, // <--- FIXED TYPO HERE! No .value
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Kerala's 1st",
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFC7001A), // Brand Red
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "HOME FITNESS",
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00225D), // Brand Blue
                        letterSpacing: 3.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
