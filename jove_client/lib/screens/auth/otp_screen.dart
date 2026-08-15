import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_background.dart';
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

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _timerSeconds = 42;
  Timer? _timer;
  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = "";

  @override
  void initState() {
    super.initState();
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
        await _signIn(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        _showMessage(e.message ?? "Verification failed. Please try again.");
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
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length < 6) {
      _showMessage("Please enter the complete code.");
      return;
    }
    if (_verificationId.isEmpty) {
      _showMessage("Still sending code, please wait a moment and try again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await _signIn(credential);
    } catch (e) {
      if (!mounted) return;
      _showMessage("Invalid code. Please try again.");
      _clearOtpFields();
      setState(() => _isLoading = false);
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

          await FirebaseFirestore.instance
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

      // ✅ FIX: Strict linter compliance using State's 'mounted' property.
      if (!mounted) return;

      if (!hasCompletedAssessment) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentScreen()),
          (route) => false,
        );
      } else if (assignedTrainerId == null || assignedTrainerId.isEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SelectTrainerScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage("Sign in failed. Please try again.");
      setState(() => _isLoading = false);
    }
  }

  void _handleResend() {
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

  void _showMessage(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter the Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _codeSent
                            ? 'Sent to ${widget.phone}. '
                            : 'Sending to ${widget.phone}... ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: Color(0xFF01BCE3),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF01BCE3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 58,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00225D),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: const Color(0xFFF4F4F4),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF01BCE3),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF01BCE3),
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }

                          if (value.isNotEmpty && index == 5) {
                            FocusScope.of(context).unfocus();

                            Future.delayed(
                              const Duration(milliseconds: 50),
                              () {
                                if (mounted) {
                                  _verifyOtp();
                                }
                              },
                            );
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                Center(
                  child: _timerSeconds > 0
                      ? Text(
                          'Resend code in 0:${_timerSeconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : GestureDetector(
                          onTap: _handleResend,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(
                              color: Color(0xFF01BCE3),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBB0013),
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
                                'Verify',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
