import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

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

  // We now only have 6 pages for the Assessment.
  // Page 7 is now handled by your PackageSelectScreen!
  final int _totalPages = 6;
  bool _isLoading = false;

  // --- Assessment Data State ---
  final List<String> _selectedGoals = [];
  String _selectedGender = '';
  double _weight = 70;
  bool _isKg = true;
  double _height = 175;
  bool _isCm = true;
  final List<String> _medicalConditions = [];
  final List<String> _physicalConstraints = [];

  // NEW: Firebase Stream for Goals
  late Stream<QuerySnapshot> _availableGoalsStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream to fetch goals from Firebase
    _availableGoalsStream = FirebaseFirestore.instance
        .collection('fitness_goals')
        .snapshots();
  }

  // Helper method to assign appropriate icons based on Firebase string
  IconData _getIconForGoal(String title) {
    String lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('muscle') || lowerTitle.contains('strength')) {
      return Icons.fitness_center_rounded;
    }
    if (lowerTitle.contains('weight') || lowerTitle.contains('fat')) {
      return Icons.monitor_weight_outlined;
    }
    if (lowerTitle.contains('medical') || lowerTitle.contains('injury')) {
      return Icons.medical_services_outlined;
    }
    if (lowerTitle.contains('lifestyle') || lowerTitle.contains('health')) {
      return Icons.self_improvement_rounded;
    }
    if (lowerTitle.contains('stress') || lowerTitle.contains('balance')) {
      return Icons.spa_outlined;
    }
    if (lowerTitle.contains('cardio') || lowerTitle.contains('stamina')) {
      return Icons.favorite_border_rounded;
    }
    return Icons.track_changes_rounded; // Default fallback icon
  }

  // ==========================================
  // ERROR MESSAGE HELPER
  // ==========================================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================
  // VALIDATION & NAVIGATION LOGIC
  // ==========================================
  void _nextPage() {
    if (_currentPage == 0 && _selectedGoals.isEmpty) {
      _showError('err_select_goal'.tr()); // TRANSLATED
      return;
    }
    if (_currentPage == 1 && _selectedGender.isEmpty) {
      _showError('err_select_gender'.tr()); // TRANSLATED
      return;
    }
    if (_currentPage == 4 && _medicalConditions.isEmpty) {
      _showError('err_medical_condition'.tr()); // TRANSLATED
      return;
    }
    if (_currentPage == 5 && _physicalConstraints.isEmpty) {
      _showError('err_physical_constraint'.tr()); // TRANSLATED
      return;
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // IF WE ARE ON THE LAST PAGE (PAGE 6), SAVE DATA & GO TO PACKAGES
      _saveAssessmentAndGoToPackages();
    }
  }

  void _skipPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAssessmentAndGoToPackages();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ==========================================
  // SAVE DATA & NAVIGATE TO PACKAGES
  // ==========================================
  Future<void> _saveAssessmentAndGoToPackages() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Save the assessment data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'goals': _selectedGoals,
          'gender': _selectedGender,
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
        // NAVIGATE TO THE NEW PACKAGE SELECT SCREEN!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PackageSelectScreen()),
        );
      }
    } catch (e) {
      _showError('err_save_failed'.tr()); // TRANSLATED
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // MAIN BUILD METHOD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Custom Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: List.generate(
                  _totalPages,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage >= index
                            ? const Color(0xFF01BCE3)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. The Assessment Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Disable swiping
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildGoalPage(), // 0
                  _buildGenderPage(), // 1
                  _buildWeightPage(), // 2
                  _buildHeightPage(), // 3
                  _buildTagsPage(
                    // 4
                    title: 'medical_conditions_title'.tr(), // TRANSLATED
                    illustration: Icons.medical_services,
                    selectedTags: _medicalConditions,
                    suggestedTags: [
                      'cond_diabetes'.tr(),
                      'cond_asthma'.tr(),
                      'cond_hypertension'.tr(),
                      'cond_thyroid'.tr(),
                    ], // TRANSLATED
                  ),
                  _buildTagsPage(
                    // 5
                    title: 'physical_constraints_title'.tr(), // TRANSLATED
                    illustration: Icons.healing,
                    selectedTags: _physicalConstraints,
                    suggestedTags: [
                      'inj_knee'.tr(),
                      'inj_back'.tr(),
                      'inj_shoulder'.tr(),
                      'inj_arthritis'.tr(),
                    ], // TRANSLATED
                  ),
                ],
              ),
            ),

            // 3. Bottom Navigation Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: _prevPage,
                      child: Container(
                        height: 55,
                        width: 55,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF00225D),
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 55,
                    ), // Keeps Next button aligned right on page 1
                  // Skip Button (Only for Medical & Injury pages)
                  if (_currentPage == 4 || _currentPage == 5)
                    TextButton(
                      onPressed: _skipPage,
                      child: Text(
                        'skip_for_now'.tr(), // TRANSLATED
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Next / View Packages Button
                  SizedBox(
                    height: 55,
                    width: (_currentPage == 4 || _currentPage == 5) ? 120 : 170,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA0C19), // Red
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _currentPage == _totalPages - 1
                                  ? 'view_packages'
                                        .tr() // TRANSLATED
                                  : 'continue_btn'.tr(), // TRANSLATED
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
  // PAGE 0: GOALS (FETCHED FROM FIREBASE)
  // ==========================================
  Widget _buildGoalPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'main_goal_title'.tr(), // TRANSLATED
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _availableGoalsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF01BCE3)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'no_goals_found'.tr(), // TRANSLATED
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String title =
                        data['title'] ?? 'unknown_goal'.tr(); // TRANSLATED
                    bool isSelected = _selectedGoals.contains(title);
                    IconData icon = _getIconForGoal(title);

                    return GestureDetector(
                      onTap: () {
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
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF4FAFF)
                              : const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF01BCE3)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected
                                  ? const Color(0xFF01BCE3)
                                  : Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFF00225D)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF01BCE3),
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
            'gender_title'.tr(), // TRANSLATED
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 40),
          _genderCard(
            gender: 'gender_male'.tr(), // TRANSLATED
            symbol: '♂',
            imagePath: 'assets/images/male.png',
          ),
          const SizedBox(height: 20),
          _genderCard(
            gender: 'gender_female'.tr(), // TRANSLATED
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
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 140,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4FAFF) : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF01BCE3) : Colors.transparent,
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
                          : const Color(0xFFF4F4F4),
                      (isSelected
                              ? const Color(0xFFF4FAFF)
                              : const Color(0xFFF4F4F4))
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
  // PAGE 2 & 3: MEASUREMENTS
  // ==========================================
  Widget _buildWeightPage() {
    return _buildMeasurementPage(
      title: 'weight_title'.tr(), // TRANSLATED
      isMetric: _isKg,
      metricLabel: 'unit_kg'.tr(), // TRANSLATED
      imperialLabel: 'unit_lbs'.tr(), // TRANSLATED
      currentValue: _weight,
      onUnitToggle: (val) => setState(() => _isKg = val),
      onValueChanged: (val) => setState(() => _weight = val),
    );
  }

  Widget _buildHeightPage() {
    return _buildMeasurementPage(
      title: 'height_title'.tr(), // TRANSLATED
      isMetric: _isCm,
      metricLabel: 'unit_cm'.tr(), // TRANSLATED
      imperialLabel: 'unit_ft'.tr(), // TRANSLATED
      currentValue: _height,
      onUnitToggle: (val) => setState(() => _isCm = val),
      onValueChanged: (val) => setState(() => _height = val),
    );
  }

  Widget _buildMeasurementPage({
    required String title,
    required bool isMetric,
    required String metricLabel,
    required String imperialLabel,
    required double currentValue,
    required Function(bool) onUnitToggle,
    required Function(double) onValueChanged,
  }) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          width: 250,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onUnitToggle(true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isMetric
                          ? const Color(0xFF00225D)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      border: isMetric
                          ? Border.all(color: const Color(0xFF01BCE3), width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      metricLabel,
                      style: TextStyle(
                        color: isMetric ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onUnitToggle(false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !isMetric
                          ? const Color(0xFF00225D)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                      border: !isMetric
                          ? Border.all(color: const Color(0xFF01BCE3), width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      imperialLabel,
                      style: TextStyle(
                        color: !isMetric ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              currentValue.toInt().toString(),
              style: const TextStyle(
                fontSize: 70,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00225D),
              ),
            ),
            Text(
              isMetric ? metricLabel : imperialLabel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF01BCE3),
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: const Color(0xFF00225D),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: currentValue,
              min: 30,
              max: 250,
              onChanged: onValueChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PAGE 4 & 5: MEDICAL / TAGS
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
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00225D),
              ),
            ),
            const SizedBox(height: 20),
            Icon(illustration, size: 100, color: const Color(0xFFBA0C19)),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF01BCE3), width: 2),
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFF7DE1F5),
                        deleteIcon: const Icon(Icons.close, size: 16),
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
                            hintText: 'type_to_add'.tr(), // TRANSLATED
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
                          color: Color(0xFF01BCE3),
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
                  'most_common'.tr(), // TRANSLATED
                  style: const TextStyle(color: Colors.grey),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: suggestedTags.map((tag) {
                      return ActionChip(
                        label: Text(
                          tag,
                          style: const TextStyle(color: Color(0xFF00225D)),
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
