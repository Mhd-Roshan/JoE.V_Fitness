import 'dart:ui';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoBlur;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    const revealDuration = Duration(milliseconds: 900);
    const revealCurve = Curves.easeOutCubic;

    _logoController = AnimationController(
      vsync: this,
      duration: revealDuration,
    );
    _logoBlur = Tween<double>(
      begin: 10.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: revealCurve));
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoScale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: revealCurve));

    // Ambient breathing glow behind the logo.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _logoController.forward();

    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(opacity: animation, child: const LoginScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
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

          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = 0.5 + (_pulseController.value * 0.5);
                    return Container(
                      width: 220 * pulse,
                      height: 220 * pulse,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Logo: blur-to-focus + fade + gentle scale settle.
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _logoBlur.value,
                            sigmaY: _logoBlur.value,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/images/landing_photo.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
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
