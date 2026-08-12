import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003893), // Deep Blue Background
      body: Stack(
        children: [
          // Custom drawn wavy lines
          CustomPaint(
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
            painter: WavePainter(),
          ),
          // The actual screen content
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
          .withValues(
            alpha: 0.15,
          ) // FIXED: using withValues instead of withOpacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Top right circles
    for (double i = 50; i < 600; i += 70) {
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), i, paint);
    }
    // Bottom left circles
    for (double i = 50; i < 600; i += 70) {
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), i, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
