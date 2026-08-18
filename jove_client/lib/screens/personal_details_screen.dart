import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// Import your other screens for the bottom nav bar
import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final String uid = currentUser?.uid ?? '';
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    _mobileController.text = currentUser?.phoneNumber ?? '+91 ';
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
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();

    // Fix: Cache the messenger before await
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
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image. Please try again.'),
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

    // Fix: Cache the messenger and navigator before await
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Update Mobile Number',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: TextField(
                controller: phoneTempController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+91 9876543210',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingPhone ? null : () => navigator.pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navBgColor,
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
                                const SnackBar(
                                  content: Text('Mobile number updated!'),
                                  backgroundColor: Color(0xFF34C759),
                                ),
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => isSavingPhone = false);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Error updating number.'),
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
                      : const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
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
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    // Fix: Cache messenger
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
          const SnackBar(
            content: Text('Personal details saved successfully!'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Error saving changes.'),
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

    // Fix: Cache the navigator
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
          const SnackBar(content: Text('Error loading booking.')),
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

    return Scaffold(
      backgroundColor: _bgColor,
      extendBody: true,
      bottomNavigationBar: isKeyboardOpen
          ? const SizedBox.shrink()
          : _buildBottomNavBar(),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),

        child: SafeArea(
          bottom: false,
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
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTopAppBar(),
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
    );
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

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
              const Text(
                'Personal Details',
                style: TextStyle(
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

  Widget _buildAvatarSection(String photoUrl) {
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
                  color: _navBgColor.withValues(alpha: 0.1),
                  width: 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
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
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: _navBgColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickAndUploadImage,
          child: Text(
            _isUploadingImage ? 'Uploading...' : 'Update Photo',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Basic Info'),
          Row(
            children: [
              Expanded(
                child: _buildInputCard(
                  'Full name',
                  _nameController,
                  'e.g. Rahul Kumar',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputCard(
                  'Age',
                  _ageController,
                  'e.g. 32',
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Mobile number',
            style: TextStyle(
              color: _textMain,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 55,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    readOnly: true,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
                GestureDetector(
                  onTap: _showPhoneUpdateDialog,
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      color: _navBgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _buildSectionTitle('Body Info'),
          Row(
            children: [
              Expanded(
                child: _buildInputCard(
                  'Weight (KG)',
                  _weightController,
                  'e.g. 68.5',
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputCard(
                  'Height (CM)',
                  _heightController,
                  'e.g. 175',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: _navBgColor,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
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
          label: Text(
            _isLoading ? 'Saving...' : 'Save Changes',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return SafeArea(
      child: Container(
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
                  label: 'Home',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const HomeDashboardScreen()),
                ),
                _NavItem(
                  index: 1,
                  icon: Icons.calendar_today_rounded,
                  label: 'Booking',
                  selectedIndex: selectedIndex,
                  onTap: _navigateToBooking,
                ),
                _NavItem(
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ProgressScreen()),
                ),
                _NavItem(
                  index: 3,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chats',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ChatScreen()),
                ),
                _NavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ProfileScreen()),
                ),
              ],
            );
          },
        ),
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
