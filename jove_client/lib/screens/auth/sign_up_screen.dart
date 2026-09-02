import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Slightly faster duration for a snappier feel
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // OPTIMIZATION: Snappier curves
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );

    // Start entrance animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
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
      barrierLabel: 'dismiss'.tr(),
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
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
                      Text(
                        'registration_successful'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'registration_success_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
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
                            backgroundColor: const Color(0xFFBB0013),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'sign_in_now_btn'.tr(),
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
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'err_enter_name'.tr() : null;
      _emailError = (email.isEmpty || !email.contains('@'))
          ? 'err_valid_email'.tr()
          : null;
      _phoneError = phone.length < 10 ? 'err_valid_phone'.tr() : null;
    });

    if (_nameError != null || _emailError != null || _phoneError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedPhone = '+91$phone';

      // 1. Check if phone exists in 'users'
      final existingPhoneQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: formattedPhone)
          .where('role', isEqualTo: 'client')
          .limit(1)
          .get();

      // 2. Check if email exists in 'users'
      var existingEmailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'client')
          .limit(1)
          .get();

      // 3. Check if phone exists in 'pending_users'
      final pendingPhoneDoc = await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(formattedPhone)
          .get();

      // 4. Check if email exists in 'pending_users'
      var pendingEmailQuery = await FirebaseFirestore.instance
          .collection('pending_users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (!mounted) return;

      if (existingPhoneQuery.docs.isNotEmpty || pendingPhoneDoc.exists) {
        setState(() => _isLoading = false);
        _showModernSnackBar('err_phone_registered'.tr(), isError: false);
        return;
      }

      bool emailExists = existingEmailQuery.docs.isNotEmpty || pendingEmailQuery.docs.isNotEmpty;
      
      // Fallback for old uppercase data during testing
      if (!emailExists) {
        final allUsers = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'client').get();
        for (var doc in allUsers.docs) {
          if ((doc.data()['email'] as String?)?.toLowerCase() == email) {
            emailExists = true;
            break;
          }
        }
        if (!emailExists) {
          final allPending = await FirebaseFirestore.instance.collection('pending_users').get();
          for (var doc in allPending.docs) {
            if ((doc.data()['email'] as String?)?.toLowerCase() == email) {
              emailExists = true;
              break;
            }
          }
        }
      }

      if (emailExists) {
        setState(() => _isLoading = false);
        _showModernSnackBar('Email is already registered. Please sign in.', isError: false);
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
      _showModernSnackBar('err_connection'.tr(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
      child: Scaffold(
        body: Stack(
          children: [
            // OPTIMIZATION: RepaintBoundary prevents this background from repainting during animations
            RepaintBoundary(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF003DD0), // Deep blue at the top
                      Color(0xFF1C75F9), // Lighter medium blue in the middle
                      Color(0xFFE6EFFF), // Icy light white-blue at the bottom
                    ],
                    stops: [0.0, 0.45, 1.0], // Controls the smooth fade
                  ),
                ),
              ),
            ),

            // --- ENTRANCE FADE + SLIDE WRAPPER ---
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SafeArea(
                  // OPTIMIZATION: Replaced IntrinsicHeight + LayoutBuilder with CustomScrollView + SliverFillRemaining
                  // This is vastly faster and smoother for rendering screen-filling forms.
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // --- ORIGINAL LOGO ---
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
                                    'sign_up_to_joe'.tr(),
                                    style: GoogleFonts.workSans(
                                      fontSize: 28,
                                      fontWeight:
                                          FontWeight.w700, // Reduced from w900
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
                                        Color(0xFFBB0013),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'V',
                                    style: GoogleFonts.workSans(
                                      fontSize: 28,
                                      fontWeight:
                                          FontWeight.w700, // Reduced from w900
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'register_subtitle'.tr(),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // --- Smooth Input Fields (Glassmorphic) ---
                              _AnimatedInputField(
                                label: 'name_label'.tr(),
                                hint: 'name_hint'.tr(),
                                icon: Icons.person_outline,
                                controller: _nameController,
                                error: _nameError,
                              ),
                              const SizedBox(height: 20),

                              _AnimatedInputField(
                                label: 'email_label'.tr(),
                                hint: 'email_hint'.tr(),
                                icon: Icons.email_outlined,
                                controller: _emailController,
                                error: _emailError,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20),

                              _AnimatedInputField(
                                label: 'phone_label'.tr(),
                                hint: 'phone_hint'.tr(),
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

                              // OPTIMIZATION: Using isolated _BouncingButton
                              // Prevents full page rebuilds when user just taps the button
                              _BouncingButton(
                                onTap: _isLoading ? null : _handleSignUp,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleSignUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFBB0013),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
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
                                              child: CustomLoadingIndicator(),
                                            )
                                          : Row(
                                              key: const ValueKey('label'),
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'sign_up_btn'.tr(),
                                                  style: GoogleFonts.workSans(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // --- Footer ---
                              // CHANGED: Dark colors because bottom background is very light
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 40.0,
                                  top: 20.0,
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'already_have_account'.tr(),
                                      style: GoogleFonts.workSans(
                                        color: const Color(
                                          0xFF333333,
                                        ), // Dark grey
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen(),
                                        ),
                                      ),
                                      child: Text(
                                        'sign_in_link_dot'.tr(),
                                        style: GoogleFonts.workSans(
                                          color: const Color(
                                            0xFF003DD0,
                                          ), // Deep blue
                                          fontWeight: FontWeight.w800,
                                          decoration: TextDecoration.underline,
                                          decorationColor: const Color(
                                            0xFF003DD0,
                                          ),
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// DEDICATED WIDGET FOR PERFORMANCE: ANIMATED BOUNCING BUTTON
// By isolating this, tapping buttons no longer rebuilds the entire screen!
// ===================================================================
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BouncingButton({required this.child, required this.onTap});

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100), // Very fast response
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ===================================================================
// DEDICATED WIDGET FOR BUTTERY SMOOTH INPUT FIELD TRANSITIONS
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
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          style: GoogleFonts.poppins(
            color: _isFocused ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        AnimatedScale(
          scale: _isFocused ? 1.01 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutQuart,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
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
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
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
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    widget.error!,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF5252),
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
