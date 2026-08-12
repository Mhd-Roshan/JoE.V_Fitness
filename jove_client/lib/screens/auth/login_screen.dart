import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_background.dart';
import 'sign_up_screen.dart';
import 'otp_screen.dart';
import 'assessment_screen.dart';

// import 'home_screen.dart'; // UNCOMMENT THIS ONCE YOU CREATE YOUR HOME SCREEN!

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _inputError = false;
  String _errorMessage = 'Please enter a valid 10-digit number';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (_inputError) {
        setState(() => _inputError = false); // Clear error when typing
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // --- SMART NAVIGATION HELPER ---
  Future<void> _checkAssessmentAndNavigate(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      bool hasCompleted = false;

      if (userDoc.exists && userDoc.data() != null) {
        hasCompleted =
            (userDoc.data() as Map<String, dynamic>)['assessmentCompleted'] ??
            false;
      }

      if (mounted) {
        if (hasCompleted) {
          _showMessage("Login Successful! Going to Home...", isError: false);
          // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AssessmentScreen()),
          );
        }
      }
    } catch (e) {
      _showMessage("Error checking profile data.");
      setState(() => _isLoading = false);
    }
  }

  // --- PASSWORDLESS LOGIN WITH FIRESTORE VERIFICATION ---
  Future<void> _handleLogin() async {
    final input = _phoneController.text.trim();

    // 1. VALIDATION (Must be exactly 10 digits)
    if (input.isEmpty || input.length < 10) {
      setState(() {
        _inputError = true;
        _errorMessage = 'Please enter a valid 10-digit number';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- CHECK IF PHONE EXISTS IN DATABASE ---
      String phoneNumber = '+91$input'; // Automatically attach the +91

      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .get();

      if (userQuery.docs.isEmpty) {
        // PHONE NOT REGISTERED -> FORCE SIGN UP
        setState(() => _isLoading = false);
        _showNoAccountPrompt();
        return;
      }

      // PHONE IS REGISTERED -> GO TO OTP SCREEN
      setState(() => _isLoading = false);
      Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(phone: phoneNumber, isSignUp: false),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error verifying account. Please check your connection.");
    }
  }

  // --- DIALOG: FORCES UNREGISTERED USERS TO SIGN UP ---
  void _showNoAccountPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Account Not Found",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This phone number is not registered yet. Please create an account to begin your journey.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SignUpScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CBE6),
            ),
            child: const Text(
              "Sign Up",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REAL GOOGLE SIGN IN ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // Save their info to Firestore just in case they are brand new
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': userCredential.user!.displayName ?? '',
            'email': userCredential.user!.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await _checkAssessmentAndNavigate(userCredential.user!.uid);
    } catch (e) {
      _showMessage("Google Sign-In failed. Please try again.");
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildGoogleButton() {
    return InkWell(
      onTap: _isLoading ? null : _signInWithGoogle,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: const Center(
          child: Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'sans-serif',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            Image.asset(
              'assets/images/landing_photo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
            const Text(
              'Sign In To JoE.V',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Login to continue your journey',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // Phone Field
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Phone Number',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              // STRICLY LIMIT TO 10 NUMBERS ONLY!
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: '9876543210',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,

                // PRESET +91 DESIGN
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_iphone, color: Colors.black87),
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
                      Container(width: 1, height: 24, color: Colors.grey),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // RED ERROR BORDER LOGIC
                errorText: _inputError ? _errorMessage : null,
                errorStyle: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00CBE6),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Send Code / Sign In Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA0C19),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get OTP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 35),

            // Google Button
            _buildGoogleButton(),

            const SizedBox(height: 40),

            // Bottom Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.white),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignUpScreen(),
                    ),
                  ),
                  child: const Text(
                    'Sign Up.',
                    style: TextStyle(
                      color: Color(0xFF00CBE6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
