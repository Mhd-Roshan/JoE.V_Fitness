import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/trainer_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorText;

  // Focus nodes to track active state
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Enter both email and password.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Navigate to TrainerHomeScreen on successful login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TrainerHomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          message = 'No account found with these credentials.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Try again.';
          break;
        case 'invalid-email':
          message = 'Enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later.';
          break;
        default:
          message = 'Couldn\'t sign in. Check your connection and try again.';
      }
      setState(() => _errorText = message);
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003AA3),
      body: Stack(
        children: [
          // Decorative concentric ring circles - top right
          const Positioned(
            top: -63,
            right: -45,
            child: _ConcentricCircles(size: 220),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 29, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 135),

                  // Logo/Document image
                  Center(
                    child: Image.asset(
                      'assets/images/landing_photo.png',
                      width: 145,
                      height: 145,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Title
                  const Text(
                    'Sign In To JoE  V',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.75,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Login account to beginning journey',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFDCDCDC),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 34),

                  // Email field
                  const _FieldLabel('Email'),
                  const SizedBox(height: 8),
                  _AuthTextField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    hint: 'Joevfitness@gmail.co',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isActive: _emailFocusNode.hasFocus,
                  ),

                  const SizedBox(height: 25),

                  // Password field
                  const _FieldLabel('Password'),
                  const SizedBox(height: 8),
                  _AuthTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hint: 'Enter  Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    isActive: _passwordFocusNode.hasFocus,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFFBFBFBF),
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),

                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFB4B4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),

                  // Sign In button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBB0013),
                        disabledBackgroundColor: const Color(
                          0xFFBB0013,
                        ).withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.isActive = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? const Color(0xFF01BCE3) : Colors.transparent,
          width: 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF01BCE3).withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Color(0xFF111214),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF111214), size: 24),
          suffixIcon: suffixIcon,
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFBFBFBF),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

/// Concentric circles decoration matching the design
class _ConcentricCircles extends StatelessWidget {
  const _ConcentricCircles({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBFBFBF).withValues(alpha: 0.5),
                width: 4,
              ),
            ),
          ),
          // Inner circle
          Container(
            width: size * 0.545,
            height: size * 0.545,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBFBFBF).withValues(alpha: 0.5),
                width: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
