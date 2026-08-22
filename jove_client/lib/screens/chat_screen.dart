import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS (Automatically exports 'intl')

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart'; // ADDED IMPORT

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _redSendButton = Color(0xFFBB0013);
  static const Color _userBubbleColor = Color(0xFF00215F);
  static const Color _adminBubbleColor = Color(0xFFEef1f6);

  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(3);
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isNavigating = false;

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // --- SEND MESSAGE (PERFECTLY ALIGNED WITH REACT ADMIN) ---
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) {
      return;
    }

    HapticFeedback.lightImpact();
    _messageController.clear();

    try {
      final String uid = currentUser!.uid;
      final String clientName =
          currentUser!.displayName != null &&
              currentUser!.displayName!.isNotEmpty
          ? currentUser!.displayName!
          : 'athlete'.tr(); // TRANSLATED FALLBACK

      final chatDocRef = FirebaseFirestore.instance
          .collection('chatThreads')
          .doc(uid);
      final newMessageRef = chatDocRef.collection('messages').doc();

      final batch = FirebaseFirestore.instance.batch();

      batch.set(newMessageRef, {
        'text': text,
        'senderId': uid,
        'senderRole': 'client',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      batch.set(chatDocRef, {
        'clientName': clientName,
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
        'clientPhotoURL': currentUser!.photoURL,
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_to_send_message'.tr()), // TRANSLATED
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- OPEN PDF ---
  Future<void> _openPdf(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('could_not_open_pdf'.tr()), // TRANSLATED
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- SHOW DIET PDF MENU ---
  void _showDietTemplates() {
    if (currentUser == null) {
      return;
    }

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_rounded,
                        color: _navBgColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'diet_plans'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textMain,
                        ),
                      ), // TRANSLATED
                    ],
                  ),
                ),
                const Divider(height: 1),

                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chatThreads')
                        .doc(currentUser!.uid)
                        .collection('messages')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(
                              color: _navBgColor,
                            ),
                          ),
                        );
                      }

                      final pdfDocs =
                          snapshot.data?.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['type'] == 'pdf' ||
                                data['attachmentName'] != null;
                          }).toList() ??
                          [];

                      if (pdfDocs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "no_diet_plans".tr(),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ), // TRANSLATED
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: pdfDocs.length,
                        itemBuilder: (context, index) {
                          var data =
                              pdfDocs[index].data() as Map<String, dynamic>;
                          String fileName =
                              data['fileName'] ??
                              data['attachmentName'] ??
                              'Diet_Plan.pdf';
                          String fileUrl = data['fileUrl'] ?? '';

                          String timeString = '';
                          if (data['createdAt'] != null) {
                            DateTime dt = (data['createdAt'] as Timestamp)
                                .toDate();
                            timeString = DateFormat(
                              'MMM d, yyyy • h:mm a',
                              context.locale.languageCode,
                            ).format(dt); // LOCALIZED
                          }

                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (fileUrl.isNotEmpty) {
                                Navigator.pop(context);
                                _openPdf(fileUrl);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fileName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _textMain,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          timeString,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: Colors.grey,
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
          ),
        );
      },
    );
  }

  // --- NAVIGATION LOGIC ---
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

      if (!mounted) {
        return;
      }
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
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_loading_data'.tr())),
        ); // TRANSLATED
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _selectedIndexNotifier.value = 3;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopAppBar(),

                // --- FAST MESSAGES LIST ---
                Expanded(
                  child: currentUser == null
                      ? Center(
                          child: Text("please_login_chat".tr()),
                        ) // TRANSLATED
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chatThreads')
                              .doc(currentUser!.uid)
                              .collection('messages')
                              .orderBy('createdAt', descending: true)
                              .limit(100)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('something_went_wrong'.tr()),
                              ); // TRANSLATED
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _navBgColor,
                                ),
                              );
                            }

                            final docs =
                                snapshot.data?.docs.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return data['type'] != 'pdf' &&
                                      data['attachmentName'] == null;
                                }).toList() ??
                                [];

                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  "send_message_start".tr(),
                                  style: TextStyle(color: Colors.grey.shade500),
                                ), // TRANSLATED
                              );
                            }

                            return ListView.builder(
                              reverse: true,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                return RepaintBoundary(
                                  child: _buildMessageBubble(
                                    docs[index].data() as Map<String, dynamic>,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // --- INPUT FIELD ---
                _buildMessageInput(),

                SizedBox(height: isKeyboardOpen ? 16 : 95),
              ],
            ),
          ),

          // --- BOTTOM NAV BAR ---
          if (!isKeyboardOpen) _buildBottomNavBar(),
        ],
      ),
    );
  }

  // --- UPDATED APP BAR WITH NOTIFICATION ICON ---
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
                  _navigate(const ProgressScreen());
                },
              ),
              const SizedBox(width: 8),
              Text(
                'chats_title'.tr(),
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ), // TRANSLATED
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

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    bool isMe =
        data['senderRole'] == 'client' || data['senderId'] == currentUser?.uid;
    String message = data['text'] ?? '';

    String timeString = '';
    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      timeString = DateFormat(
        'h:mm a',
        context.locale.languageCode,
      ).format(dt); // LOCALIZED
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? _userBubbleColor : _adminBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : _textMain,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              timeString,
              style: TextStyle(
                color: isMe ? Colors.white60 : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: _bgColor),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showDietTemplates,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: _navBgColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEef1f6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'message_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                ), // TRANSLATED
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _redSendButton,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Align(
      alignment: Alignment.bottomCenter,
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
                  label: 'home_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const HomeDashboardScreen()),
                ), // TRANSLATED
                _NavItem(
                  index: 1,
                  icon: Icons.calendar_today_rounded,
                  label: 'booking_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: _navigateToBooking,
                ), // TRANSLATED
                _NavItem(
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'stats_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ProgressScreen()),
                ), // TRANSLATED
                _NavItem(
                  index: 3,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'chats_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () {},
                ), // TRANSLATED
                _NavItem(
                  index: 4,
                  icon: Icons.person_outline_rounded,
                  label: 'profile_nav'.tr(),
                  selectedIndex: selectedIndex,
                  onTap: () => _navigate(const ProfileScreen()),
                ), // TRANSLATED
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
