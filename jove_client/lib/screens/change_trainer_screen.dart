import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED FOR METHODCHANNEL
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'trainer_selection_screen.dart';

class ChangeTrainerScreen extends StatefulWidget {
  const ChangeTrainerScreen({super.key});

  @override
  State<ChangeTrainerScreen> createState() => _ChangeTrainerScreenState();
}

class _ChangeTrainerScreenState extends State<ChangeTrainerScreen> {
  // --- NATIVE SCREENSHOT CHANNEL ---
  static const platform = MethodChannel('com.example.jove_client/screenshot');

  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redButton = Color(0xFFBB0013);
  static const Color _iconBg = Color(0xFFF0F2F5);

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);

  bool _isLoading = true;
  bool _isNavigating = false;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _currentTrainerData;
  final List<Map<String, dynamic>> _availableTrainers = [];
  bool _isPackageExpired = false;

  @override
  void initState() {
    super.initState();
    _disableScreenshots(); // Calls Native Kotlin code
    _fetchData();
  }

  @override
  void dispose() {
    _enableScreenshots(); // Calls Native Kotlin code
    _selectedIndexNotifier.dispose();
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

  // ==========================================
  // DATA FETCHING & LOGIC
  // ==========================================
  Future<void> _fetchData() async {
    if (currentUser == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      _userData = userDoc.data() as Map<String, dynamic>? ?? {};

      Timestamp? endDate =
          _userData?['packageEndDate'] ??
          _userData?['subscription']?['nextBillingDate'];

      if (endDate != null) {
        _isPackageExpired = DateTime.now().isAfter(endDate.toDate());
      } else {
        _isPackageExpired = false;
      }

      String? currentTrainerId = _userData?['assignedTrainerId'];
      QuerySnapshot trainerDocs = await FirebaseFirestore.instance
          .collection('trainers')
          .get(const GetOptions(source: Source.serverAndCache));

      _availableTrainers.clear();

      for (var doc in trainerDocs.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        if (doc.id == currentTrainerId) {
          _currentTrainerData = data;
        } else {
          _availableTrainers.add(data);
        }
      }
    } catch (e) {
      debugPrint("Error fetching trainers: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _switchTrainer(
    String newTrainerId,
    String newTrainerName,
  ) async {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _navBgColor)),
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'assignedTrainerId': newTrainerId,
            'assignedTrainerName': newTrainerName,
            'hasReviewedCurrentTrainer': false,
          });

      if (mounted) {
        Navigator.pop(context); // Close Loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('success_switch_trainer'.tr(args: [newTrainerName])),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isLoading = true);
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close Loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_switch_trainer'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTrainerDetails(Map<String, dynamic> trainer) {
    HapticFeedback.lightImpact();

    String name = _parseStringOrList(
      trainer['name'] ?? trainer['fullName'] ?? 'trainer'.tr(),
    );
    String imageUrl =
        trainer['profileImageUrl'] ??
        trainer['photoUrl'] ??
        trainer['photoURL'] ??
        trainer['image'] ??
        '';
    String specialty = _parseStringOrList(
      trainer['specialty'] ?? trainer['title'] ?? 'elite_trainer'.tr(),
    );
    String bio = _parseStringOrList(
      trainer['bio'] ?? trainer['description'] ?? 'no_bio_available'.tr(),
    );
    String rating = trainer['rating']?.toString() ?? '';

    dynamic rawTags =
        trainer['tags'] ?? trainer['specialties'] ?? trainer['skills'];
    List<dynamic> tags = rawTags is List
        ? rawTags
        : (rawTags != null ? [rawTags] : []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                color: Colors.grey.shade200,
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (imageUrl.isEmpty)
                    const Center(
                      child: Icon(Icons.person, size: 80, color: Colors.grey),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: _textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                specialty,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (rating.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'about'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _navBgColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),

                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'expertise'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _navBgColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _iconBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag.toString(),
                                  style: const TextStyle(
                                    color: _navBgColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(24),
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
              child: ElevatedButton(
                onPressed: _isPackageExpired
                    ? () {
                        Navigator.pop(context);
                        _switchTrainer(trainer['id'], name);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _redButton,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isPackageExpired
                      ? 'switch_to_trainer'.tr(args: [name])
                      : 'package_must_expire'.tr(),
                  style: TextStyle(
                    color: _isPackageExpired
                        ? Colors.white
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // NAVIGATION LOGIC
  // ==========================================
  void _navigate(Widget screen) {
    if (_isNavigating) return;
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
      if (mounted) setState(() => _isNavigating = false);
    });
  }

  Future<void> _navigateToBooking() async {
    if (_isNavigating || currentUser == null) return;
    setState(() => _isNavigating = true);
    HapticFeedback.selectionClick();

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _navBgColor)),
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
        nextScreen = const ChangeTrainerScreen();
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
            : const ChangeTrainerScreen();
      }

      if (!mounted) return;
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

  // ==========================================
  // UI BUILDERS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _navBgColor),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: RepaintBoundary(child: _buildTopAppBar()),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      if (_currentTrainerData != null)
                        SliverToBoxAdapter(
                          child: RepaintBoundary(
                            child: _buildCurrentTrainerCard(),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, bottom: 12),
                          child: Text(
                            'select_trainers'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _navBgColor,
                            ),
                          ),
                        ),
                      ),

                      if (!_isPackageExpired)
                        SliverToBoxAdapter(
                          child: RepaintBoundary(child: _buildWarningBox()),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                      _buildTrainerSliverList(),

                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildBottomNavBar()),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: _textMain,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'trainer_change_title'.tr(),
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _textMain,
                size: 24,
              ),
              onPressed: () => HapticFeedback.lightImpact(),
            ),
          ),
        ],
      ),
    );
  }

  String _parseStringOrList(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is List) return data.join(' • ');
    return data.toString();
  }

  Widget _buildCurrentTrainerCard() {
    String name = _parseStringOrList(
      _currentTrainerData?['name'] ??
          _currentTrainerData?['fullName'] ??
          _userData?['assignedTrainerName'] ??
          'assigned_trainer'.tr(),
    );
    String imageUrl =
        _currentTrainerData?['profileImageUrl'] ??
        _currentTrainerData?['photoUrl'] ??
        _currentTrainerData?['photoURL'] ??
        _currentTrainerData?['image'] ??
        '';
    String rating = _currentTrainerData?['rating']?.toString() ?? '';
    String reviews =
        _currentTrainerData?['reviewsCount']?.toString() ??
        _currentTrainerData?['reviews']?.toString() ??
        '';
    String specialty = _parseStringOrList(
      _currentTrainerData?['specialty'] ?? _currentTrainerData?['title'],
    );
    String tier = _parseStringOrList(
      _currentTrainerData?['tier'] ??
          _currentTrainerData?['level'] ??
          'trainer'.tr(),
    );
    String certs = _parseStringOrList(
      _currentTrainerData?['certifications'] ??
          _currentTrainerData?['description'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _navBgColor, width: 3),
          color: Colors.grey.shade200,
          image: imageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (imageUrl.isEmpty)
              Center(
                child: Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.lightGreenAccent.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'current_active'.tr(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tier.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _redButton,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tier,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (rating.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        Text(
                          ' $rating ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (reviews.isNotEmpty)
                          Text(
                            '($reviews)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                  if (specialty.isNotEmpty || certs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [specialty, certs].where((e) => e.isNotEmpty).join(' • '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "switch_trainer_warning".tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerSliverList() {
    if (_availableTrainers.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              "no_other_trainers".tr(),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          var trainer = _availableTrainers[index];

          String name = _parseStringOrList(
            trainer['name'] ?? trainer['fullName'] ?? 'trainer'.tr(),
          );
          String imageUrl =
              trainer['profileImageUrl'] ??
              trainer['photoUrl'] ??
              trainer['photoURL'] ??
              trainer['image'] ??
              '';
          String specialty = _parseStringOrList(
            trainer['specialty'] ?? trainer['title'],
          );

          dynamic rawTags =
              trainer['tags'] ?? trainer['specialties'] ?? trainer['skills'];
          List<dynamic> tags = rawTags is List
              ? rawTags
              : (rawTags != null ? [rawTags] : []);
          String rating = trainer['rating']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.blue,
                                )
                              : null,
                        ),
                        if (rating.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                              Text(
                                ' $rating',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _textMain,
                            ),
                          ),
                          if (specialty.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              specialty,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _iconBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag.toString(),
                                        style: const TextStyle(
                                          color: _navBgColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showTrainerDetails(trainer),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'view_details'.tr(),
                          style: const TextStyle(
                            color: _navBgColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isPackageExpired
                            ? () => _switchTrainer(trainer['id'], name)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _redButton,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'switch_trainer_btn'.tr(),
                          style: TextStyle(
                            color: _isPackageExpired
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }, childCount: _availableTrainers.length),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _navBgColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: isSelected
            ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)
            : const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white70,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
