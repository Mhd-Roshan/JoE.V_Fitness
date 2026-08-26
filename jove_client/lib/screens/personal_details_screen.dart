import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

// Import your other screens for the bottom nav bar
import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart'; // <-- ADDED NOTIFICATION IMPORT
import '../widgets/package_required_modal.dart';
import '../theme/app_theme_controller.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redButton = Color(0xFFBB0013);

  bool get _isDarkMode => AppThemeController.isDark;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot> _userStream;

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isInitialDataLoaded = false;
  bool _isNavigating = false;
  bool _hasActiveSubscription = false;

  @override
  void initState() {
    super.initState();
    final String uid = currentUser?.uid ?? '';
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    _mobileController.text = currentUser?.phoneNumber ?? '+91 ';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _populateData(Map<String, dynamic> data) {
    _hasActiveSubscription = data['hasActiveSubscription'] == true ||
        (data['subscription'] is Map &&
            data['subscription']['status'] == 'Active');

    if (!_isInitialDataLoaded) {
      _nameController.text = data['fullName'] ?? data['name'] ?? '';
      _ageController.text = data['age']?.toString() ?? '';
      _weightController.text = data['weight']?.toString() ?? '';
      _heightController.text = data['height']?.toString() ?? '';

      if (data['mobile'] != null && data['mobile'].toString().isNotEmpty) {
        _mobileController.text = data['mobile'];
      }
      _isInitialDataLoaded = true;
    }
  }

  // --- 1. IMAGE UPLOAD LOGIC ---
  Future<void> _pickAndUploadImage() async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Profile Photo Upload');
      return;
    }
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();

    // Cache the messenger before await
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null || currentUser == null) return;

      setState(() => _isUploadingImage = true);

      File imageFile = File(pickedFile.path);
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${currentUser!.uid}.jpg');

      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'photoURL': downloadUrl});

      await currentUser!.updatePhotoURL(downloadUrl);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('msg_profile_pic_updated'.tr()), // TRANSLATED
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('err_upload_image'.tr()), // TRANSLATED
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // --- 2. MOBILE NUMBER CHANGE LOGIC ---
  void _showPhoneUpdateDialog() {
    HapticFeedback.lightImpact();
    TextEditingController phoneTempController = TextEditingController(
      text: _mobileController.text,
    );
    bool isSavingPhone = false;

    // Cache the messenger and navigator before await
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final bool isDark = _isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'dialog_update_mobile'.tr(), // TRANSLATED
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                ),
              ),
              content: TextField(
                controller: phoneTempController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                ),
                decoration: InputDecoration(
                  hintText: 'hint_mobile'.tr(), // TRANSLATED
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: isDark ? const BorderSide(color: Color(0xFF262626)) : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: isDark ? const BorderSide(color: Color(0xFF262626)) : BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingPhone ? null : () => navigator.pop(),
                  child: Text(
                    'btn_cancel'.tr(), // TRANSLATED
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSavingPhone
                      ? null
                      : () async {
                          setStateDialog(() => isSavingPhone = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser!.uid)
                                .set({
                                  'mobile': phoneTempController.text.trim(),
                                }, SetOptions(merge: true));

                            if (mounted) {
                              setState(
                                () => _mobileController.text =
                                    phoneTempController.text.trim(),
                              );
                              navigator.pop();
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'msg_mobile_updated'.tr(),
                                  ), // TRANSLATED
                                  backgroundColor: const Color(0xFF34C759),
                                ),
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => isSavingPhone = false);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'err_update_mobile'.tr(),
                                ), // TRANSLATED
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSavingPhone
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'btn_save'.tr(), // TRANSLATED
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SAVE ALL CHANGES ---
  Future<void> _saveChanges() async {
    if (!_hasActiveSubscription) {
      showPackageRequiredSheet(context, featureName: 'Profile Edits');
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    // Cache messenger
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final String uid = currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullName': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'weight': double.tryParse(_weightController.text.trim()),
        'height': double.tryParse(_heightController.text.trim()),
        'mobile': _mobileController.text.trim(),
      }, SetOptions(merge: true));

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('msg_details_saved'.tr()), // TRANSLATED
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('err_save_changes'.tr()), // TRANSLATED
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NAVIGATION LOGIC ---
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

    // Cache the navigator
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
          SnackBar(content: Text('error_loading_booking'.tr())), // TRANSLATED
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
                  bottom: false, // Allows scrolling behind the nav bar smoothly
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _userStream,
                    builder: (context, snapshot) {
                      var userData =
                          snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      if (snapshot.hasData) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _populateData(userData),
                        );
                      }

                      String photoUrl =
                          userData['photoURL'] ?? currentUser?.photoURL ?? '';

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          bottom: 120,
                        ), // Padding to avoid clipping behind navbar
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RepaintBoundary(child: _buildTopAppBar()),
                            const SizedBox(height: 16),

                            _buildAvatarSection(photoUrl),
                            const SizedBox(height: 32),

                            _buildFormSection(),
                            const SizedBox(height: 40),

                            _buildSaveButton(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Using a Stack overlay exactly like the Profile screen for maximum layout smoothness
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

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildTopAppBar() {
    final bool isDark = _isDarkMode;
    final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded added to constrain the title width gracefully
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
                    'personal_details_title'.tr(), // TRANSLATED
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: textMain,
                size: 24,
              ),
              onPressed: () {
                // --- UPDATED NOTIFICATION ROUTING ---
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

  Widget _buildAvatarSection(String photoUrl) {
    final bool isDark = _isDarkMode;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF262626) : _navBgColor.withValues(alpha: 0.1),
                  width: 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? Icon(Icons.person, size: 40, color: isDark ? Colors.grey.shade600 : Colors.grey)
                        : null,
                  ),
                  if (_isUploadingImage)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _isUploadingImage ? null : _pickAndUploadImage,
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: BoxShape.circle,
                  border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickAndUploadImage,
          child: Text(
            _isUploadingImage
                ? 'status_uploading'.tr()
                : 'btn_update_photo'.tr(), // TRANSLATED
            style: TextStyle(
              color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    final bool isDark = _isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('section_basic_info'.tr()), // TRANSLATED
          Row(
            children: [
              Expanded(
                child: _buildInputCard(
                  'label_full_name'.tr(), // TRANSLATED
                  _nameController,
                  'hint_name'.tr(), // TRANSLATED
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputCard(
                  'label_age'.tr(), // TRANSLATED
                  _ageController,
                  'hint_age'.tr(), // TRANSLATED
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'label_mobile'.tr(), // TRANSLATED
            style: TextStyle(
              color: isDark ? const Color(0xFFF5F5F5) : _textMain,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 55,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade300,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    readOnly: true,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFA8A8A8) : Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
                GestureDetector(
                  onTap: _showPhoneUpdateDialog,
                  child: Text(
                    'btn_change'.tr(), // TRANSLATED
                    style: TextStyle(
                      color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _buildSectionTitle('section_body_info'.tr()), // TRANSLATED
          Row(
            children: [
              Expanded(
                child: _buildInputCard(
                  'label_weight'.tr(), // TRANSLATED
                  _weightController,
                  'hint_weight'.tr(), // TRANSLATED
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputCard(
                  'label_height'.tr(), // TRANSLATED
                  _heightController,
                  'hint_height'.tr(), // TRANSLATED
                  isNumber: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final bool isDark = _isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInputCard(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    final bool isDark = _isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5F5) : _textMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            autofocus: false,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: TextStyle(
              color: isDark ? const Color(0xFFF5F5F5) : _textMain,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _redButton,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _saveChanges,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined, color: Colors.white, size: 22),
          label: Flexible(
            child: Text(
              _isLoading
                  ? 'status_saving'.tr()
                  : 'btn_save_changes'.tr(), // TRANSLATED
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final bool isDark = _isDarkMode;
    final Color navBg = isDark ? const Color(0xFF121212) : _navBgColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(40),
        border: isDark ? Border.all(color: const Color(0xFF262626), width: 1.2) : null,
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
                label: 'home_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const HomeDashboardScreen()),
              ),
              _NavItem(
                index: 1,
                icon: Icons.calendar_today_rounded,
                label: 'booking_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: _navigateToBooking,
              ),
              _NavItem(
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'stats_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ProgressScreen()),
              ),
              _NavItem(
                index: 3,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'chats_nav'.tr(), // TRANSLATED
                selectedIndex: selectedIndex,
                onTap: () => _navigate(const ChatScreen()),
              ),
              _NavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                label: 'profile_nav'.tr(), // TRANSLATED
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
