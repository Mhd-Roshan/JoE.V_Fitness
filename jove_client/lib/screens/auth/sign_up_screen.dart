import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters!
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_background.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;

  // Error tracking variables for red borders
  bool _nameError = false;
  bool _emailError = false;
  bool _phoneError = false;
  String _phoneErrorMessage = 'Please enter your phone number';

  @override
  void initState() {
    super.initState();
    // Listeners to clear the red error borders when the user starts typing
    _nameController.addListener(() {
      if (_nameError) setState(() => _nameError = false);
    });
    _emailController.addListener(() {
      if (_emailError) setState(() => _emailError = false);
    });
    _phoneController.addListener(() {
      if (_phoneError) setState(() => _phoneError = false);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // 1. VALIDATION: Check for empty fields and trigger red borders
    bool isPhoneEmpty = phone.isEmpty;
    bool isPhoneShort = phone.isNotEmpty && phone.length < 10;

    setState(() {
      _nameError = name.isEmpty;
      _emailError = email.isEmpty;
      _phoneError = isPhoneEmpty || isPhoneShort;

      if (isPhoneEmpty) {
        _phoneErrorMessage = 'Please enter your phone number';
      } else if (isPhoneShort) {
        _phoneErrorMessage = 'Please enter a valid 10-digit number';
      }
    });

    if (_nameError || _emailError || _phoneError) {
      return; // Stop here if there are errors
    }

    setState(() => _isLoading = true);

    // 2. Format Phone Number for Firebase (Automatically adds +91)
    String formattedPhone = '+91$phone';

    try {
      // 3. SAVE REAL DATA TO FIRESTORE DATABASE
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'name': name,
        'email': email,
        'phone': formattedPhone,
        'assessmentCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. CHECK IF SCREEN IS STILL OPEN BEFORE USING CONTEXT
      if (!mounted) return;

      setState(() => _isLoading = false);

      // SHOW SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Account created successfully! Please log in to verify.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // NAVIGATE TO LOGIN SCREEN
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error creating account: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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

            // Logo
            Image.asset(
              'assets/images/landing_photo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),

            // Titles
            const Text(
              'Sign Up To JoE.V',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register account to beginning journey',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // Input Fields with Dynamic Error Logic
            _buildInputField(
              label: 'Name',
              hint: 'Enter Name',
              icon: Icons.person_outline,
              controller: _nameController,
              hasError: _nameError,
              errorMsg: 'Please enter your name',
            ),
            const SizedBox(height: 20),

            _buildInputField(
              label: 'Email',
              hint: 'Joevfitness@gmail.com',
              icon: Icons.email_outlined,
              controller: _emailController,
              hasError: _emailError,
              errorMsg: 'Please enter your email',
            ),
            const SizedBox(height: 20),

            // UPDATED PHONE FIELD
            _buildInputField(
              label: 'Phone',
              hint: '9087654321',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              hasError: _phoneError,
              errorMsg: _phoneErrorMessage,
              isPhone: true,
            ),
            const SizedBox(height: 40),

            // Sign Up Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA0C19), // Red
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
                            'Sign Up',
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
            const SizedBox(height: 40),

            // Bottom Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account? ",
                  style: TextStyle(color: Colors.white),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  ),
                  child: const Text(
                    'Sign In.',
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

  // Custom Input Field upgraded with +91 logic and Red Error Borders!
  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool hasError,
    required String errorMsg,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isPhone
              ? TextInputType.phone
              : TextInputType.emailAddress,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),

          // STRICT 10-DIGIT LIMIT IF IT IS A PHONE FIELD
          inputFormatters: isPhone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : null,

          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,

            // IF IT IS A PHONE NUMBER, ADD THE FANCY +91 PREFIX
            prefixIcon: isPhone
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.black87),
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
                  )
                : Icon(
                    icon,
                    color: Colors.black87,
                  ), // Normal Icon for Name/Email
            // RED ERROR BORDER LOGIC
            errorText: hasError ? errorMsg : null,
            errorStyle: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),

            // Standard Borders
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00CBE6), width: 2),
            ),
            // Error Borders
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
