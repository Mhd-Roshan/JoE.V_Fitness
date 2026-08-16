import 'dart:ui'; // <-- REQUIRED FOR BLUR EFFECT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart'; // <-- REQUIRED FOR PREMIUM FONTS

import 'auth_background.dart';
import 'sign_up_screen.dart';
import 'otp_screen.dart';
import 'assessment_screen.dart';
// import 'home_dashboard_screen.dart'; // <-- IMPORT YOUR ACTUAL HOME DASHBOARD FILE HERE

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // --- MODERN FLOATING SNACKBAR FOR ERRORS/INFO ---
  void _showModernSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFBB0013)
            : const Color(0xFF00CBE6).withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // --- MODERN GLASSMORPHISM "NO ACCOUNT" DIALOG ---
  void _showNoAccountPrompt() {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.7,
                ), // Semi-transparent dark
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Missing Account Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFE67E22,
                      ).withValues(alpha: 0.2), // Soft orange warning
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_search_outlined,
                      color: Color(0xFFE67E22),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Account Not Found',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'This phone number is not registered yet. Please create an account to begin your journey.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons (Cancel & Sign Up)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF00CBE6,
                              ), // Cyan accent
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // PHONE LOGIN LOGIC
  // ==========================================
  Future<void> _handleSignIn() async {
    final input = _phoneController.text.trim();

    if (input.isEmpty) {
      setState(() => _errorText = 'Please enter your phone number');
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final cleanPhone = input.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanPhone.length < 10) {
        setState(() {
          _errorText = 'Please enter a valid 10-digit number';
          _isLoading = false;
        });
        return;
      }

      final formattedPhone =
          '+91${cleanPhone.substring(cleanPhone.length - 10)}';

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: formattedPhone)
          .where('role', isEqualTo: 'client')
          .limit(1)
          .get();

      final pendingQuery = await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(formattedPhone)
          .get();

      if (!mounted) return;

      if (userQuery.docs.isEmpty && !pendingQuery.exists) {
        setState(() => _isLoading = false);
        _showNoAccountPrompt(); // <-- Called the new modern prompt
        return;
      }

      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OtpScreen(phone: formattedPhone, isSignUp: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showModernSnackBar(
        'Error verifying account. Please check your connection.',
        isError: true,
      );
    }
  }

  // ==========================================
  // GOOGLE "G" BUTTON LOGIN LOGIC (FIREBASE)
  // ==========================================
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final userDoc = await userDocRef.get();

        bool hasCompletedAssessment = false;

        if (!userDoc.exists) {
          await userDocRef.set({
            'role': 'client',
            'authProvider': 'google',
            'fullName': user.displayName ?? '',
            'email': user.email ?? '',
            'phone': user.phoneNumber ?? '',
            'assessmentCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          hasCompletedAssessment =
              userDoc.data()?['assessmentCompleted'] ?? false;
        }

        if (!mounted) return;

        if (hasCompletedAssessment) {
          // Navigator.pushAndRemoveUntil(
          //   context,
          //   MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          //   (route) => false,
          // );
          _showModernSnackBar(
            "Google Sign-In Successful! Routing to Home Screen...",
            isError: false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AssessmentScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar('Google Sign-In failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // --- Logo ---
                        Image.asset(
                          'assets/images/landing_photo.png',
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.fitness_center,
                              size: 100,
                              color: Colors.white,
                            );
                          },
                        ),
                        const SizedBox(height: 40),

                        // --- Titles with Custom SVG Kettlebell Icon ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Sign In To JoE',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3.0,
                              ),
                              child: Transform.translate(
                                offset: const Offset(0, 4),
                                child: SvgPicture.asset(
                                  'assets/images/kettlebell-icon.svg',
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                            const Text(
                              'V',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Login to continue your journey',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // --- Input Field (PHONE ONLY) ---
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF4F4F4),
                            hintText: '9087654321',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w400,
                            ),
                            errorText: _errorText,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '+91',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF01BCE3),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF01BCE3),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Sign In Button ---
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBB0013),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // --- Google Sign In Button ---
                        GestureDetector(
                          onTap: _isLoading ? null : _signInWithGoogle,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white70,
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // --- Footer Text ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0, top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignUpScreen(),
                                  ),
                                ),
                                child: const Text(
                                  "Sign Up.",
                                  style: TextStyle(
                                    color: Color(0xFF01BCE3),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF01BCE3),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
