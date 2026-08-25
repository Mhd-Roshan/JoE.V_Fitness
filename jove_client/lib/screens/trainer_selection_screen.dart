import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'booking_screen.dart';
import '../theme/app_theme_controller.dart';

// ==========================================
// DATA MODEL
// ==========================================
class Trainer {
  final String id;
  final String name;
  final String designation;
  final String imageUrl;
  final double rating;
  final int ratingCount;
  final List<String> specializations;
  final String yearsExperience;
  final String bio;
  final List<String> certifications;

  Trainer({
    required this.id,
    required this.name,
    required this.designation,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.specializations,
    required this.yearsExperience,
    required this.bio,
    required this.certifications,
  });

  factory Trainer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String formattedExperience = "0 ${'years_lowercase'.tr()}";
    if (data['yearsExperience'] != null) {
      formattedExperience =
          "${data['yearsExperience']}+ ${'years_lowercase'.tr()}";
    }

    String rawName = (data['name'] ?? data['fullName'] ?? 'expert_trainer'.tr()).toString().trim();
    if (rawName.isEmpty) rawName = 'Trainer';

    // Check all possible field variations for trainer images in Firestore
    String? rawImg = data['imageUrl'] ??
        data['profileImageUrl'] ??
        data['profilePic'] ??
        data['profilePicture'] ??
        data['photoUrl'] ??
        data['photoURL'] ??
        data['image'] ??
        data['avatar'] ??
        data['picture'];

    String finalImg = '';
    if (rawImg != null &&
        rawImg.toString().trim().isNotEmpty &&
        (rawImg.toString().trim().startsWith('http://') ||
            rawImg.toString().trim().startsWith('https://'))) {
      finalImg = rawImg.toString().trim();
    } else {
      finalImg =
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(rawName)}&background=BA0C19&color=fff&size=256';
    }

    return Trainer(
      id: data['trainerId'] ?? doc.id,
      name: rawName,
      designation: (data['designation'] ?? data['title'] ?? data['role'] ?? 'personal_trainer'.tr()).toString(),
      imageUrl: finalImg,
      rating: ((data['rating'] ?? 5.0) as num).toDouble(),
      ratingCount: (data['ratingCount'] ?? data['reviewsCount'] ?? 0) is int
          ? (data['ratingCount'] ?? data['reviewsCount'] ?? 0)
          : int.tryParse((data['ratingCount'] ?? data['reviewsCount'] ?? 0).toString()) ?? 0,
      specializations: List<String>.from(data['specializations'] ?? data['specialties'] ?? []),
      yearsExperience: formattedExperience,
      bio: (data['bio'] ?? data['description'] ?? data['about'] ?? '').toString(),
      certifications: List<String>.from(data['certifications'] ?? []),
    );
  }
}

// ==========================================
// SCREEN 1: TRAINER LIST
// ==========================================
class SelectTrainerScreen extends StatefulWidget {
  const SelectTrainerScreen({super.key});

  @override
  State<SelectTrainerScreen> createState() => _SelectTrainerScreenState();
}

class _SelectTrainerScreenState extends State<SelectTrainerScreen> {
  // --- NATIVE SCREENSHOT CHANNEL ---
  static const platform = MethodChannel('com.example.jove_client/screenshot');

  Trainer? _selectedTrainer;
  bool _isLoading = false;

  late final Stream<QuerySnapshot> _trainersStream;

  @override
  void initState() {
    super.initState();
    _disableScreenshots(); // Block screenshots natively when screen opens

    _trainersStream = FirebaseFirestore.instance
        .collection('trainers')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  @override
  void dispose() {
    _enableScreenshots(); // Allow screenshots again when leaving this screen
    super.dispose();
  }

  // ==========================================
  // NATIVE SCREENSHOT CONTROLS
  // ==========================================
  Future<void> _disableScreenshots() async {
    try {
      await platform.invokeMethod('disableScreenshots');
    } catch (e) {
      debugPrint("Error disabling screenshots: $e");
    }
  }

  Future<void> _enableScreenshots() async {
    try {
      await platform.invokeMethod('enableScreenshots');
    } catch (e) {
      debugPrint("Error enabling screenshots: $e");
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedTrainer == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final clientName = userDoc.data()?['fullName'] ?? 'A new client';

        final batch = FirebaseFirestore.instance.batch();

        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        batch.update(userRef, {
          'assignedTrainerId': _selectedTrainer!.id,
          'assignedTrainerName': _selectedTrainer!.name,
          'trainerAssignedAt': FieldValue.serverTimestamp(),
        });

        final adminNotifRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        batch.set(adminNotifRef, {
          'targetRole': 'admin',
          'type': 'trainer_assigned',
          'title': 'Trainer Selected',
          'message':
              '$clientName has selected ${_selectedTrainer!.name} as their trainer.',
          'clientId': user.uid,
          'trainerId': _selectedTrainer!.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final trainerNotifRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        batch.set(trainerNotifRef, {
          'targetId': _selectedTrainer!.id,
          'targetRole': 'trainer',
          'type': 'new_client',
          'title': 'New Client Assigned',
          'message': '$clientName has selected you as their personal trainer.',
          'clientId': user.uid,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
      }

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                child: Material(
                  color: Colors.transparent,
                  child: SuccessDialog(trainer: _selectedTrainer!),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_saving_trainer'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              'select_trainers_title'.tr(),
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5F5) : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      "select_trainer_subtitle".tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFA8A8A8) : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B192C) : const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFD0E3FF),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF00225D),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF00225D),
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'note_label'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: 'select_trainer_note'.tr()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _trainersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFBA0C19)),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "no_trainers_available".tr(),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFA8A8A8) : Colors.grey,
                          ),
                        ),
                      );
                    }

                    final trainers = snapshot.data!.docs
                        .map((doc) => Trainer.fromFirestore(doc))
                        .toList();

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: trainers.length,
                      itemBuilder: (context, index) {
                        final trainer = trainers[index];
                        final isSelected = _selectedTrainer?.id == trainer.id;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121212) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.05,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(35),
                                        child: Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFFBA0C19)
                                                  : (isDark
                                                      ? const Color(0xFF262626)
                                                      : Colors.grey.shade300),
                                              width: 2,
                                            ),
                                          ),
                                          child: trainer.imageUrl.isNotEmpty
                                              ? Image.network(
                                                  trainer.imageUrl,
                                                  width: 70,
                                                  height: 70,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stackTrace) {
                                                    return Container(
                                                      color: const Color(0xFFBA0C19),
                                                      alignment: Alignment.center,
                                                      child: Text(
                                                        trainer.name.isNotEmpty
                                                            ? trainer.name[0].toUpperCase()
                                                            : 'T',
                                                        style: const TextStyle(
                                                          fontSize: 26,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  loadingBuilder:
                                                      (context, child, loadingProgress) {
                                                    if (loadingProgress == null) {
                                                      return child;
                                                    }
                                                    return Container(
                                                      color: isDark
                                                          ? const Color(0xFF1E293B)
                                                          : const Color(0xFFF1F5F9),
                                                      alignment: Alignment.center,
                                                      child: const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Color(0xFFBA0C19),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: const Color(0xFFBA0C19),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    trainer.name.isNotEmpty
                                                        ? trainer.name[0].toUpperCase()
                                                        : 'T',
                                                    style: const TextStyle(
                                                      fontSize: 26,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            trainer.rating.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFFF5F5F5) : Colors.black,
                                            ),
                                          ),
                                          Text(
                                            ' (${trainer.ratingCount})',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trainer.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFFF5F5F5) : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          trainer.designation,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: trainer.specializations
                                              .take(3)
                                              .map(
                                                (s) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? const Color(0xFF1E293B)
                                                        : const Color(0xFFE5F1FF),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    s,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(0xFF60A5FA)
                                                          : const Color(0xFF0044FF),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _BouncingButton(
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    final selected = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrainerProfileScreen(
                                          trainer: trainer,
                                        ),
                                      ),
                                    );
                                    if (selected == true) {
                                      setState(
                                        () => _selectedTrainer = trainer,
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'view_details'.tr(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF00225D),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _BouncingButton(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedTrainer = trainer);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFD6D9)
                                          : const Color(0xFFBA0C19),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isSelected
                                          ? 'selected'.tr()
                                          : 'select_trainer_btn'.tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isSelected
                                            ? const Color(0xFFBA0C19)
                                            : Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedTrainer != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _BouncingButton(
                  onTap: _isLoading ? null : _confirmSelection,
                  child: SizedBox(
                    height: 55,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA0C19),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${'continue_btn'.tr()} ',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
      },
    );
  }
}

// ==========================================
// SCREEN 2: TRAINER PROFILE (REDESIGNED MATCHING SCREENSHOT)
// ==========================================
class TrainerProfileScreen extends StatelessWidget {
  final Trainer trainer;

  const TrainerProfileScreen({super.key, required this.trainer});

  @override
  Widget build(BuildContext context) {
    // Design Colors based on Screenshot
    const Color badgeRed = Color(0xFFC8102E);
    const Color darkNavy = Color(0xFF0F172A);
    const Color lightPill = Color(0xFFF1F5F9);
    const Color textGrey = Color(0xFF475569);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO IMAGE WITH OVERLAY
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 480, // Tall header like the design
                      child: Image.network(
                        trainer.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF0F172A),
                                  Color(0xFF1E293B),
                                  Color(0xFFBA0C19),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.15),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        trainer.name.isNotEmpty
                                            ? trainer.name[0].toUpperCase()
                                            : 'T',
                                        style: const TextStyle(
                                          fontSize: 52,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF0F172A),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFBA0C19),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Gradient overlay at bottom of image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 250,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              darkNavy.withValues(alpha: 0.95),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Trainer Name and Badge
                    Positioned(
                      bottom: 55, // Leaves space for the overlapping stats
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Red Designation Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              trainer.designation.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Trainer Name
                          Text(
                            trainer.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2. OVERLAPPING STATS ROW
                Transform.translate(
                  offset: const Offset(
                    0,
                    -25,
                  ), // Pulls the row up over the image
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statBox(
                            darkNavy,
                            'EXPERIENCE',
                            trainer.yearsExperience,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statBox(
                            darkNavy,
                            'REVIEWS',
                            '${trainer.ratingCount}+',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statBox(
                            darkNavy,
                            'RATING',
                            '${trainer.rating} ⭐',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. BODY CONTENT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ABOUT SECTION
                      _sectionTitle(badgeRed, darkNavy, 'ABOUT'),
                      const SizedBox(height: 12),
                      Text(
                        trainer.bio.isEmpty
                            ? "no_bio_provided".tr()
                            : trainer.bio,
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // SPECIALTIES SECTION
                      if (trainer.specializations.isNotEmpty) ...[
                        _sectionTitle(badgeRed, darkNavy, 'SPECIALTIES'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: trainer.specializations
                              .map((s) => _pillBadge(lightPill, darkNavy, s))
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // CERTIFICATIONS SECTION
                      if (trainer.certifications.isNotEmpty) ...[
                        _sectionTitle(badgeRed, darkNavy, 'CERTIFICATIONS'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: trainer.certifications
                              .map((c) => _pillBadge(lightPill, darkNavy, c))
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Padding for bottom button
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FLOATING BACK BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: _BouncingButton(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // BOTTOM SELECTION BUTTON
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: _BouncingButton(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, true);
          },
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'select_trainer_btn'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET: Overlapping Stat Box
  Widget _statBox(Color bgColor, String title, String value) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Section Title with Red Line
  Widget _sectionTitle(Color lineColor, Color textColor, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // WIDGET: Light Grey Pill Badges
  Widget _pillBadge(Color bgColor, Color textColor, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 3: SUCCESS DIALOG COMPONENT
// ==========================================
class SuccessDialog extends StatelessWidget {
  final Trainer trainer;

  const SuccessDialog({super.key, required this.trainer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
      ),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WAVY GREEN CHECKMARK BADGE
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFF6C2),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                Transform.rotate(
                  angle: 3.14159 / 4,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFF6C2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                const Icon(Icons.check, color: Color(0xFF0C5618), size: 45),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'successful_title'.tr(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'trainer_selected_success_msg'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 48),

          _BouncingButton(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => BookingScreen(trainer: trainer),
                ),
                (Route<dynamic> route) => route.isFirst,
              );
            },
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => BookingScreen(trainer: trainer),
                    ),
                    (Route<dynamic> route) => route.isFirst,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBB0013),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'done_btn'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DEDICATED WIDGET FOR PERFORMANCE: ANIMATED BOUNCING BUTTON
// ==========================================
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
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
