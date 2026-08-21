import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

// IMPORTANT: IMPORT YOUR NEW PACKAGE SCREEN HERE
import 'package_select_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 7 pages for the Assessment
  final int _totalPages = 7;
  bool _isLoading = false;

  // --- Assessment Data State ---
  final List<String> _selectedGoals = [];
  String _selectedGender = '';
  int _age = 20;
  double _weight = 62;
  bool _isKg = true;
  double _height = 175;
  bool _isCm = true;
  final List<String> _medicalConditions = [];
  final List<String> _physicalConstraints = [];

  // Firebase Stream for Goals
  late Stream<QuerySnapshot> _availableGoalsStream;

  static const List<String> _defaultGoals = [
    'Muscle building',
    'Weight loss',
    'Medical recovery',
    'Lifestyle improvement',
    'Stress reduction & Balance',
  ];

  @override
  void initState() {
    super.initState();
    _availableGoalsStream = FirebaseFirestore.instance
        .collection('fitness_goals')
        .snapshots();
    _checkAndSeedGoals();
  }

  Future<void> _checkAndSeedGoals() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fitness_goals')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var goal in _defaultGoals) {
          final docRef = FirebaseFirestore.instance
              .collection('fitness_goals')
              .doc();
          batch.set(docRef, {
            'title': goal,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error seeding goals: $e");
    }
  }

  IconData _getIconForGoal(String title) {
    String lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('muscle') || lowerTitle.contains('strength')) {
      return Icons.fitness_center_rounded;
    }
    if (lowerTitle.contains('weight') || lowerTitle.contains('fat')) {
      return Icons.monitor_weight_outlined;
    }
    if (lowerTitle.contains('medical') ||
        lowerTitle.contains('injury') ||
        lowerTitle.contains('recovery')) {
      return Icons.medical_services_outlined;
    }
    if (lowerTitle.contains('lifestyle') || lowerTitle.contains('health')) {
      return Icons.self_improvement_rounded;
    }
    if (lowerTitle.contains('stress') || lowerTitle.contains('balance')) {
      return Icons.directions_run_rounded;
    }
    if (lowerTitle.contains('cardio') || lowerTitle.contains('stamina')) {
      return Icons.favorite_border_rounded;
    }
    return Icons.track_changes_rounded;
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFBB0013),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage == 0 && _selectedGoals.isEmpty) {
      _showError('err_select_goal'.tr());
      return;
    }
    if (_currentPage == 1 && _selectedGender.isEmpty) {
      _showError('err_select_gender'.tr());
      return;
    }
    if (_currentPage == 5 && _medicalConditions.isEmpty) {
      _showError('err_medical_condition'.tr());
      return;
    }
    if (_currentPage == 6 && _physicalConstraints.isEmpty) {
      _showError('err_physical_constraint'.tr());
      return;
    }

    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _saveAssessmentAndGoToPackages();
    }
  }

  void _skipPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _saveAssessmentAndGoToPackages();
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveAssessmentAndGoToPackages() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'goals': _selectedGoals,
          'gender': _selectedGender,
          'age': _age,
          'weight': _weight,
          'weightUnit': _isKg ? 'kg' : 'lbs',
          'height': _height,
          'heightUnit': _isCm ? 'cm' : 'ft/in',
          'medicalConditions': _medicalConditions,
          'physicalConstraints': _physicalConstraints,
          'assessmentCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PackageSelectScreen()),
        );
      }
    } catch (e) {
      _showError('err_save_failed'.tr());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Progress Bar Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: List.generate(_totalPages, (index) {
                  bool isActive = index <= _currentPage;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF003DD0)
                            : const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Assessment Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildGoalPage(),
                  _buildGenderPage(),
                  _buildAgePage(),
                  _buildWeightPage(),
                  _buildHeightPage(),
                  _buildTagsPage(
                    title: 'medical_conditions_title'.tr(),
                    illustration: Icons.medical_services,
                    selectedTags: _medicalConditions,
                    suggestedTags: [
                      'cond_diabetes'.tr(),
                      'cond_asthma'.tr(),
                      'cond_hypertension'.tr(),
                      'cond_thyroid'.tr(),
                    ],
                  ),
                  _buildTagsPage(
                    title: 'physical_constraints_title'.tr(),
                    illustration: Icons.healing,
                    selectedTags: _physicalConstraints,
                    suggestedTags: [
                      'inj_knee'.tr(),
                      'inj_back'.tr(),
                      'inj_shoulder'.tr(),
                      'inj_arthritis'.tr(),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    _BouncingButton(
                      onTap: _prevPage,
                      scaleFactor: 0.9,
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F6),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  if (_currentPage == 5 || _currentPage == 6) ...[
                    TextButton(
                      onPressed: _skipPage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'skip_for_now'.tr(),
                        style: GoogleFonts.workSans(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Continue / View Packages Button
                  Expanded(
                    child: _BouncingButton(
                      onTap: _isLoading ? null : _nextPage,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBB0013),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _currentPage == _totalPages - 1
                                              ? 'view_packages'.tr()
                                              : 'continue_btn'.tr(),
                                          style: GoogleFonts.workSans(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAGE 0: GOALS
  // ==========================================
  Widget _buildGoalPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'What’s your fitness\ngoal?',
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              fontSize: 28,
              fontWeight: FontWeight.w600, // REDUCED BOLDNESS
              color: const Color(0xFF333333),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _availableGoalsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF003DD0)),
                  );
                }

                List<String> goalTitles = [];
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  goalTitles = snapshot.data!.docs
                      .map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        return data['title']?.toString() ?? '';
                      })
                      .where((t) => t.isNotEmpty)
                      .toList();
                }
                if (goalTitles.isEmpty) goalTitles = _defaultGoals;

                return ListView.builder(
                  itemCount: goalTitles.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    String title = goalTitles[index];
                    bool isSelected = _selectedGoals.contains(title);
                    IconData icon = _getIconForGoal(title);

                    // OPTIMIZATION: Bouncing wrapper for smoothness
                    return _BouncingButton(
                      scaleFactor: 0.96,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _selectedGoals.remove(title);
                          } else {
                            _selectedGoals.add(title);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF003DD0)
                              : const Color(0xFFF1F3F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                              size: 24,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.workSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600, // Balanced
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                  width: 1.8,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFF003DD0),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 1: GENDER
  // ==========================================
  Widget _buildGenderPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'gender_title'.tr(),
            style: GoogleFonts.workSans(
              fontSize: 28,
              fontWeight: FontWeight.w600, // REDUCED BOLDNESS
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 40),
          _genderCard(
            gender: 'gender_male'.tr(),
            symbol: '♂',
            imagePath: 'assets/images/male.png',
          ),
          const SizedBox(height: 20),
          _genderCard(
            gender: 'gender_female'.tr(),
            symbol: '♀',
            imagePath: 'assets/images/female.png',
          ),
        ],
      ),
    );
  }

  Widget _genderCard({
    required String gender,
    required String symbol,
    required String imagePath,
  }) {
    bool isSelected = _selectedGender == gender;
    return _BouncingButton(
      scaleFactor: 0.96,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedGender = gender);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 140,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4FAFF) : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF003DD0) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.55,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey.shade300),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      isSelected
                          ? const Color(0xFFF4FAFF)
                          : const Color(0xFFF1F3F6),
                      (isSelected
                              ? const Color(0xFFF4FAFF)
                              : const Color(0xFFF1F3F6))
                          .withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        symbol,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        gender,
                        style: GoogleFonts.workSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600, // Reduced boldness
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black87, width: 2),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: isSelected
                        ? Container(
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAGE 2: AGE
  // ==========================================
  Widget _buildAgePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'What’s your Age?',
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              fontSize: 28,
              fontWeight: FontWeight.w600, // REDUCED BOLDNESS
              color: const Color(0xFF333333),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SizedBox(
                height: 320,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 68,
                  perspective: 0.003,
                  diameterRatio: 1.6,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: (_age - 14).clamp(0, 76),
                  ),
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _age = 14 + index);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 77,
                    builder: (context, index) {
                      int ageVal = 14 + index;
                      bool isSelected = ageVal == _age;

                      if (isSelected) {
                        return Center(
                          child: Container(
                            width: 110,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF003DD0),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF003DD0,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              ageVal.toString(),
                              style: GoogleFonts.workSans(
                                fontSize: 34,
                                fontWeight:
                                    FontWeight.w700, // Kept for emphasis
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }

                      int diff = (ageVal - _age).abs();
                      double opacity = diff == 1
                          ? 0.45
                          : diff == 2
                          ? 0.25
                          : 0.12;

                      return Center(
                        child: Text(
                          ageVal.toString(),
                          style: GoogleFonts.workSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: const Color(
                              0xFF111111,
                            ).withValues(alpha: opacity),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 3: WEIGHT
  // ==========================================
  Widget _buildWeightPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'What’s your current\nweight right now?',
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              fontSize: 28,
              fontWeight: FontWeight.w600, // REDUCED BOLDNESS
              color: const Color(0xFF333333),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _unitToggleButton(
                label: 'Kg',
                isSelected: _isKg,
                onTap: () {
                  if (!_isKg) {
                    setState(() {
                      _isKg = true;
                      _weight = (_weight / 2.20462).roundToDouble().clamp(
                        30,
                        200,
                      );
                    });
                  }
                },
              ),
              const SizedBox(width: 14),
              _unitToggleButton(
                label: 'Lbs',
                isSelected: !_isKg,
                onTap: () {
                  if (_isKg) {
                    setState(() {
                      _isKg = false;
                      _weight = (_weight * 2.20462).roundToDouble().clamp(
                        66,
                        440,
                      );
                    });
                  }
                },
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _weight.toInt().toString(),
                style: GoogleFonts.workSans(
                  fontSize: 56,
                  fontWeight: FontWeight.w700, // Kept thick for numbers
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isKg ? 'Kg' : 'Lbs',
                style: GoogleFonts.workSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _RulerScalePicker(
            key: ValueKey('weight_ruler_$_isKg'),
            minValue: _isKg ? 30 : 66,
            maxValue: _isKg ? 200 : 440,
            value: _weight,
            step: 1,
            majorStep: _isKg ? 5 : 10,
            itemWidth: 16.0,
            indicatorColor: const Color(0xFFBB0013),
            onChanged: (val) {
              setState(() => _weight = val);
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 4: HEIGHT
  // ==========================================
  Widget _buildHeightPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'What’s your height?',
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              fontSize: 28,
              fontWeight: FontWeight.w600, // REDUCED BOLDNESS
              color: const Color(0xFF333333),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _unitToggleButton(
                label: 'Cm',
                isSelected: _isCm,
                onTap: () {
                  if (!_isCm) setState(() => _isCm = true);
                },
              ),
              const SizedBox(width: 14),
              _unitToggleButton(
                label: 'Ft / In',
                isSelected: !_isCm,
                onTap: () {
                  if (_isCm) setState(() => _isCm = false);
                },
              ),
            ],
          ),
          const Spacer(),
          if (_isCm)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _height.toInt().toString(),
                  style: GoogleFonts.workSans(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Cm',
                  style: GoogleFonts.workSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF888888),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  (_height / 30.48).floor().toString(),
                  style: GoogleFonts.workSans(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
                Text(
                  'ft ',
                  style: GoogleFonts.workSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF888888),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ((_height % 30.48) / 2.54).round().toString(),
                  style: GoogleFonts.workSans(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
                Text(
                  'in',
                  style: GoogleFonts.workSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          _RulerScalePicker(
            key: const ValueKey('height_ruler'),
            minValue: 100,
            maxValue: 230,
            value: _height,
            step: 1,
            majorStep: 5,
            itemWidth: 16.0,
            indicatorColor: const Color(0xFF003DD0),
            onChanged: (val) {
              setState(() => _height = val);
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _unitToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _BouncingButton(
      scaleFactor: 0.9,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003DD0) : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF003DD0).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PAGE 5 & 6: MEDICAL / TAGS
  // ==========================================
  Widget _buildTagsPage({
    required String title,
    required IconData illustration,
    required List<String> selectedTags,
    required List<String> suggestedTags,
  }) {
    TextEditingController controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.workSans(
                fontSize: 28,
                fontWeight: FontWeight.w600, // REDUCED BOLDNESS
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 20),
            Icon(illustration, size: 100, color: const Color(0xFF003DD0)),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF003DD0), width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedTags.map((tag) {
                      return Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, // Reduced boldness
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: const Color(0xFF003DD0),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                        onDeleted: () =>
                            setState(() => selectedTags.remove(tag)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: 'type_to_add'.tr(),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.isNotEmpty) {
                              setState(() => selectedTags.add(val.trim()));
                              controller.clear();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF003DD0),
                        ),
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            setState(
                              () => selectedTags.add(controller.text.trim()),
                            );
                            controller.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'most_common'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: suggestedTags.map((tag) {
                      return ActionChip(
                        label: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFF003DD0),
                            fontWeight: FontWeight.w600, // Reduced boldness
                          ),
                        ),
                        backgroundColor: const Color(0xFFE5F1FF),
                        side: BorderSide.none,
                        onPressed: () {
                          if (!selectedTags.contains(tag)) {
                            setState(() => selectedTags.add(tag));
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
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

// ==========================================
// RULER SCALE PICKER WIDGET
// ==========================================
class _RulerScalePicker extends StatefulWidget {
  final double minValue;
  final double maxValue;
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final int majorStep;
  final double itemWidth;
  final Color indicatorColor;

  const _RulerScalePicker({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.value,
    required this.onChanged,
    this.step = 1.0,
    this.majorStep = 5,
    this.itemWidth = 14.0,
    this.indicatorColor = const Color(0xFFBB0013),
  });

  @override
  State<_RulerScalePicker> createState() => _RulerScalePickerState();
}

class _RulerScalePickerState extends State<_RulerScalePicker> {
  late ScrollController _scrollController;
  late int _totalItems;
  double _lastVibratedValue = -1;

  @override
  void initState() {
    super.initState();
    _totalItems =
        ((widget.maxValue - widget.minValue) / widget.step).round() + 1;
    double initialOffset =
        ((widget.value - widget.minValue) / widget.step) * widget.itemWidth;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void didUpdateWidget(covariant _RulerScalePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minValue != widget.minValue ||
        oldWidget.maxValue != widget.maxValue ||
        oldWidget.value != widget.value) {
      _totalItems =
          ((widget.maxValue - widget.minValue) / widget.step).round() + 1;
      double targetOffset =
          ((widget.value - widget.minValue) / widget.step) * widget.itemWidth;
      if (_scrollController.hasClients &&
          (_scrollController.offset - targetOffset).abs() > widget.itemWidth) {
        _scrollController.jumpTo(targetOffset);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    double offset = _scrollController.offset;
    double calculatedValue =
        widget.minValue + (offset / widget.itemWidth) * widget.step;
    double clampedValue = calculatedValue.clamp(
      widget.minValue,
      widget.maxValue,
    );
    double roundedValue = (clampedValue / widget.step).round() * widget.step;

    if (roundedValue != _lastVibratedValue) {
      _lastVibratedValue = roundedValue;
      HapticFeedback.selectionClick(); // Lightweight hardware feel
      widget.onChanged(roundedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _onScroll();
        }
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;

          return SizedBox(
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: halfWidth),
                  itemCount: _totalItems,
                  itemBuilder: (context, index) {
                    double val = widget.minValue + index * widget.step;
                    bool isMajor = (val.round() % widget.majorStep == 0);

                    return SizedBox(
                      width: widget.itemWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: isMajor ? 2.2 : 1.2,
                            height: isMajor ? 38 : 20,
                            decoration: BoxDecoration(
                              color: isMajor
                                  ? const Color(0xFF555555)
                                  : const Color(0xFFD0D3D9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isMajor)
                            Text(
                              val.toInt().toString(),
                              style: GoogleFonts.workSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF777777),
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 14,
                  child: Container(
                    width: 3.5,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.indicatorColor,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.indicatorColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
