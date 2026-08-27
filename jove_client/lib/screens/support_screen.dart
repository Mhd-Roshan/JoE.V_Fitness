import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jove_client/widgets/custom_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

// Import your existing screens for navigation
import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'trainer_selection_screen.dart';
import 'notification_screen.dart';
import '../theme/app_theme_controller.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // Theme Colors (Matching Profile Page)
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redButton = Color(0xFFBB0013);
  static const Color _iconBg = Color(0xFFF0F2F5);

  bool get _isDarkMode => AppThemeController.isDark;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  // State Notifiers for Buttery Smooth UI
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(4);
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);

  // Form Controllers & State
  final TextEditingController _messageController = TextEditingController();
  final ValueNotifier<String> _subjectNotifier = ValueNotifier<String>(
    'Technical Issues',
  );

  final List<String> _subjects = [
    'Technical Issues',
    'Billing & Payments',
    'Trainer Feedback',
    'General Enquiry',
  ];

  late Stream<QuerySnapshot> _ticketsStream;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    final uid = currentUser?.uid ?? '';
    _ticketsStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _tabNotifier.dispose();
    _isSubmitting.dispose();
    _messageController.dispose();
    _subjectNotifier.dispose();
    super.dispose();
  }

  // ==========================================
  // URL LAUNCHERS & ACTIONS (REAL DATA)
  // ==========================================
  Future<void> _handleChatNavigation() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  Future<void> _handleCallAction() async {
    HapticFeedback.selectionClick();
    final Uri url = Uri.parse('tel:+91987654345');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open phone dialer")),
        );
      }
    }
  }

  Future<void> _handleEmailAction() async {
    HapticFeedback.selectionClick();
    final Uri url = Uri.parse('mailto:admin@gmail.com?subject=Support Enquiry');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open email app")),
        );
      }
    }
  }

  Future<void> _openAttachmentUrl(String url) async {
    HapticFeedback.lightImpact();
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ==========================================
  // FIREBASE UPLOAD
  // ==========================================
  Future<void> _submitTicket() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your issue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    _isSubmitting.value = true;

    try {
      // Save Ticket to Firestore
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': currentUser?.uid ?? 'unknown',
        'subject': _subjectNotifier.value,
        'message': _messageController.text.trim(),
        'status': 'Pending',
        'adminReply': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Reset Form
      _messageController.clear();
      _subjectNotifier.value = _subjects.first;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Switch to Inbox tab instantly
      _tabNotifier.value = 1;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please check connection.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isSubmitting.value = false;
    }
  }

  // --- NAVIGATION LOGIC ---
  Future<void> _handleStandardNavigation(Widget screen, int index) async {
    if (_isNavigating) return;
    HapticFeedback.selectionClick();
    setState(() => _isNavigating = true);
    _selectedIndexNotifier.value = index;

    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, a, b, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _navigateToBooking() async {
    if (_isNavigating || currentUser == null) return;
    _isNavigating = true;
    HapticFeedback.selectionClick();

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CustomLoadingIndicator()),
    );

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final String? trainerId = userData['assignedTrainerId'];
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
      Navigator.pop(context);

      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, b) => nextScreen,
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error loading booking.')));
    } finally {
      if (mounted) {
        _isNavigating = false;
        _selectedIndexNotifier.value = 4;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final Color currentBg = isDark ? const Color(0xFF000000) : _bgColor;

        return Scaffold(
          backgroundColor: currentBg,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildTopAppBar(),
                    const SizedBox(height: 12),
                    _buildTabToggle(),
                    const SizedBox(height: 16),

                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _tabNotifier,
                        builder: (context, tabIndex, child) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: tabIndex == 0
                                ? _buildContactFormTab()
                                : _buildInboxTab(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              if (!isKeyboardOpen)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _FloatingNavBar(
                    selectedIndexNotifier: _selectedIndexNotifier,
                    onHomeTap: () => _handleStandardNavigation(
                      const HomeDashboardScreen(),
                      0,
                    ),
                    onBookingTap: _navigateToBooking,
                    onStatsTap: () =>
                        _handleStandardNavigation(const ProgressScreen(), 2),
                    onChatsTap: () =>
                        _handleStandardNavigation(const ChatScreen(), 3),
                    onProfileTap: () =>
                        _handleStandardNavigation(const ProfileScreen(), 4),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopAppBar() {
    final bool isDark = _isDarkMode;
    final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Contact Support',
                style: TextStyle(
                  color: textMain,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
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

  Widget _buildTabToggle() {
    final bool isDark = _isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: _tabNotifier,
        builder: (context, currentIndex, _) {
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _tabNotifier.value = 0;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: currentIndex == 0
                          ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: currentIndex == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.05,
                                ),
                                blurRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Submit Issue',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: currentIndex == 0
                              ? (isDark ? const Color(0xFF3B82F6) : _navBgColor)
                              : (isDark
                                    ? const Color(0xFFA8A8A8)
                                    : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _tabNotifier.value = 1;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: currentIndex == 1
                          ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: currentIndex == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.05,
                                ),
                                blurRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Inbox',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: currentIndex == 1
                              ? (isDark ? const Color(0xFF3B82F6) : _navBgColor)
                              : (isDark
                                    ? const Color(0xFFA8A8A8)
                                    : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: SUBMIT NEW ISSUE
  // ==========================================
  Widget _buildContactFormTab() {
    final bool isDark = _isDarkMode;

    return SingleChildScrollView(
      key: const PageStorageKey('ContactForm'),
      padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Alert',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
            ),
          ),
          const SizedBox(height: 12),

          // Contact Cards (WITH REAL CLICK ACTIONS)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _buildContactCard(
                  Icons.chat_bubble_outline,
                  'Chat with us',
                  'Quick replies for general queries',
                  _handleChatNavigation,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF262626)
                      : Colors.grey.shade100,
                ),
                _buildContactCard(
                  Icons.phone_outlined,
                  'Call support',
                  '+91 987654345   8 AM - 9 PM',
                  _handleCallAction,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF262626)
                      : Colors.grey.shade100,
                ),
                _buildContactCard(
                  Icons.email_outlined,
                  'Email us',
                  'admin@gmail.com',
                  _handleEmailAction,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Direct Message',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
            ),
          ),
          const SizedBox(height: 16),

          // Subject Dropdown
          Text(
            'Enquiry Subject',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: _subjectNotifier,
            builder: (context, subject, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF262626)
                        : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: subject,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? const Color(0xFFA8A8A8) : Colors.grey,
                    ),
                    items: _subjects.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(
                          val,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFF5F5F5)
                                : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _subjectNotifier.value = val;
                    },
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Message Field
          Text(
            'How can i help you',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            autofocus: false,
            maxLines: 4,
            style: TextStyle(
              color: isDark ? const Color(0xFFF5F5F5) : _textMain,
            ),
            decoration: InputDecoration(
              hintText: 'Describe the issue in details....',
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade500,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : _iconBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF262626) : Colors.transparent,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF262626) : Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          ValueListenableBuilder<bool>(
            valueListenable: _isSubmitting,
            builder: (context, isSubmitting, _) {
              return SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _redButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomLoadingIndicator(),
                        )
                      : const Text(
                          'Send Message',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  label: isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Updated Contact Card to accept an onTap function
  Widget _buildContactCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final bool isDark = _isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                borderRadius: BorderRadius.circular(10),
                border: isDark
                    ? Border.all(color: const Color(0xFF262626))
                    : null,
              ),
              child: Icon(
                icon,
                color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFA8A8A8)
                          : Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? const Color(0xFF444444) : Colors.grey.shade300,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: INBOX (LIVE FIRESTORE DATA)
  // ==========================================
  Widget _buildInboxTab() {
    final bool isDark = _isDarkMode;

    return StreamBuilder<QuerySnapshot>(
      stream: _ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: const CustomLoadingIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 60,
                  color: isDark
                      ? const Color(0xFF444444)
                      : Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'No support tickets yet.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA8A8A8)
                        : Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
          physics: const BouncingScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var ticket =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String subject = ticket['subject'] ?? 'Support Ticket';
            String message = ticket['message'] ?? '';
            String status = ticket['status'] ?? 'Pending';
            String? adminReply = ticket['adminReply'];
            String? attachmentUrl = ticket['attachmentUrl'];
            Timestamp? date = ticket['createdAt'];

            String dateStr = date != null
                ? DateFormat('dd MMM, hh:mm a').format(date.toDate())
                : '';
            Color statusColor = status == 'Pending'
                ? Colors.orange
                : (status == 'Answered' ? Colors.green : Colors.grey);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF262626)
                      : Colors.grey.shade200,
                ),
                boxShadow: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFE0E0E0) : Colors.black87,
                      fontSize: 14,
                    ),
                  ),

                  // SHOW ATTACHMENT IF IT EXISTS (For historical tickets)
                  if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ActionChip(
                      backgroundColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : _iconBg,
                      side: BorderSide.none,
                      avatar: Icon(
                        Icons.attachment_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                      ),
                      label: Text(
                        "View Attachment",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                        ),
                      ),
                      onPressed: () => _openAttachmentUrl(attachmentUrl),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFA8A8A8)
                          : Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),

                  // ADMIN REPLY BUBBLE
                  if (adminReply != null && adminReply.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                              : _navBgColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            color: isDark
                                ? const Color(0xFF3B82F6)
                                : _navBgColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Reply',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFF3B82F6)
                                        : _navBgColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  adminReply,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFE0E0E0)
                                        : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- BOTTOM NAVBAR COMPONENT ---
class _FloatingNavBar extends StatelessWidget {
  final ValueNotifier<int> selectedIndexNotifier;
  final VoidCallback onHomeTap;
  final VoidCallback onBookingTap;
  final VoidCallback onStatsTap;
  final VoidCallback onChatsTap;
  final VoidCallback onProfileTap;

  const _FloatingNavBar({
    required this.selectedIndexNotifier,
    required this.onHomeTap,
    required this.onBookingTap,
    required this.onStatsTap,
    required this.onChatsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final Color navBg = isDark
            ? const Color(0xFF121212)
            : const Color(0xFF00215F);

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
            valueListenable: selectedIndexNotifier,
            builder: (context, selectedIndex, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavItem(
                    index: 0,
                    icon: Icons.home_filled,
                    label: 'Home',
                    selectedIndex: selectedIndex,
                    onTap: onHomeTap,
                  ),
                  _NavItem(
                    index: 1,
                    icon: Icons.calendar_today_rounded,
                    label: 'Booking',
                    selectedIndex: selectedIndex,
                    onTap: onBookingTap,
                  ),
                  _NavItem(
                    index: 2,
                    icon: Icons.bar_chart_rounded,
                    label: 'Stats',
                    selectedIndex: selectedIndex,
                    onTap: onStatsTap,
                  ),
                  _NavItem(
                    index: 3,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chats',
                    selectedIndex: selectedIndex,
                    onTap: onChatsTap,
                  ),
                  _NavItem(
                    index: 4,
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    selectedIndex: selectedIndex,
                    onTap: onProfileTap,
                  ),
                ],
              );
            },
          ),
        );
      },
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
