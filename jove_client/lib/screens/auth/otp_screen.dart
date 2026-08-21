import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'assessment_screen.dart';
import '../trainer_selection_screen.dart';
import '../home_dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final bool isSignUp;
  final String phone; // E.164 format, e.g. +919876543210
  final String? name;
  final String? email;

  const OtpScreen({
    super.key,
    required this.phone,
    this.isSignUp = false,
    this.name,
    this.email,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _timerSeconds = 42;
  Timer? _timer;

  bool _isLoading = false;
  bool _isVerifying = false; // Prevents multiple API requests
  bool _codeSent = false;
  String _verificationId = "";

  // Animations
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // OPTIMIZATION: Using ValueNotifier prevents full-screen rebuilds on keystrokes
  final ValueNotifier<int> _focusedIndexNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    // OPTIMIZATION: Snappy 600ms duration with fluid curves
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
    });

    // Add focus listeners for smooth box highlights without setState
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus && mounted) {
          _focusedIndexNotifier.value = i;
        }
      });
    }

    _startTimer();
    _sendOtp();
  }

  void _startTimer() {
    setState(() => _timerSeconds = 42);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatically signs in if Android resolves it instantly
        await _signIn(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        _showModernSnackBar(
          e.message ?? "Verification failed. Please try again.",
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return; // Block rapid double-taps

    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length < 6) {
      _showModernSnackBar("Please enter the complete 6-digit code.");
      return;
    }
    if (_verificationId.isEmpty) {
      _showModernSnackBar(
        "Still sending code, please wait a moment and try again.",
        isError: false,
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isVerifying = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await _signIn(credential);
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar("Invalid code. Please try again.");
      _clearOtpFields();
      setState(() {
        _isLoading = false;
        _isVerifying = false;
      });
    }
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final uid = userCredential.user!.uid;

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        final pendingDoc = await FirebaseFirestore.instance
            .collection('pending_users')
            .doc(widget.phone)
            .get();

        String savedName = widget.name ?? '';
        String savedEmail = widget.email ?? '';

        if (pendingDoc.exists) {
          savedName = pendingDoc.data()?['name'] ?? savedName;
          savedEmail = pendingDoc.data()?['email'] ?? savedEmail;

          // Process deletion in background so it doesn't block UI thread
          FirebaseFirestore.instance
              .collection('pending_users')
              .doc(widget.phone)
              .delete();
        }

        await userDocRef.set({
          'role': 'client',
          'authProvider': 'phone',
          'fullName': savedName,
          'email': savedEmail,
          'phone': widget.phone,
          'assessmentCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final updatedUserDoc = await userDocRef.get();
      final userData = updatedUserDoc.data() ?? {};

      final bool hasCompletedAssessment =
          userData['assessmentCompleted'] ?? false;
      final String? assignedTrainerId = userData['assignedTrainerId'];

      // Give the UI thread 50ms to render the success state/ripple
      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;

      Widget nextScreen;
      if (!hasCompletedAssessment) {
        nextScreen = const AssessmentScreen();
      } else if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
        nextScreen = const SelectTrainerScreen();
      } else {
        nextScreen = const HomeDashboardScreen();
      }

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a, b) => nextScreen,
          transitionsBuilder: (context, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar("Sign in failed. Please try again.");
      setState(() {
        _isLoading = false;
        _isVerifying = false;
      });
    }
  }

  void _handleResend() {
    HapticFeedback.mediumImpact();
    _startTimer();
    _clearOtpFields();
    setState(() => _codeSent = false);
    _sendOtp();
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showModernSnackBar(String message, {bool isError = true}) {
    HapticFeedback.heavyImpact();
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
            : const Color(0xFF00CBE6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _focusedIndexNotifier.dispose();
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // OPTIMIZATION: RepaintBoundary prevents background repainting during animations
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
                // OPTIMIZATION: CustomScrollView + SliverFillRemaining
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
                                          alpha: 0.15,
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
                                        HapticFeedback.lightImpact();
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // --- CENTERED LOGO ---
                            Image.asset(
                              'assets/images/landing_photo.png',
                              height: 80,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.bolt,
                                  size: 80,
                                  color: Colors.white,
                                );
                              },
                            ),

                            const SizedBox(height: 50),

                            // --- TITLE ---
                            Text(
                              'OTP Verification',
                              style: GoogleFonts.workSans(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // --- SUBTITLE ---
                            Text(
                              _codeSent
                                  ? 'Enter the verification code we just sent\non your phone number.'
                                  : 'Sending verification code to\n${widget.phone}...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // --- OTP INPUT ROW (Glassmorphic) ---
                            ValueListenableBuilder<int>(
                              valueListenable: _focusedIndexNotifier,
                              builder: (context, focusedIndex, child) {
                                return AutofillGroup(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(6, (index) {
                                      bool isFocused = focusedIndex == index;

                                      return AnimatedScale(
                                        scale: isFocused ? 1.05 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 8,
                                              sigmaY: 8,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              width: 48,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: isFocused
                                                    ? Colors.black.withValues(
                                                        alpha: 0.4,
                                                      )
                                                    : Colors.black.withValues(
                                                        alpha: 0.25,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isFocused
                                                      ? Colors.white.withValues(
                                                          alpha: 0.6,
                                                        )
                                                      : Colors.white.withValues(
                                                          alpha: 0.15,
                                                        ),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: TextField(
                                                controller:
                                                    _otpControllers[index],
                                                focusNode: _focusNodes[index],
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.center,
                                                maxLength: 1,
                                                cursorColor: Colors.white,
                                                // PERFORMANCE/UX: Autofills code directly from SMS instantly!
                                                autofillHints: const [
                                                  AutofillHints.oneTimeCode,
                                                ],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                decoration:
                                                    const InputDecoration(
                                                      counterText: "",
                                                      border: InputBorder.none,
                                                    ),
                                                onChanged: (value) {
                                                  // Handling full code paste from Autofill
                                                  if (value.length == 6) {
                                                    for (
                                                      int i = 0;
                                                      i < 6;
                                                      i++
                                                    ) {
                                                      _otpControllers[i].text =
                                                          value[i];
                                                    }
                                                    FocusScope.of(
                                                      context,
                                                    ).unfocus();
                                                    _verifyOtp();
                                                    return;
                                                  }

                                                  if (value.isNotEmpty &&
                                                      index < 5) {
                                                    _focusNodes[index + 1]
                                                        .requestFocus();
                                                  } else if (value.isEmpty &&
                                                      index > 0) {
                                                    _focusNodes[index - 1]
                                                        .requestFocus();
                                                  }

                                                  // Auto-verify on last digit
                                                  if (value.isNotEmpty &&
                                                      index == 5) {
                                                    FocusScope.of(
                                                      context,
                                                    ).unfocus();
                                                    _verifyOtp();
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 40),

                            // --- VERIFY BUTTON (Isolated to prevent rebuilds) ---
                            _BouncingButton(
                              onTap: _isLoading ? null : _verifyOtp,
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOtp,
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
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            'Verify',
                                            key: const ValueKey('label'),
                                            style: GoogleFonts.workSans(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),

                            // --- FOOTER: RESEND CODE ---
                            // CHANGED: Dark colors because bottom background is very light
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 40,
                                top: 20,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _timerSeconds > 0
                                    ? Text(
                                        'Didn\'t receive code? Resend in ${_timerSeconds}s',
                                        key: const ValueKey('timer'),
                                        style: GoogleFonts.poppins(
                                          color: const Color(
                                            0xFF333333,
                                          ), // Dark grey
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : Row(
                                        key: const ValueKey('resend'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Didn\'t receive code? ',
                                            style: GoogleFonts.poppins(
                                              color: const Color(
                                                0xFF333333,
                                              ), // Dark grey
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _handleResend,
                                            child: Text(
                                              'Resend',
                                              style: GoogleFonts.poppins(
                                                color: const Color(
                                                  0xFF003DD0,
                                                ), // Deep blue
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: const Color(
                                                  0xFF003DD0,
                                                ),
                                              ),
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

  const _BouncingButton({
    required this.child,
    required this.onTap,
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
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
