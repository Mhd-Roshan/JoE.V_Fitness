import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import 'home_dashboard_screen.dart';
import 'booking_screen.dart';
import 'progress_screen.dart';
import 'trainer_selection_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';

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

  // --- SEND MESSAGE ---
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
          : 'athlete'.tr();

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
            content: Text('failed_to_send_message'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- OPEN PDF ---
  Future<void> _openPdf(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF document is not attached to this plan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('could_not_open_pdf'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- 🔥 FETCH TEMPLATE + SUBCOLLECTION MEALS FROM FIREBASE 🔥 ---
  Future<Map<String, dynamic>> _fetchDietPlanData(String templateId) async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('dietPlanTemplates')
          .doc(templateId)
          .get();

      if (!docSnap.exists) return {};

      final mealsSnap = await FirebaseFirestore.instance
          .collection('dietPlanTemplates')
          .doc(templateId)
          .collection('meals')
          .get();

      final data = docSnap.data() ?? <String, dynamic>{};
      data['meals'] = mealsSnap.docs.map((d) => d.data()).toList();
      return data;
    } catch (e) {
      return {};
    }
  }

  // --- 🔥 HYPER-AGGRESSIVE MEAL EXTRACTION 🔥 ---
  List<dynamic> _extractMealsAggressively(Map<String, dynamic> data) {
    final possibleKeys = [
      'meals',
      'mealSequence',
      'mealPlan',
      'schedule',
      'dailyMeals',
      'items',
      'foodItems',
      'meal',
      'sequence',
      'list',
    ];

    for (String key in possibleKeys) {
      if (data[key] != null) {
        if (data[key] is List) {
          return data[key] as List<dynamic>;
        } else if (data[key] is Map) {
          return (data[key] as Map).values.toList();
        }
      }
    }

    for (var val in data.values) {
      if (val is List && val.isNotEmpty && val.first is Map) {
        return val;
      } else if (val is Map && val.isNotEmpty && val.values.first is Map) {
        return val.values.toList();
      }
    }

    return [];
  }

  // --- SHOW DIET PLAN BEAUTIFUL DASHBOARD ---
  void _showDietPlanDashboard(String templateId, String fileUrl, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _navBgColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: _navBgColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),

              // Fetch Data & Display Dashboard
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _fetchDietPlanData(templateId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _navBgColor),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Diet plan details not found.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    var data = snapshot.data!;

                    String calories = data['calories']?.toString() ?? '0';
                    String protein = data['protein']?.toString() ?? '0';
                    String fats =
                        data['fat']?.toString() ??
                        data['fats']?.toString() ??
                        '0';
                    String carbs =
                        data['carbs']?.toString() ??
                        data['netCarbsLimit']?.toString() ??
                        '0';

                    String fastingWindow =
                        data['fastingWindow']?.toString() ?? '';
                    String hydrationGoal =
                        data['hydrationGoal']?.toString() ?? '';
                    List<dynamic> prohibitions = data['prohibitions'] ?? [];

                    List<dynamic> meals = _extractMealsAggressively(data);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. MACRO STATS GRID
                          Row(
                            children: [
                              Expanded(
                                child: _buildMacroCard(
                                  "Daily Calories",
                                  calories,
                                  "kcal",
                                  Icons.local_fire_department,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMacroCard(
                                  "Protein",
                                  protein,
                                  "g",
                                  Icons.fitness_center,
                                  _navBgColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMacroCard(
                                  "Healthy Fats",
                                  fats,
                                  "g",
                                  Icons.water_drop_outlined,
                                  Colors.lightBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMacroCard(
                                  "Net Carbs",
                                  carbs,
                                  "g",
                                  Icons.eco_outlined,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 2. EXTRA INFO
                          if (fastingWindow.isNotEmpty ||
                              hydrationGoal.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fastingWindow.isNotEmpty)
                                  Expanded(
                                    child: _buildInfoCard(
                                      "Fasting Window",
                                      fastingWindow,
                                      "Fasting Protocol",
                                      Colors.indigo.shade100,
                                    ),
                                  ),
                                if (fastingWindow.isNotEmpty &&
                                    hydrationGoal.isNotEmpty)
                                  const SizedBox(width: 12),
                                if (hydrationGoal.isNotEmpty)
                                  Expanded(
                                    child: _buildInfoCard(
                                      "Hydration Goal",
                                      hydrationGoal,
                                      "Include electrolytes",
                                      Colors.cyan.shade100,
                                    ),
                                  ),
                              ],
                            ),

                          if (prohibitions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Prohibitions",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _navBgColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...prohibitions.map(
                                    (rule) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.cancel_outlined,
                                            color: _redSendButton,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              rule.toString(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                          const Text(
                            "Meal Sequence",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _navBgColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. MEAL SEQUENCE LIST
                          if (meals.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "No specific meal items listed in this template.",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else ...[
                            ...meals.map((mealData) {
                              if (mealData is! Map) {
                                return const SizedBox();
                              }

                              final m = mealData as Map<String, dynamic>;

                              final name =
                                  m['name'] ??
                                  m['mealName'] ??
                                  m['meal'] ??
                                  m['title'] ??
                                  '-';
                              final time = m['time'] ?? m['mealTime'] ?? '';
                              final items =
                                  m['ingredients'] ??
                                  m['items'] ??
                                  m['food'] ??
                                  m['description'] ??
                                  '-';
                              final mealImage =
                                  m['image'] ??
                                  m['imageUrl'] ??
                                  m['photoUrl'] ??
                                  m['imageURL'] ??
                                  '';

                              String p =
                                  m['protein']?.toString() ??
                                  m['p']?.toString() ??
                                  '0';
                              String c =
                                  m['carbs']?.toString() ??
                                  m['c']?.toString() ??
                                  '0';
                              String f =
                                  m['fats']?.toString() ??
                                  m['fat']?.toString() ??
                                  m['f']?.toString() ??
                                  '0';

                              if (m['macros'] != null && m['macros'] is Map) {
                                final mac = m['macros'] as Map;
                                p = mac['protein']?.toString() ?? p;
                                c = mac['carbs']?.toString() ?? c;
                                f =
                                    mac['fats']?.toString() ??
                                    mac['fat']?.toString() ??
                                    f;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: mealImage.toString().isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                mealImage.toString(),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons.restaurant,
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.restaurant,
                                              color: Colors.grey,
                                            ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (time.toString().isNotEmpty)
                                            Text(
                                              time.toString(),
                                              style: const TextStyle(
                                                color: _redSendButton,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          Text(
                                            name.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: _navBgColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            items.toString(),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Row(
                                      children: [
                                        _buildMacroPill(
                                          '${p}g',
                                          Colors.green.shade100,
                                          Colors.green.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        _buildMacroPill(
                                          '${c}g',
                                          Colors.orange.shade100,
                                          Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        _buildMacroPill(
                                          '${f}g',
                                          Colors.red.shade100,
                                          Colors.red.shade800,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],

                          const SizedBox(height: 32),
                          if (fileUrl.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _openPdf(fileUrl);
                                },
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: _redSendButton,
                                ),
                                label: const Text(
                                  "View Original PDF",
                                  style: TextStyle(
                                    color: _redSendButton,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _redSendButton),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _navBgColor,
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    String subLabel,
    Color badgeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _navBgColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subLabel,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _navBgColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textMain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPill(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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
                      ),
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
                            final type =
                                data['type']?.toString().toLowerCase() ?? '';
                            final text =
                                data['text']?.toString().toLowerCase() ?? '';
                            return type == 'pdf' ||
                                type == 'diet_plan' ||
                                data.containsKey('attachment') ||
                                text.contains('shared diet plan') ||
                                text.contains('**DIET PLAN');
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
                              ),
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
                          String fileName = 'Diet Plan';
                          String fileUrl = '';
                          String templateId = '';

                          if (data.containsKey('attachment') &&
                              data['attachment'] is Map) {
                            final att =
                                data['attachment'] as Map<String, dynamic>;
                            fileName =
                                att['name'] ?? att['subtitle'] ?? 'Diet Plan';
                            fileUrl = att['url'] ?? att['pdfUrl'] ?? '';
                            templateId = att['templateId'] ?? '';
                          } else {
                            final text = data['text']?.toString() ?? '';
                            if (text.contains('**DIET PLAN:')) {
                              final match = RegExp(
                                r'\*\*DIET PLAN:\s*([^*]+)\*\*',
                              ).firstMatch(text);
                              if (match != null) {
                                fileName =
                                    match.group(1)?.trim() ?? 'Diet Plan';
                              }
                            } else if (text.toLowerCase().contains(
                              'shared diet plan:',
                            )) {
                              fileName = text.split(':').last.trim();
                            }
                            fileUrl = data['fileUrl'] ?? data['url'] ?? '';
                          }

                          String timeString = '';
                          if (data['createdAt'] != null) {
                            DateTime dt = (data['createdAt'] as Timestamp)
                                .toDate();
                            timeString = DateFormat(
                              'MMM d, yyyy • h:mm a',
                              context.locale.languageCode,
                            ).format(dt);
                          }

                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              if (templateId.isNotEmpty) {
                                _showDietPlanDashboard(
                                  templateId,
                                  fileUrl,
                                  fileName,
                                );
                              } else if (fileUrl.isNotEmpty) {
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

  Widget _buildMessageRouter(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    final text = data['text']?.toString() ?? '';

    bool isDietPlan =
        type == 'diet_plan' ||
        data.containsKey('attachment') ||
        text.toLowerCase().contains('shared diet plan') ||
        text.contains('**DIET PLAN');

    if (isDietPlan) {
      return _buildDietPlanCard(data);
    } else {
      return _buildTextBubble(data);
    }
  }

  // Helper inside state for formatting the image fallback exactly like the screenshot
  Widget _buildFallbackImage() {
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFFF4F5F7), // Light grey background
      child: Center(
        child: Icon(Icons.restaurant, color: Colors.grey.shade400, size: 48),
      ),
    );
  }

  // Helper inside state for formatting the macro box exactly like the screenshot
  Widget _buildMacroBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00215F),
            ),
          ),
        ],
      ),
    );
  }

  // Internal UI Builder to keep the FutureBuilder clean
  Widget _buildDietCardUI({
    required bool isMe,
    required String templateId,
    required String fileUrl,
    required String fileName,
    required String subtitle,
    required String imageUrl,
    required String pPct,
    required String fPct,
    required String cPct,
    required String timeString,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (templateId.isNotEmpty) {
            _showDietPlanDashboard(templateId, fileUrl, fileName);
          } else if (fileUrl.isNotEmpty) {
            _openPdf(fileUrl);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: MediaQuery.of(context).size.width * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE & BADGE
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: imageUrl.isNotEmpty && imageUrl != 'null'
                        ? Image.network(
                            imageUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBB0013),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "DIET PLAN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // BODY
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.toLowerCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00215F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),

                    // MACROS
                    Row(
                      children: [
                        Expanded(child: _buildMacroBox('P', pPct)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroBox('F', fPct)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroBox('C', cPct)),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🔥 BEAUTIFUL REFINED DIET PLAN CHAT CARD (WITH FIREBASE FETCH) 🔥 ---
  Widget _buildDietPlanCard(Map<String, dynamic> data) {
    bool isMe =
        data['senderRole'] == 'client' || data['senderId'] == currentUser?.uid;

    String fileName = 'Diet Plan';
    String subtitle = 'Custom Diet Plan'; // Set default to match screenshot
    String fileUrl = '';
    String templateId = '';
    String timeString = '';

    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      timeString = DateFormat('h:mm a', context.locale.languageCode).format(dt);
    }

    // Extract basic IDs from the static message first
    if (data.containsKey('attachment') && data['attachment'] is Map) {
      final attachmentMap = data['attachment'] as Map<String, dynamic>;
      fileName =
          attachmentMap['name']?.toString() ??
          attachmentMap['subtitle']?.toString() ??
          'Diet Plan';
      subtitle = attachmentMap['subtitle']?.toString() ?? 'Custom Diet Plan';
      fileUrl =
          attachmentMap['url']?.toString() ??
          attachmentMap['pdfUrl']?.toString() ??
          '';
      templateId = attachmentMap['templateId']?.toString() ?? '';
    }

    if (fileName == 'Diet Plan' || fileName.isEmpty) {
      final text = data['text']?.toString() ?? '';
      if (text.contains('**DIET PLAN:')) {
        final match = RegExp(r'\*\*DIET PLAN:\s*([^*]+)\*\*').firstMatch(text);
        if (match != null) {
          fileName = match.group(1)?.trim() ?? 'Diet Plan';
        }
      } else if (text.toLowerCase().contains('shared diet plan:')) {
        fileName = text.split(':').last.trim();
      }
    }

    // 🔥 IF WE HAVE A TEMPLATE ID, FETCH DIRECTLY FROM FIREBASE!
    if (templateId.isNotEmpty) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _fetchDietPlanData(templateId),
        builder: (context, snapshot) {
          // While loading or if data is totally empty, parse from text as fallback
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildCardFromLocalData(
              data: data,
              isMe: isMe,
              fileName: fileName,
              subtitle: subtitle,
              templateId: templateId,
              fileUrl: fileUrl,
              timeString: timeString,
            );
          }

          // We successfully hit Firebase! Parse real live data!
          final tplData = snapshot.data!;
          String imageUrl =
              tplData['imageURL']?.toString() ??
              tplData['imageUrl']?.toString() ??
              '';
          int pGrams =
              num.tryParse(tplData['protein']?.toString() ?? '0')?.toInt() ?? 0;
          int fGrams =
              num.tryParse(tplData['fat']?.toString() ?? '0')?.toInt() ?? 0;
          int cGrams =
              num.tryParse(
                tplData['netCarbsLimit']?.toString() ??
                    tplData['carbs']?.toString() ??
                    '0',
              )?.toInt() ??
              0;

          List<dynamic> meals = _extractMealsAggressively(tplData);

          // Deep image fallback (check meals if template has no image)
          if (imageUrl.isEmpty || imageUrl == 'null') {
            for (var m in meals) {
              if (m is Map) {
                String mImg =
                    m['imageURL']?.toString() ??
                    m['imageUrl']?.toString() ??
                    m['image']?.toString() ??
                    '';
                if (mImg.isNotEmpty && mImg != 'null') {
                  imageUrl = mImg;
                  break;
                }
              }
            }
          }

          // Deep macro fallback (sum meals if template has 0 macros)
          if (pGrams == 0 && fGrams == 0 && cGrams == 0) {
            for (var meal in meals) {
              if (meal is Map) {
                pGrams +=
                    num.tryParse(
                      meal['protein']?.toString() ??
                          meal['p']?.toString() ??
                          '0',
                    )?.toInt() ??
                    0;
                fGrams +=
                    num.tryParse(
                      meal['fats']?.toString() ??
                          meal['fat']?.toString() ??
                          meal['f']?.toString() ??
                          '0',
                    )?.toInt() ??
                    0;
                cGrams +=
                    num.tryParse(
                      meal['carbs']?.toString() ?? meal['c']?.toString() ?? '0',
                    )?.toInt() ??
                    0;
              }
            }
          }

          int pCals = pGrams * 4;
          int fCals = fGrams * 9;
          int cCals = cGrams * 4;
          int totalCals = pCals + fCals + cCals;

          String pPct = totalCals > 0
              ? '${(pCals / totalCals * 100).round()}%'
              : '${pGrams}g';
          String fPct = totalCals > 0
              ? '${(fCals / totalCals * 100).round()}%'
              : '${fGrams}g';
          String cPct = totalCals > 0
              ? '${(cCals / totalCals * 100).round()}%'
              : '${cGrams}g';

          return _buildDietCardUI(
            isMe: isMe,
            templateId: templateId,
            fileUrl: fileUrl,
            fileName: fileName,
            subtitle: subtitle,
            imageUrl: imageUrl,
            pPct: pPct,
            fPct: fPct,
            cPct: cPct,
            timeString: timeString,
          );
        },
      );
    }

    // If there's no templateId saved, fallback to parsing static local message data
    return _buildCardFromLocalData(
      data: data,
      isMe: isMe,
      fileName: fileName,
      subtitle: subtitle,
      templateId: templateId,
      fileUrl: fileUrl,
      timeString: timeString,
    );
  }

  // Backup method just in case Firebase fails to load or no template ID is attached
  Widget _buildCardFromLocalData({
    required Map<String, dynamic> data,
    required bool isMe,
    required String fileName,
    required String subtitle,
    required String templateId,
    required String fileUrl,
    required String timeString,
  }) {
    String imageUrl = '';
    int pGrams = 0;
    int fGrams = 0;
    int cGrams = 0;

    if (data.containsKey('attachment') && data['attachment'] is Map) {
      final attachmentMap = data['attachment'] as Map<String, dynamic>;
      imageUrl =
          attachmentMap['imageURL']?.toString() ??
          attachmentMap['imageUrl']?.toString() ??
          '';
      pGrams =
          num.tryParse(attachmentMap['protein']?.toString() ?? '0')?.toInt() ??
          0;
      fGrams =
          num.tryParse(attachmentMap['fat']?.toString() ?? '0')?.toInt() ?? 0;
      cGrams =
          num.tryParse(attachmentMap['carbs']?.toString() ?? '0')?.toInt() ?? 0;
    }

    if (pGrams == 0 && fGrams == 0 && cGrams == 0) {
      final text = data['text']?.toString() ?? '';
      final pMatches = RegExp(r'P:\s*(\d+(\.\d+)?)g?').allMatches(text);
      final cMatches = RegExp(r'C:\s*(\d+(\.\d+)?)g?').allMatches(text);
      final fMatches = RegExp(r'F:\s*(\d+(\.\d+)?)g?').allMatches(text);

      for (var m in pMatches) {
        pGrams += num.tryParse(m.group(1) ?? '0')?.toInt() ?? 0;
      }
      for (var m in cMatches) {
        cGrams += num.tryParse(m.group(1) ?? '0')?.toInt() ?? 0;
      }
      for (var m in fMatches) {
        fGrams += num.tryParse(m.group(1) ?? '0')?.toInt() ?? 0;
      }
    }

    int pCals = pGrams * 4;
    int fCals = fGrams * 9;
    int cCals = cGrams * 4;
    int totalCals = pCals + fCals + cCals;

    String pPct = totalCals > 0
        ? '${(pCals / totalCals * 100).round()}%'
        : '${pGrams}g';
    String fPct = totalCals > 0
        ? '${(fCals / totalCals * 100).round()}%'
        : '${fGrams}g';
    String cPct = totalCals > 0
        ? '${(cCals / totalCals * 100).round()}%'
        : '${cGrams}g';

    return _buildDietCardUI(
      isMe: isMe,
      templateId: templateId,
      fileUrl: fileUrl,
      fileName: fileName,
      subtitle: subtitle,
      imageUrl: imageUrl,
      pPct: pPct,
      fPct: fPct,
      cPct: cPct,
      timeString: timeString,
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> data) {
    bool isMe =
        data['senderRole'] == 'client' || data['senderId'] == currentUser?.uid;
    String message = data['text'] ?? '';

    String timeString = '';
    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      timeString = DateFormat('h:mm a', context.locale.languageCode).format(dt);
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
                ),
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
            .get();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_loading_data'.tr())));
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
                  onTap: () {},
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

                Expanded(
                  child: currentUser == null
                      ? Center(child: Text("please_login_chat".tr()))
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
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _navBgColor,
                                ),
                              );
                            }

                            final docs = snapshot.data?.docs.toList() ?? [];

                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  "send_message_start".tr(),
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
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
                                  child: _buildMessageRouter(
                                    docs[index].data() as Map<String, dynamic>,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                _buildMessageInput(),
                SizedBox(height: isKeyboardOpen ? 16 : 95),
              ],
            ),
          ),

          if (!isKeyboardOpen) _buildBottomNavBar(),
        ],
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
