import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_background.dart';
import 'login_screen.dart';
import 'assessment_screen.dart';

class OtpScreen extends StatefulWidget {
  final bool isSignUp;
  final String phone;
  final String? name;
  final String? email;
  final bool isEmailLogin;

  const OtpScreen({
    super.key,
    required this.phone,
    this.isSignUp = false,
    this.name,
    this.email,
    this.isEmailLogin = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // CHANGED: Generating 6 controllers instead of 4
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  // CHANGED: Generating 6 focus nodes instead of 4
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _timerSeconds = 42;
  Timer? _timer;
  bool _isLoading = false;

  // For Phone SMS
  String _verificationId = "";

  // For Email OTP
  String? _generatedEmailOtp;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (widget.isEmailLogin) {
      _sendEmailOtp();
    } else {
      _verifyPhone();
    }
  }

  void _startTimer() {
    setState(() => _timerSeconds = 42);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  // ══════════════════════════════════════
  // PHONE SMS - FIREBASE
  // ══════════════════════════════════════
  Future<void> _verifyPhone() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithPhone(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        _showMessage(e.message ?? "Verification Failed", isError: true);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _verificationId = verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ══════════════════════════════════════
  // EMAIL OTP - SIMULATED
  // ══════════════════════════════════════
  Future<void> _sendEmailOtp() async {
    final random = Random();
    // CHANGED: Generates a 6-digit code for testing (e.g. 482910)
    _generatedEmailOtp = (100000 + random.nextInt(900000)).toString();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Show OTP in snackbar for testing - REMOVE IN PRODUCTION
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📧 [TEST ONLY] OTP: $_generatedEmailOtp',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ══════════════════════════════════════
  // VERIFY OTP - Handles Both Modes
  // ══════════════════════════════════════
  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    // CHANGED: Must be 6 digits now
    if (otp.length < 6) {
      _showMessage("Please enter the complete 6-digit code.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isEmailLogin) {
      // ── EMAIL OTP VERIFY ──
      if (otp == _generatedEmailOtp) {
        try {
          UserCredential userCredential;
          try {
            userCredential = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
                  email: widget.email ?? widget.phone,
                  password: "JoEV_Secure_Password_123!",
                );
          } catch (e) {
            userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                  email: widget.email ?? widget.phone,
                  password: "JoEV_Secure_Password_123!",
                );
          }
          _showMessage("✅ Email Verified!", isError: false);
          await _checkAssessmentAndNavigate(userCredential);
        } catch (e) {
          _showMessage("Firebase Error. Try again.", isError: true);
          setState(() => _isLoading = false);
        }
      } else {
        _showMessage("❌ Incorrect OTP. Please try again.", isError: true);
        for (final c in _otpControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        setState(() => _isLoading = false);
      }
    } else {
      // ── PHONE SMS VERIFY (Firebase) ──
      try {
        final PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: otp,
        );
        await _signInWithPhone(credential);
      } catch (e) {
        _showMessage("Invalid Code. Please try again.", isError: true);
        setState(() => _isLoading = false);
        // Clear boxes on failure
        for (final c in _otpControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  // ══════════════════════════════════════
  // FIREBASE PHONE SIGN IN
  // ══════════════════════════════════════
  Future<void> _signInWithPhone(PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (mounted) {
        _showMessage("✅ Successfully Verified!", isError: false);
        await _checkAssessmentAndNavigate(userCredential);
      }
    } catch (e) {
      _showMessage("Sign in failed. Try again.", isError: true);
      setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════
  // NAVIGATE TO ASSESSMENT OR HOME
  // ══════════════════════════════════════
  Future<void> _checkAssessmentAndNavigate(
    UserCredential userCredential,
  ) async {
    if (widget.isSignUp && userCredential.user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': widget.name ?? '',
            'email': widget.email ?? '',
            'phone': widget.isEmailLogin ? '' : widget.phone,
            'assessmentCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();
    bool hasCompleted = false;
    if (userDoc.exists && userDoc.data() != null) {
      hasCompleted =
          (userDoc.data() as Map<String, dynamic>)['assessmentCompleted'] ??
          false;
    }

    if (mounted) {
      if (hasCompleted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showMessage(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ══════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final String displayTarget = widget.isEmailLogin
        ? (widget.email ?? 'your email')
        : widget.phone;

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
            ), // Slightly reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ── Icon Box ──
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2FA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Icon(
                      widget.isEmailLogin
                          ? Icons.mark_email_read_outlined
                          : Icons.chat_bubble_outline,
                      color: const Color(0xFF1E3A8A),
                      size: 45,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ── Title ──
                const Text(
                  'Enter the Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Subtitle ──
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Sent to $displayTarget. ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: Color(0xFF00CBE6),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // ── 6 OTP Boxes ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  // CHANGED: Building 6 boxes
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48, // CHANGED: Smaller width to fit 6 boxes
                      height: 55, // CHANGED: Smaller height
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 26, // Smaller font for smaller box
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            counterText: "",
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            // CHANGED: Navigation logic for 6 boxes
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }

                            // Auto-submit if all 6 are filled!
                            if (value.isNotEmpty && index == 5) {
                              FocusScope.of(context).unfocus();
                              _verifyOTP(); // Automatically trigger verify
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),

                // ── Timer / Resend ──
                _timerSeconds > 0
                    ? Row(
                        children: [
                          const Text(
                            'Resend code in ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '0:${_timerSeconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Color(0xFF00CBE6),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () {
                          _startTimer();
                          if (widget.isEmailLogin) {
                            _sendEmailOtp();
                          } else {
                            _verifyPhone();
                          }
                        },
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(
                            color: Color(0xFF00CBE6),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                const SizedBox(height: 40),

                // ── Verify Button ──
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBA0C19),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Verify',
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
