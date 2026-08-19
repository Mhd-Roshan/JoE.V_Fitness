import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _phoneError;

  // Animation controllers
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Button press scale
  double _signUpScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    // Start entrance animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- MODERN FLOATING SNACKBAR FOR ERRORS ---
  void _showModernSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
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
            : const Color(0xFFE67E22),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // --- MODERN GLASSMORPHISM SUCCESS DIALOG ---
  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'dismiss'.tr(), // TRANSLATED
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6), // Dark glass
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Success Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E4EF4).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF1E4EF4),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'registration_successful'.tr(), // TRANSLATED
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
                        'registration_success_desc'.tr(), // TRANSLATED
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Button (Red to match your theme)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBB0013), // Red
                            foregroundColor: Colors.white, // White text
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'sign_in_now_btn'.tr(), // TRANSLATED
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'err_enter_name'.tr() : null; // TRANSLATED
      _emailError = (email.isEmpty || !email.contains('@'))
          ? 'err_valid_email'
                .tr() // TRANSLATED
          : null;
      _phoneError = phone.length < 10
          ? 'err_valid_phone'
                .tr() // TRANSLATED
          : null;
    });

    if (_nameError != null || _emailError != null || _phoneError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedPhone = '+91$phone';

      final existingUserQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: formattedPhone)
          .where('role', isEqualTo: 'client')
          .limit(1)
          .get();

      if (!mounted) return;

      if (existingUserQuery.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        _showModernSnackBar(
          'err_phone_registered'.tr(), // TRANSLATED
          isError: false,
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(formattedPhone)
          .set({
            'name': name,
            'email': email,
            'phone': formattedPhone,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showModernSnackBar(
        'err_connection'.tr(), // TRANSLATED
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- NEW: VIBRANT BLUE TO DARK LINEAR GRADIENT ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E4EF4), // Requested Specific Blue
                  Color(0xFF04081C), // Deep dark color at the bottom
                ],
                stops: [0.0, 0.85], // Controls how smoothly it transitions down
              ),
            ),
          ),

          // --- ENTRANCE FADE + SLIDE WRAPPER ---
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),

                              // --- GLASSMORPHIC BACK BUTTON ---
                              Align(
                                alignment: Alignment.topLeft,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // --- ORIGINAL LOGO (No Color Filter) ---
                              Image.asset(
                                'assets/images/landing_photo.png',
                                height: 80,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.fitness_center,
                                    size: 80,
                                    color: Colors.white,
                                  );
                                },
                              ),

                              const SizedBox(height: 30),

                              // --- TITLE & SUBTITLE ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'sign_up_to_joe'.tr(), // TRANSLATED
                                    style: GoogleFonts.workSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4.0,
                                      right: 6.0,
                                      bottom: 0.0,
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/images/kettlebell-icon.svg',
                                      height: 15,
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFFBB0013), // Red kettlebell
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'V', // Brand element
                                    style: GoogleFonts.workSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'register_subtitle'.tr(), // TRANSLATED
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // --- Smooth Input Fields (Glassmorphic) ---
                              _AnimatedInputField(
                                label: 'name_label'.tr(), // TRANSLATED
                                hint: 'name_hint'.tr(), // TRANSLATED
                                icon: Icons.person_outline,
                                controller: _nameController,
                                error: _nameError,
                              ),
                              const SizedBox(height: 20),

                              _AnimatedInputField(
                                label: 'email_label'.tr(), // TRANSLATED
                                hint: 'email_hint'.tr(), // TRANSLATED
                                icon: Icons.email_outlined,
                                controller: _emailController,
                                error: _emailError,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20),

                              _AnimatedInputField(
                                label: 'phone_label'.tr(), // TRANSLATED
                                hint: 'phone_hint'.tr(), // TRANSLATED
                                icon: Icons.phone_outlined,
                                controller: _phoneController,
                                error: _phoneError,
                                keyboardType: TextInputType.phone,
                                isPhone: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // --- SIGN UP BUTTON (Animated RED Button) ---
                              GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _signUpScale = 0.96),
                                onTapUp: (_) =>
                                    setState(() => _signUpScale = 1.0),
                                onTapCancel: () =>
                                    setState(() => _signUpScale = 1.0),
                                onTap: _isLoading ? null : _handleSignUp,
                                child: AnimatedScale(
                                  scale: _signUpScale,
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleSignUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFBB0013, // Red button same as Login
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                key: ValueKey('loader'),
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  color: Colors
                                                      .white, // White loader
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : Row(
                                                key: const ValueKey('label'),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'sign_up_btn'
                                                        .tr(), // TRANSLATED
                                                    style: GoogleFonts.workSans(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors
                                                          .white, // White text
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.arrow_forward,
                                                    color: Colors
                                                        .white, // White icon
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // --- Footer ---
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 50.0,
                                  top: 20.0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'already_have_account'.tr(), // TRANSLATED
                                      style: GoogleFonts.workSans(
                                        color: Colors.white60,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen(),
                                        ),
                                      ),
                                      child: Text(
                                        'sign_in_link_dot'.tr(), // TRANSLATED
                                        style: GoogleFonts.workSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white,
                                          fontSize: 14,
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
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// DEDICATED WIDGET FOR BUTTERY SMOOTH INPUT FIELD TRANSITIONS (GLASSMORPHIC)
// ===================================================================
class _AnimatedInputField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? error;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPhone;

  const _AnimatedInputField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.error,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.isPhone = false,
  });

  @override
  State<_AnimatedInputField> createState() => _AnimatedInputFieldState();
}

class _AnimatedInputFieldState extends State<_AnimatedInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic colors for Glassmorphic dark overlay
    final borderColor = widget.error != null
        ? Colors.redAccent
        : _isFocused
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.15);

    final iconColor = widget.error != null
        ? Colors.redAccent
        : _isFocused
        ? Colors.white
        : Colors.white54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Text
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          style: GoogleFonts.poppins(
            color: _isFocused ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),

        // Animated Input Box
        AnimatedScale(
          scale: _isFocused ? 1.01 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8,
                sigmaY: 8,
              ), // Blur for glass effect
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  // Semi-transparent black over the blue gradient creates depth
                  color: _isFocused
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: _isFocused || widget.error != null ? 1.5 : 1.0,
                  ),
                  boxShadow: _isFocused && widget.error == null
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  cursorColor: Colors.white,
                  cursorRadius: const Radius.circular(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedTheme(
                            data: ThemeData(
                              iconTheme: IconThemeData(color: iconColor),
                            ),
                            child: Icon(widget.icon, size: 20),
                          ),
                          if (widget.isPhone) ...[
                            const SizedBox(width: 8),
                            const Text(
                              '+91',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          // Vertical divider
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 1,
                            height: 20,
                            color: _isFocused ? Colors.white54 : Colors.white24,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Smooth Error Text Expand/Collapse
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: widget.error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    widget.error!,
                    style: GoogleFonts.poppins(
                      color: const Color(
                        0xFFFF5252,
                      ), // Bright red for dark mode
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
