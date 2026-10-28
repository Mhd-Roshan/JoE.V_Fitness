import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_wrapper.dart';

class OtpScreen extends StatefulWidget {
  final bool isSignUp;
  final String phone; // E.164 format, e.g. +919876543210
  final String? name;
  final String? email;
  final OAuthCredential? credentialToLink;

  const OtpScreen({
    super.key,
    required this.phone,
    this.isSignUp = false,
    this.name,
    this.email,
    this.credentialToLink,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  // Only 1 controller and 1 focus node needed for robust autofill
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _timerSeconds = 42;
  Timer? _timer;

  bool _isLoading = false;
  bool _isVerifying = false; // Prevents multiple API requests
  bool _codeSent = false;
  String _verificationId = "";
  int? _resendToken;

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
      if (!mounted) return;
      _animController.forward();
      // Open the keyboard (after the entrance animation has started) so the
      // OTP suggestion from the incoming SMS can be autofilled in one tap.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && !_isVerifying) _focusNode.requestFocus();
      });
    });

    // Add focus listeners for smooth box highlights without setState
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

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
    debugPrint("📱 [OTP] Initiating phone verification for: ${widget.phone}");
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint("📱 [OTP] Auto-verification completed by Android");
          if (_isVerifying) return;
          final String? autoCode = credential.smsCode;
          final bool hasCode = autoCode != null && autoCode.length == 6;
          if (mounted) {
            // Fill the boxes with the received code (like Zomato) instead of
            // signing in silently with empty boxes.
            if (hasCode) {
              _otpController.value = TextEditingValue(
                text: autoCode,
                selection: TextSelection.collapsed(offset: autoCode.length),
              );
              _focusNode.unfocus();
              HapticFeedback.lightImpact();
            }
            setState(() {
              _isVerifying = true;
              _isLoading = true;
            });
          }
          // Brief pause so the user sees the code land in the boxes.
          if (hasCode) await Future.delayed(const Duration(milliseconds: 400));
          await _signIn(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("❌ [OTP] Verification failed: [${e.code}] ${e.message}");
          if (!mounted) return;
          _showModernSnackBar(
            e.message != null
                ? "${e.message} (${e.code})"
                : "Verification failed (${e.code})",
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint(
            "✅ [OTP] SMS code dispatched. Verification ID: $verificationId",
          );
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
            "⏰ [OTP] Auto-retrieval timeout. Verification ID: $verificationId",
          );
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint("❌ [OTP] Unexpected exception in verifyPhoneNumber: $e");
      if (!mounted) return;
      _showModernSnackBar("Error sending OTP: $e");
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return; // Block rapid double-taps

    final otp = _otpController.text.trim();

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

      if (widget.credentialToLink != null) {
        try {
          await userCredential.user!.linkWithCredential(widget.credentialToLink!);
        } catch (e) {
          debugPrint('Failed to link credential: $e');
        }
      }

      final uid = userCredential.user!.uid;

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      final userDoc = await userDocRef.get();

      // The notification service may already have created users/{uid} with just
      // an FCM token, so a missing role also means the profile isn't set up yet.
      final bool needsSetup =
          !userDoc.exists || (userDoc.data()?['role'] == null);

      if (needsSetup) {
        // Check if this phone number already exists under another login (e.g. Google)
        final lookup = await FirebaseFunctions.instance
            .httpsCallable('lookupAccount')
            .call(<String, dynamic>{'phone': widget.phone});
        final Map<String, dynamic> found =
            Map<String, dynamic>.from(lookup.data as Map);
        final dynamic existingInfo = found['userByPhoneInfo'];

        if (found['userByPhone'] == true &&
            existingInfo is Map &&
            existingInfo['uid'] != uid) {
          // They already have an account with this phone under a different UID (Google)!
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showModernSnackBar('Phone registered via Google. Please use Google Login.', isError: true);
          setState(() {
            _isLoading = false;
            _isVerifying = false;
          });
          return;
        }

        String savedName = widget.name ?? '';
        String savedEmail = widget.email ?? '';

        // The server returns (and removes) the details saved at sign up.
        try {
          final pending = await FirebaseFunctions.instance
              .httpsCallable('consumePending')
              .call();
          final Map<String, dynamic> p =
              Map<String, dynamic>.from(pending.data as Map);
          if ((p['name'] ?? '').toString().isNotEmpty) {
            savedName = p['name'];
          }
          if ((p['email'] ?? '').toString().isNotEmpty) {
            savedEmail = p['email'];
          }
        } catch (e) {
          debugPrint('consumePending failed: $e');
        }

        // Last fallback so the dashboard never has to show "Athlete"
        if (savedName.isEmpty) {
          savedName = userCredential.user?.displayName ?? '';
        }


        await userDocRef.set({
          'role': 'client',
          'authProvider': 'phone',
          'fullName': savedName,
          'email': savedEmail.toLowerCase(),
          'phone': widget.phone,
          'assessmentCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (savedName.isNotEmpty) {
          try {
            await FirebaseAuth.instance.currentUser?.updateDisplayName(savedName);
          } catch (e) {
            debugPrint('Failed to update auth display name: $e');
          }
        }
      }

      // Give the UI thread 50ms to render the success state/ripple
      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a, b) => const AuthWrapper(),
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
    _otpController.clear();
    _focusNode.requestFocus();
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
    _otpController.dispose();
    _focusNode.dispose();
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
                bottom: false,
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
                            AnimatedBuilder(
                              animation: Listenable.merge([_otpController, _focusNode]),
                              builder: (context, child) {
                                final text = _otpController.text;
                                return Stack(
                                  children: [
                                    // Visual Boxes
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(6, (index) {
                                        bool isFocused = _focusNode.hasFocus &&
                                            (text.length == index ||
                                                (text.length == 6 && index == 5));
                                        
                                        String digit = '';
                                        if (index < text.length) {
                                          digit = text[index];
                                        }

                                        return GestureDetector(
                                          onTap: () => _focusNode.requestFocus(),
                                          child: AnimatedScale(
                                            scale: isFocused ? 1.05 : 1.0,
                                            duration: const Duration(milliseconds: 150),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  curve: Curves.easeOutCubic,
                                                  width: 48,
                                                  height: 56,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: isFocused
                                                        ? Colors.black.withValues(alpha: 0.4)
                                                        : Colors.black.withValues(alpha: 0.25),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: isFocused
                                                          ? Colors.white.withValues(alpha: 0.6)
                                                          : Colors.white.withValues(alpha: 0.15),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    digit,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    // Hidden TextField for perfect native Autofill
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.0,
                                        child: TextField(
                                          controller: _otpController,
                                          focusNode: _focusNode,
                                          keyboardType: TextInputType.number,
                                          autofillHints: const [AutofillHints.oneTimeCode],
                                          maxLength: 6,
                                          showCursor: false,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          decoration: const InputDecoration(counterText: ""),
                                          onChanged: (val) {
                                            if (val.length == 6) {
                                              FocusScope.of(context).unfocus();
                                              _verifyOtp();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
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
                                            child: CustomLoadingIndicator(),
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
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
