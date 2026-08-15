import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // CHANGED: We now only have 6 pages for the Assessment.
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

  final List<Map<String, dynamic>> _goalOptions = [
    {'title': 'Muscle building', 'icon': Icons.fitness_center},
    {'title': 'Weight loss', 'icon': Icons.monitor_weight_outlined},
    {'title': 'Medical recovery', 'icon': Icons.medical_services_outlined},
    {'title': 'Lifestyle improvement', 'icon': Icons.self_improvement},
    {'title': 'Stress reduction & Balance', 'icon': Icons.spa_outlined},
  ];

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
      _showError('Please select at least one fitness goal to continue.');
      return;
    }
    if (_currentPage == 1 && _selectedGender.isEmpty) {
      _showError('Please select your gender to continue.');
      return;
    }
    if (_currentPage == 4 && _medicalConditions.isEmpty) {
      _showError('Please add a condition or click "Skip For Now".');
      return;
    }
    if (_currentPage == 5 && _physicalConstraints.isEmpty) {
      _showError('Please add an injury/constraint or click "Skip For Now".');
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
  // SAVE DATA & NAVIGATE TO PACKAGES (UPDATED)
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
      _showError("Failed to save data. Please try again.");
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
                    title: "Any Medical Conditions?",
                    illustration: Icons.medical_services,
                    selectedTags: _medicalConditions,
                    suggestedTags: [
                      'Diabetes',
                      'Asthma',
                      'Hypertension',
                      'Thyroid',
                    ],
                  ),
                  _buildTagsPage(
                    // 5
                    title: "Any Physical Constraints?",
                    illustration: Icons.healing,
                    selectedTags: _physicalConstraints,
                    suggestedTags: [
                      'Knee Pain',
                      'Back Pain',
                      'Shoulder Injury',
                      'Arthritis',
                    ],
                  ),
                  // Package screen removed! Now it's a separate file.
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
                      child: const Text(
                        'Skip For Now',
                        style: TextStyle(
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
                                  ? 'View Packages'
                                  : 'Continue',
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
  // PAGE 0: GOALS
  // ==========================================
  Widget _buildGoalPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "What is your main goal?",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: _goalOptions.length,
              itemBuilder: (context, index) {
                final option = _goalOptions[index];
                bool isSelected = _selectedGoals.contains(option['title']);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedGoals.remove(option['title']);
                      } else {
                        _selectedGoals.add(option['title']);
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
                          option['icon'],
                          color: isSelected
                              ? const Color(0xFF01BCE3)
                              : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          option['title'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF00225D)
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
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
          const Text(
            "What's your gender?",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 40),
          _genderCard(
            gender: 'Male',
            symbol: '♂',
            imagePath: 'assets/images/male.png',
          ),
          const SizedBox(height: 20),
          _genderCard(
            gender: 'Female',
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
      title: "What's your Weight?",
      isMetric: _isKg,
      metricLabel: 'kg',
      imperialLabel: 'lbs',
      currentValue: _weight,
      onUnitToggle: (val) => setState(() => _isKg = val),
      onValueChanged: (val) => setState(() => _weight = val),
    );
  }

  Widget _buildHeightPage() {
    return _buildMeasurementPage(
      title: "What's your height?",
      isMetric: _isCm,
      metricLabel: 'cm',
      imperialLabel: 'ft/in',
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
                          decoration: const InputDecoration(
                            hintText: 'Type to add...',
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
                const Text(
                  'Most Common: ',
                  style: TextStyle(color: Colors.grey),
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
