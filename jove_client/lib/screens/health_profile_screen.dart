import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart'; // <-- IMPORTED PROFILE SCREEN
import 'notification_screen.dart'; // <-- ADDED NOTIFICATION IMPORT
import '../widgets/package_required_modal.dart';
import '../theme/app_theme_controller.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _primaryBlue = Color(0xFF00215F);
  static const Color _cyanAccent = Color(0xFF00C4FF);
  static const Color _redButton = Color(0xFFBB0013);
  static const Color _cardBg = Colors.white;

  bool get _isDarkMode => AppThemeController.isDark;

  static const LinearGradient _meshGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.35, 0.65, 0.85, 1.0],
    colors: [
      Color(0xFFE2F4EB),
      Color(0xFFFDF0B9),
      Color(0xFFFA6A48),
      Color(0xFF0F4E53),
      Color(0xFFC7CDFA),
    ],
  );

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);

  bool _isLoading = true;
  bool _isNavigating = false;
  bool _hasActiveSubscription = false;

  // --- LOCAL DATA LISTS ---
  List<Map<String, dynamic>> _medicalConditions = [];
  List<Map<String, dynamic>> _physicalConstraints = [];
  List<Map<String, dynamic>> _surgeries = [];
  List<Map<String, dynamic>> _medications = [];

  // --- UI TOGGLE STATES ---
  bool _isAddingMedical = false;
  bool _isAddingConstraint = false;
  bool _isAddingSurgery = false;
  bool _isAddingMedication = false;

  // --- FORM CONTROLLERS ---
  final TextEditingController _medDetailsCtrl = TextEditingController();
  final TextEditingController _conNameCtrl = TextEditingController();
  final TextEditingController _conAreaCtrl = TextEditingController();
  final TextEditingController _conDurationCtrl = TextEditingController();
  double _conIntensity = 1.0;
  String _conType = 'chronic'.tr(); // Initialized via translation below

  final TextEditingController _surgNameCtrl = TextEditingController();
  final TextEditingController _surgDateCtrl = TextEditingController();
  final TextEditingController _surgHospitalCtrl = TextEditingController();
  bool _surgOngoingRehab = false;

  final TextEditingController _medNameCtrl = TextEditingController();
  final TextEditingController _medDosageCtrl = TextEditingController();
  final TextEditingController _medFreqCtrl = TextEditingController();
  final TextEditingController _medReasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHealthData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _medDetailsCtrl.dispose();
    _conNameCtrl.dispose();
    _conAreaCtrl.dispose();
    _conDurationCtrl.dispose();
    _surgNameCtrl.dispose();
    _surgDateCtrl.dispose();
    _surgHospitalCtrl.dispose();
    _medNameCtrl.dispose();
    _medDosageCtrl.dispose();
    _medFreqCtrl.dispose();
    _medReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHealthData() async {
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;

        _hasActiveSubscription =
            data['hasActiveSubscription'] == true ||
            (data['subscription'] is Map &&
                data['subscription']['status'] == 'Active');

        setState(() {
          if (data['medicalConditions'] is List) {
            _medicalConditions = (data['medicalConditions'] as List)
                .map((e) {
                  if (e is String) {
                    return {'name': e, 'diagnosed': 'recently'.tr()};
                  }
                  if (e is Map) {
                    return Map<String, dynamic>.from(e);
                  }
                  return <String, dynamic>{};
                })
                .where((e) => e.isNotEmpty)
                .toList();
          }

          if (data['physicalConstraints'] is List) {
            _physicalConstraints = (data['physicalConstraints'] as List)
                .map((e) {
                  if (e is String) {
                    return {
                      'name': e,
                      'intensity': 1.0,
                      'duration': 'unknown'.tr(),
                      'type': 'injury'.tr(),
                      'area': '',
                    };
                  }
                  if (e is Map) {
                    return Map<String, dynamic>.from(e);
                  }
                  return <String, dynamic>{};
                })
                .where((e) => e.isNotEmpty)
                .toList();
          }

          if (data['surgeries'] is List) {
            _surgeries = (data['surgeries'] as List)
                .map((e) {
                  if (e is Map) {
                    return Map<String, dynamic>.from(e);
                  }
                  return <String, dynamic>{};
                })
                .where((e) => e.isNotEmpty)
                .toList();
          }

          if (data['medications'] is List) {
            _medications = (data['medications'] as List)
                .map((e) {
                  if (e is Map) {
                    return Map<String, dynamic>.from(e);
                  }
                  return <String, dynamic>{};
                })
                .where((e) => e.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching health profile data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncToFirebase({String? successMessage}) async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Health Profile');
      return;
    }
    if (currentUser == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
            'medicalConditions': _medicalConditions,
            'physicalConstraints': _physicalConstraints,
            'surgeries': _surgeries,
            'medications': _medications,
          }, SetOptions(merge: true));

      if (successMessage != null && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF34C759),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('error_updating_db'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigate(Widget screen) {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a, b) => screen,
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
  }

  Future<void> _navigateToBooking() async {
    if (_isNavigating || currentUser == null) {
      return;
    }
    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) => const Center(child: CustomLoadingIndicator()),
    );

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>? ?? {};
      String? trainerId = userData['assignedTrainerId'];

      Widget nextScreen;
      if (trainerId == null || trainerId.isEmpty) {
        nextScreen = const SelectTrainerScreen();
      } else {
        DocumentSnapshot trainerDoc = await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .get(const GetOptions(source: Source.cache))
            .catchError(
              (_) => FirebaseFirestore.instance
                  .collection('trainers')
                  .doc(trainerId)
                  .get(),
            );
        nextScreen = trainerDoc.exists
            ? BookingScreen(trainer: Trainer.fromFirestore(trainerDoc))
            : const SelectTrainerScreen();
      }

      if (!mounted) {
        return;
      }
      navigator.pop();

      await navigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => nextScreen,
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      if (mounted) {
        navigator.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _selectedIndexNotifier.value = 4;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final Color currentBg = isDark ? const Color(0xFF000000) : _bgColor;

        return Scaffold(
          backgroundColor: currentBg,
          extendBody: true,
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SafeArea(
                  bottom: false,
                  child: _isLoading
                      ? const Center(child: CustomLoadingIndicator())
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RepaintBoundary(child: _buildTopAppBar()),
                              const SizedBox(height: 16),

                              _buildSectionHeader(
                                'health_condition_title'.tr(),
                              ),
                              _buildMedicalSection(),

                              const SizedBox(height: 24),
                              _buildSectionHeader(
                                'physical_constraints_title'.tr(),
                              ),
                              _buildConstraintsSection(),
                              const SizedBox(height: 16),
                              _buildSurgeriesSection(),
                              const SizedBox(height: 16),
                              _buildMedicationsSection(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ),
              if (!isKeyboardOpen)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomNavBar(),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- UPDATED APP BAR WITH NOTIFICATION ICON ---
  Widget _buildTopAppBar() {
    final bool isDark = _isDarkMode;
    final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Wrapped in Expanded to prevent right overflow
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: textMain,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'health_profile'.tr(),
                    style: TextStyle(
                      color: textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: textMain,
                size: 24,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, a, b) =>
                            const NotificationScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                                child: child,
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 150),
                      ),
                    );
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final bool isDark = _isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
        ),
      ),
    );
  }

  Widget _buildMedicalSection() {
    final bool isDark = _isDarkMode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAddingMedical
            ? null
            : (isDark ? const Color(0xFF121212) : _cardBg),
        gradient: _isAddingMedical ? _meshGradient : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
        boxShadow: [
          if (!_isAddingMedical)
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitleRow(
            'current_conditions'.tr(),
            _medicalConditions.length,
          ),
          const SizedBox(height: 16),

          if (!_isAddingMedical) ...[
            ..._medicalConditions.asMap().entries.map(
              (entry) => _buildMedicalItem(entry.key, entry.value),
            ),
            _buildDottedAddButton(
              'add_other_conditions'.tr(),
              () => setState(() => _isAddingMedical = true),
            ),
          ] else ...[
            _buildFormLabel('condition_name'.tr()),
            Row(
              children: [
                Expanded(
                  child: _buildFormTextField(
                    _medDetailsCtrl,
                    'eg_hypertension'.tr(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_medDetailsCtrl.text.trim().isNotEmpty) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _medicalConditions.add({
                            'name': _medDetailsCtrl.text.trim(),
                            'diagnosed': 'recently'.tr(),
                          });
                          _isAddingMedical = false;
                          _medDetailsCtrl.clear();
                        });
                        await _syncToFirebase(
                          successMessage: 'condition_added'.tr(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redButton,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(
                      'add'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isAddingMedical = false;
                  _medDetailsCtrl.clear();
                }),
                child: Text(
                  'cancel'.tr(),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalItem(int index, Map<String, dynamic> item) {
    final bool isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            item['name'].toString().toLowerCase().contains('diabetes')
                ? Icons.bloodtype_outlined
                : Icons.sick_outlined,
            color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${'diagnosed'.tr()}: ${item['diagnosed'] ?? 'unknown'.tr()}',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA8A8A8)
                        : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _redButton),
            onPressed: () async {
              HapticFeedback.lightImpact();
              setState(() => _medicalConditions.removeAt(index));
              await _syncToFirebase();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintsSection() {
    final bool isDark = _isDarkMode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAddingConstraint
            ? null
            : (isDark ? const Color(0xFF121212) : _cardBg),
        gradient: _isAddingConstraint ? _meshGradient : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitleRow(
            'current_limitations'.tr(),
            _physicalConstraints.length,
          ),
          const SizedBox(height: 16),

          if (!_isAddingConstraint) ...[
            ..._physicalConstraints.asMap().entries.map(
              (entry) => _buildConstraintItem(entry.key, entry.value),
            ),
            _buildDottedAddButton(
              'log_new_limitation'.tr(),
              () => setState(() => _isAddingConstraint = true),
            ),
          ] else ...[
            _buildFormLabel('limitation_name'.tr()),
            _buildFormTextField(_conNameCtrl, 'eg_knee_pain'.tr()),
            const SizedBox(height: 16),
            _buildFormLabel('affected_area'.tr()),
            _buildFormTextField(_conAreaCtrl, 'eg_lower_back'.tr()),
            const SizedBox(height: 16),
            _buildFormLabel('condition_intensity'.tr()),
            _buildIntensitySlider(),
            const SizedBox(height: 16),
            _buildFormLabel('type_label'.tr()),
            _buildTypeChips(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _isAddingConstraint = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF3B82F6)
                          : _primaryBlue,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_conNameCtrl.text.isNotEmpty) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _physicalConstraints.add({
                            'name': _conNameCtrl.text,
                            'area': _conAreaCtrl.text,
                            'intensity': _conIntensity,
                            'type': _conType,
                            'duration': 'recently'.tr(),
                          });
                          _isAddingConstraint = false;
                          _conNameCtrl.clear();
                          _conAreaCtrl.clear();
                          _conIntensity = 1.0;
                        });
                        await _syncToFirebase(
                          successMessage: 'limitation_saved'.tr(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redButton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'save'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConstraintItem(int index, Map<String, dynamic> item) {
    final bool isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.accessible_forward,
                      color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark
                                  ? const Color(0xFFF5F5F5)
                                  : _primaryBlue,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${'since'.tr()}: ${item['duration'] ?? 'unknown'.tr()}',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFA8A8A8)
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['type'] ?? 'chronic'.tr(),
                  style: const TextStyle(
                    color: _redButton,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (item['intensity'] ?? 1.0) / 2,
            backgroundColor: isDark
                ? const Color(0xFF262626)
                : Colors.grey.shade200,
            color: _redButton,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${'pain_intensity'.tr()}: ${item['intensity'] == 2.0
                      ? 'high'.tr()
                      : item['intensity'] == 1.0
                      ? 'moderate'.tr()
                      : 'low'.tr()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFA8A8A8) : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: _redButton,
                  size: 20,
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  setState(() => _physicalConstraints.removeAt(index));
                  await _syncToFirebase();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSurgeriesSection() {
    final bool isDark = _isDarkMode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAddingSurgery
            ? null
            : (isDark ? const Color(0xFF121212) : _cardBg),
        gradient: _isAddingSurgery ? _meshGradient : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitleRow('surgeries_procedures'.tr(), _surgeries.length),
          const SizedBox(height: 16),

          if (!_isAddingSurgery) ...[
            ..._surgeries.asMap().entries.map(
              (entry) => _buildSurgeryItem(entry.key, entry.value),
            ),
            _buildDottedAddButton(
              'log_procedure'.tr(),
              () => setState(() => _isAddingSurgery = true),
            ),
          ] else ...[
            _buildFormLabel('procedure_name'.tr()),
            _buildFormTextField(_surgNameCtrl, 'eg_acl'.tr()),
            const SizedBox(height: 12),
            _buildFormLabel('date_of_procedure'.tr()),
            _buildFormTextField(
              _surgDateCtrl,
              'mm_dd_yyyy'.tr(),
              icon: Icons.calendar_month,
            ),
            const SizedBox(height: 12),
            _buildFormLabel('hospital_clinic'.tr()),
            _buildFormTextField(_surgHospitalCtrl, 'hospital_name'.tr()),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(color: const Color(0xFF262626))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ongoing_rehab'.tr(),
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFF5F5F5)
                                : _primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'seeing_pt'.tr(),
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFA8A8A8)
                                : Colors.grey,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _surgOngoingRehab,
                    activeTrackColor: _cyanAccent,
                    onChanged: (v) => setState(() => _surgOngoingRehab = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isAddingSurgery = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF3B82F6)
                          : _primaryBlue,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_surgNameCtrl.text.isNotEmpty) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _surgeries.add({
                            'name': _surgNameCtrl.text,
                            'date': _surgDateCtrl.text,
                            'hospital': _surgHospitalCtrl.text,
                            'rehab': _surgOngoingRehab,
                          });
                          _isAddingSurgery = false;
                          _surgNameCtrl.clear();
                          _surgDateCtrl.clear();
                          _surgHospitalCtrl.clear();
                        });
                        await _syncToFirebase(
                          successMessage: 'procedure_saved'.tr(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redButton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'add'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSurgeryItem(int index, Map<String, dynamic> item) {
    final bool isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.healing,
            color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${'timeline'.tr()}: ${item['date'] ?? 'unknown'.tr()}',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA8A8A8)
                        : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _redButton),
            onPressed: () async {
              HapticFeedback.lightImpact();
              setState(() => _surgeries.removeAt(index));
              await _syncToFirebase();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsSection() {
    final bool isDark = _isDarkMode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAddingMedication
            ? null
            : (isDark ? const Color(0xFF121212) : _cardBg),
        gradient: _isAddingMedication ? _meshGradient : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitleRow('current_medications'.tr(), _medications.length),
          const SizedBox(height: 16),

          if (!_isAddingMedication) ...[
            ..._medications.asMap().entries.map(
              (entry) => _buildMedicationItem(entry.key, entry.value),
            ),
            _buildDottedAddButton(
              'add_medication'.tr(),
              () => setState(() => _isAddingMedication = true),
            ),
          ] else ...[
            _buildFormLabel('medication_name'.tr()),
            _buildFormTextField(_medNameCtrl, 'eg_ibuprofen'.tr()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormLabel('dosage'.tr()),
                      _buildFormTextField(_medDosageCtrl, 'eg_500mg'.tr()),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormLabel('frequency'.tr()),
                      _buildFormTextField(_medFreqCtrl, 'eg_twice_daily'.tr()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFormLabel('reason_for_med'.tr()),
            _buildFormTextField(_medReasonCtrl, 'select_conditions'.tr()),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _isAddingMedication = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF3B82F6)
                          : _primaryBlue,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_medNameCtrl.text.isNotEmpty) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _medications.add({
                            'name': _medNameCtrl.text,
                            'dosage': _medDosageCtrl.text,
                            'frequency': _medFreqCtrl.text,
                            'reason': _medReasonCtrl.text,
                          });
                          _isAddingMedication = false;
                          _medNameCtrl.clear();
                          _medDosageCtrl.clear();
                          _medFreqCtrl.clear();
                          _medReasonCtrl.clear();
                        });
                        await _syncToFirebase(
                          successMessage: 'medication_saved'.tr(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redButton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'add'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationItem(int index, Map<String, dynamic> item) {
    final bool isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.medication_outlined,
            color: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item['dosage']} • ${item['frequency']}',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA8A8A8)
                        : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _redButton),
            onPressed: () async {
              HapticFeedback.lightImpact();
              setState(() => _medications.removeAt(index));
              await _syncToFirebase();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardTitleRow(String title, int count) {
    final bool isDark = _isDarkMode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A2B) : const Color(0xFFE2F5E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count ${'active'.tr()}',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF34C759),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDottedAddButton(String text, VoidCallback onTap) {
    final bool isDark = _isDarkMode;
    return GestureDetector(
      onTap: () {
        if (!_hasActiveSubscription) {
          showPackageRequiredSheet(
            context,
            featureName: 'Health Profile',
            customMessage:
                'Adding and tracking medical conditions, physical constraints, surgeries, or medications requires an active membership package.',
          );
          return;
        }
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E1E)
              : _redButton.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? _redButton.withValues(alpha: 0.4)
                : _redButton.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _redButton,
          ),
        ),
      ),
    );
  }

  Widget _buildFormLabel(String text) {
    final bool isDark = _isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFormTextField(
    TextEditingController controller,
    String hint, {
    IconData? icon,
  }) {
    final bool isDark = _isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
      ),
      child: TextField(
        controller: controller,
        autofocus: false,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF5F5F5) : _primaryBlue,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: icon != null
              ? Icon(icon, color: isDark ? Colors.grey.shade500 : Colors.grey)
              : null,
        ),
      ),
    );
  }

  Widget _buildIntensitySlider() {
    final bool isDark = _isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _redButton,
              thumbColor: _redButton,
              inactiveTrackColor: isDark
                  ? const Color(0xFF262626)
                  : Colors.grey.shade300,
              trackHeight: 6,
            ),
            child: Slider(
              value: _conIntensity,
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (v) => setState(() => _conIntensity = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'mild'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFA8A8A8) : _primaryBlue,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              Flexible(
                child: Text(
                  'moderate'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFA8A8A8) : _primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: Text(
                  'severe'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFA8A8A8) : _primaryBlue,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    final bool isDark = _isDarkMode;
    List<String> types = [
      'injury'.tr(),
      'chronic'.tr(),
      'surgery'.tr(),
      'rehab'.tr(),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types
          .map(
            (t) => ChoiceChip(
              // REMOVED fixed width to allow text to grow safely
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(t),
              ),
              selected: _conType == t,
              onSelected: (val) => setState(() => _conType = t),
              selectedColor: isDark ? const Color(0xFF3B82F6) : _primaryBlue,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              labelStyle: TextStyle(
                color: _conType == t
                    ? Colors.white
                    : (isDark ? const Color(0xFFF5F5F5) : _primaryBlue),
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isDark ? const Color(0xFF262626) : Colors.transparent,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomNavBar() {
    final bool isDark = _isDarkMode;
    final Color navBg = isDark ? const Color(0xFF121212) : _primaryBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(40),
        border: isDark
            ? Border.all(color: const Color(0xFF262626), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                index: 0,
                icon: Icons.home_filled,
                label: 'home_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const HomeDashboardScreen()),
              ),
              _NavItem(
                index: 1,
                icon: Icons.calendar_today_rounded,
                label: 'booking_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: _navigateToBooking,
              ),
              _NavItem(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'stats_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ProgressScreen()),
              ),
              _NavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'chats_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ChatScreen()),
              ),
              _NavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'profile_nav'.tr(),
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ProfileScreen()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index, selectedIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedIndex == index;
    return Expanded(
      flex: isSelected ? 4 : 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            padding: isSelected
                ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0)
                : const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white70,
                  size: 20,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
