import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme_controller.dart';

// --- Notification Model ---
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'system',
      isRead: data['isRead'] ?? false,
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _activeBlue = Color(0xFF003AA3);

  // --- UPDATED FILTERS ---
  String _selectedFilter = 'All';
  final List<String> _filters = const ['All', 'Unread'];

  List<NotificationModel> _allNotifications = [];
  List<NotificationModel> _filteredNotifications = []; // Pre-computed for speed
  bool _isLoading = true;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final uid = currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            _allNotifications = snapshot.docs
                .map((doc) => NotificationModel.fromFirestore(doc))
                .toList();

            _applyFilter(); // Filter once when data arrives

            setState(() {
              _isLoading = false;
            });
          },
          onError: (error) {
            debugPrint("Error fetching notifications: $error");
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // --- Optimized Pre-Filtering ---
  void _setFilter(String filter) {
    if (_selectedFilter == filter) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_selectedFilter == 'Unread') {
      _filteredNotifications = _allNotifications
          .where((n) => !n.isRead)
          .toList();
    } else {
      _filteredNotifications = List.from(_allNotifications);
    }
  }

  // --- Optimistic Actions ---
  Future<void> _markAllAsRead() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();

    setState(() {
      for (var n in _allNotifications) {
        n.isRead = true;
      }
      _applyFilter();
    });

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');
      for (var n in _allNotifications) {
        batch.update(ref.doc(n.id), {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    final uid = currentUser?.uid;
    if (uid == null || notification.isRead) return;

    setState(() {
      notification.isRead = true;
      _applyFilter();
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notification.id)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _deleteNotification(String id) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _allNotifications.removeWhere((n) => n.id == id);
      _applyFilter();
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cache the 'now' time ONCE per frame instead of on every list item scroll
    final DateTime now = DateTime.now();

    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : _bgColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopAppBar(),
                _buildFilterPills(),
                const SizedBox(height: 8),

                Expanded(
                  child: RepaintBoundary(
                    // Prevents list scrolling from repainting the App Bar
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _activeBlue),
                          )
                        : _filteredNotifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                              top: 8,
                              bottom: 40,
                              left: 24,
                              right: 24,
                            ),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _filteredNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = _filteredNotifications[index];
                              return _NotificationCard(
                                key: ValueKey(
                                  notification.id,
                                ), // crucial for efficient UI updates
                                notification: notification,
                                now: now,
                                onRead: () => _markAsRead(notification),
                                onDelete: () =>
                                    _deleteNotification(notification.id),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopAppBar() {
    final bool isDark = AppThemeController.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? const Color(0xFFF5F5F5) : _textMain,
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
              'notifications_title'.tr(),
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5F5) : _textMain,
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
    );
  }

  // --- UPDATED FILTER ROW (Filters on left, Mark All Read on right) ---
  Widget _buildFilterPills() {
    final bool isDark = AppThemeController.isDark;
    bool hasUnread = _allNotifications.any((n) => !n.isRead);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left Side: Filter Pills (All / Unread)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return GestureDetector(
                onTap: () => _setFilter(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _activeBlue
                        : (isDark ? const Color(0xFF141414) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _activeBlue
                          : (isDark
                              ? const Color(0xFF262626)
                              : Colors.grey.shade300),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _activeBlue.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    filter.tr(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFFA8A8A8)
                              : Colors.grey.shade600),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),

          // Right Side: Mark All as Read Button
          if (hasUnread)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _activeBlue.withValues(alpha: isDark ? 0.25 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: isDark
                      ? Border.all(color: const Color(0xFF1E3A8A), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      color: isDark ? const Color(0xFF60A5FA) : _activeBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'mark_read'.tr(),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF60A5FA) : _activeBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isDark = AppThemeController.isDark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              shape: BoxShape.circle,
              border: isDark
                  ? Border.all(color: const Color(0xFF262626), width: 1.2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              color: isDark ? const Color(0xFF60A5FA) : _activeBlue,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'empty_notifications_title'.tr(),
            style: TextStyle(
              color: isDark ? const Color(0xFFF5F5F5) : _textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'empty_notifications_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Extracted Stateless Widget for Max Scroll Performance ---
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final DateTime now;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required super.key,
    required this.notification,
    required this.now,
    required this.onRead,
    required this.onDelete,
  });

  String _formatTimestamp() {
    final difference = now.difference(notification.timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    return DateFormat('MMM dd').format(notification.timestamp);
  }

  IconData _getIcon() {
    switch (notification.type) {
      case 'workout':
        return Icons.fitness_center_rounded;
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'workout':
        return Colors.deepOrange;
      case 'message':
        return Colors.green;
      default:
        return const Color(0xFF003AA3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppThemeController.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key('dismiss_${notification.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          onDelete();
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade500,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        child: GestureDetector(
          onTap: onRead,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? (isDark ? const Color(0xFF121212) : Colors.white)
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F5FF)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: notification.isRead
                    ? (isDark ? const Color(0xFF262626) : Colors.grey.shade200)
                    : (isDark
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF003AA3).withValues(alpha: 0.3)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.02,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100)
                        : _getIconColor().withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(),
                    color: notification.isRead
                        ? (isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade500)
                        : (isDark && notification.type == 'system'
                            ? const Color(0xFF60A5FA)
                            : _getIconColor()),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFF5F5F5)
                                    : const Color(0xFF1A1A1A),
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w700
                                    : FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(),
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFA8A8A8)
                                  : Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: notification.isRead
                              ? (isDark
                                  ? const Color(0xFFA8A8A8)
                                  : Colors.grey.shade600)
                              : (isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1A1A1A).withValues(alpha: 0.8)),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Unread Indicator
                if (!notification.isRead) ...[
                  const SizedBox(width: 12),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF003AA3),
                      shape: BoxShape.circle,
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
