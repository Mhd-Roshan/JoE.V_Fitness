import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

import 'sign_up_screen.dart';
import 'otp_screen.dart';
import '../auth_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  // Animation controllers
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Slightly faster duration for snappier feel
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  void _showNoAccountPrompt() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
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
                          color: const Color(0xFFE67E22).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_search_outlined,
                          color: Color(0xFFE67E22),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'account_not_found_title'.tr(),
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
                        'account_not_found_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "cancel_btn".tr(),
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
                                      builder: (context) =>
                                          const SignUpScreen(),
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
                                  'sign_up_btn'.tr(),
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignIn() async {
    final input = _phoneController.text.trim();

    if (input.isEmpty) {
      setState(() => _errorText = 'err_enter_phone'.tr());
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
          _errorText = 'err_valid_phone'.tr();
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
        _showNoAccountPrompt();
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
      _showModernSnackBar('err_verify_account'.tr(), isError: true);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut().catchError((_) => null);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
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

        final emailToCheck = user.email?.toLowerCase() ?? '';

        // Check if this email already exists under a Phone UID
        var existingUserByEmail = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: emailToCheck)
            .where('role', isEqualTo: 'client')
            .limit(1)
            .get();

        DocumentSnapshot? conflictingDoc;
        
        if (existingUserByEmail.docs.isNotEmpty) {
           final firstDoc = existingUserByEmail.docs.first;
           if (firstDoc.id != user.uid) {
             conflictingDoc = firstDoc;
           }
        } else {
           // Fallback for old uppercase data during testing
           final allUsers = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'client')
                .get();
           for (var doc in allUsers.docs) {
              final dbEmail = (doc.data()['email'] as String?)?.toLowerCase() ?? '';
              if (dbEmail == emailToCheck && doc.id != user.uid) {
                 conflictingDoc = doc;
                 break;
              }
           }
        }

        if (conflictingDoc != null) {
          final data = conflictingDoc.data() as Map<String, dynamic>;
          final provider = data['authProvider'] ?? 'phone';
          
          if (provider == 'phone') {
            await user.delete();
            await FirebaseAuth.instance.signOut();
            
            // Clean up the empty Google doc if it exists
            if (userDoc.exists) {
               await userDocRef.delete();
            }

            if (!mounted) return;
            setState(() => _isLoading = false);
            _showModernSnackBar('Link Google Account by verifying your Phone', isError: false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpScreen(
                  phone: data['phone'] ?? '',
                  isSignUp: false,
                  credentialToLink: credential,
                ),
              ),
            );
            return;
          } else {
            // It's an orphaned Google Auth doc from testing. We should delete it so we can recreate it under the new UID.
            await FirebaseFirestore.instance.collection('users').doc(conflictingDoc.id).delete();
          }
        }

        if (!userDoc.exists) {

          // Check if there is a pending user with this email
          var pendingUserQuery = await FirebaseFirestore.instance
              .collection('pending_users')
              .where('email', isEqualTo: emailToCheck)
              .limit(1)
              .get();

          String name = user.displayName ?? '';
          String phone = user.phoneNumber ?? '';

          if (pendingUserQuery.docs.isNotEmpty) {
             final pendingData = pendingUserQuery.docs.first.data();
             name = pendingData['name'] ?? name;
             phone = pendingData['phone'] ?? phone;
             // delete pending doc
             await FirebaseFirestore.instance.collection('pending_users').doc(pendingUserQuery.docs.first.id).delete();
          } else {
             // Fallback for old uppercase pending data
             final allPending = await FirebaseFirestore.instance.collection('pending_users').get();
             for (var doc in allPending.docs) {
                final dbEmail = (doc.data()['email'] as String?)?.toLowerCase() ?? '';
                if (dbEmail == emailToCheck) {
                   final pendingData = doc.data();
                   name = pendingData['name'] ?? name;
                   phone = pendingData['phone'] ?? phone;
                   await FirebaseFirestore.instance.collection('pending_users').doc(doc.id).delete();
                   break;
                }
             }
          }

          await userDocRef.set({
            'role': 'client',
            'authProvider': 'google',
            'fullName': name,
            'email': emailToCheck,
            'phone': phone,
            'assessmentCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar(
        'google_signin_failed'.tr(namedArgs: {'error': e.toString()}),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // OPTIMIZATION: RepaintBoundary prevents this gradient from repainting during animations
          RepaintBoundary(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF003DD0),
                    Color(0xFF1C75F9),
                    Color(0xFFE6EFFF),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

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

                            // Back Button
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

                            // Logo
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

                            // Title & Subtitle
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'sign_in_to_joe'.tr(),
                                  style: GoogleFonts.workSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
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
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'login_subtitle'.tr(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Input Field
                            _AnimatedInputField(
                              label: 'phone_label'.tr(),
                              hint: 'phone_hint'.tr(),
                              icon: Icons.phone_outlined,
                              controller: _phoneController,
                              error: _errorText,
                              keyboardType: TextInputType.phone,
                              isPhone: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // OPTIMIZATION: Using isolated _BouncingButton
                            // Prevents full page rebuilds when user just taps the button
                            _BouncingButton(
                              onTap: _isLoading ? null : _handleSignIn,
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFBB0013),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _isLoading
                                        ? const SizedBox(
                                            key: ValueKey('loader'),
                                            width: 24,
                                            height: 24,
                                            child: CustomLoadingIndicator(),
                                          )
                                        : Text(
                                            'sign_in_btn'.tr(),
                                            key: const ValueKey('label'),
                                            style: GoogleFonts.workSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(
                                    color: Colors.white24,
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'or_login_with'.tr(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(
                                    color: Colors.white24,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // Google Button
                            _BouncingButton(
                              onTap: _isLoading ? null : _signInWithGoogle,
                              scaleFactor: 0.92,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Container(
                                    width: 90,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Footer
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 40.0,
                                top: 20,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "dont_have_account".tr(),
                                    style: GoogleFonts.workSans(
                                      color: const Color(0xFF333333),
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
                                            const SignUpScreen(),
                                      ),
                                    ),
                                    child: Text(
                                      "register_link".tr(),
                                      style: GoogleFonts.workSans(
                                        color: const Color(0xFF003DD0),
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(
                                          0xFF003DD0,
                                        ),
                                        fontWeight: FontWeight.w800,
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
  final double scaleFactor;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.96,
  });

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
        scale: _isPressed ? widget.scaleFactor : 1.0,
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
