import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Make sure it says "extends StatefulWidget" right here!
class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  final Map<String, dynamic> _userAnswers = {
    'goal': '',
    'gender': '',
    'activity_level': '',
  };

  final int _totalPages = 3;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishAssessmentAndSave();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishAssessmentAndSave() async {
    setState(() => _isSaving = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'assessment': _userAnswers,
        'assessmentCompleted': true,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile Built Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F54),
      body: SafeArea(
        child: Column(
          children: [
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
                            ? const Color(0xFF00CBE6)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildGoalPage(),
                  _buildGenderPage(),
                  _buildActivityPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _previousPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  SizedBox(
                    width: 180,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA0C19),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _currentPage == _totalPages - 1
                                  ? 'Finish'
                                  : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
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

  Widget _buildGoalPage() {
    return _buildPageLayout(
      title: "What is your main goal?",
      subtitle: "Let us know so we can tailor your plan.",
      content: Column(
        children: [
          _buildSelectionCard(
            'goal',
            'Lose Weight',
            Icons.monitor_weight_outlined,
          ),
          _buildSelectionCard('goal', 'Build Muscle', Icons.fitness_center),
          _buildSelectionCard('goal', 'Keep Fit', Icons.directions_run),
        ],
      ),
    );
  }

  Widget _buildGenderPage() {
    return _buildPageLayout(
      title: "What is your gender?",
      subtitle: "This helps us calculate your metrics.",
      content: Row(
        children: [
          Expanded(child: _buildSelectionCard('gender', 'Male', Icons.male)),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSelectionCard('gender', 'Female', Icons.female),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPage() {
    return _buildPageLayout(
      title: "How active are you?",
      subtitle: "Tell us about your daily lifestyle.",
      content: Column(
        children: [
          _buildSelectionCard(
            'activity_level',
            'Beginner',
            Icons.accessibility_new,
          ),
          _buildSelectionCard(
            'activity_level',
            'Intermediate',
            Icons.directions_walk,
          ),
          _buildSelectionCard(
            'activity_level',
            'Advanced',
            Icons.directions_run,
          ),
        ],
      ),
    );
  }

  Widget _buildPageLayout({
    required String title,
    required String subtitle,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          content,
        ],
      ),
    );
  }

  Widget _buildSelectionCard(String mapKey, String value, IconData icon) {
    bool isSelected = _userAnswers[mapKey] == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _userAnswers[mapKey] = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00CBE6).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00CBE6)
                : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00CBE6) : Colors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00CBE6) : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
