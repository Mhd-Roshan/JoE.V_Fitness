import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/trainer_main_screen.dart';
import '../../services/language_service.dart';

class TrainerNotificationsScreen extends StatefulWidget {
  const TrainerNotificationsScreen({super.key});

  static bool isNotificationForTrainer({
    required Map<String, dynamic> data,
    required String uid,
    String? userEmail,
    Set<String>? trainerIds,
    Set<String>? trainerNames,
  }) {
    final tId = (data['trainerId'] ??
            data['targetId'] ??
            data['recipientId'] ??
            data['userId'] ??
            data['trainer_id'] ??
            '')
        .toString()
        .trim();

    if (tId.isNotEmpty) {
      if (tId == uid || (trainerIds != null && trainerIds.contains(tId))) {
        return true;
      }
    }

    final targetRole = (data['targetRole'] ??
            data['recipientRole'] ??
            data['role'] ??
            data['for'] ??
            data['type'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();

    if (targetRole == 'trainer' ||
        targetRole == 'all' ||
        targetRole == 'broadcast' ||
        targetRole == 'staff') {
      if (tId.isEmpty || tId == uid || (trainerIds != null && trainerIds.contains(tId))) {
        return true;
      }
    }

    final email = (data['trainerEmail'] ??
            data['trainer_email'] ??
            data['email'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    if (email.isNotEmpty &&
        userEmail != null &&
        userEmail.isNotEmpty &&
        email == userEmail.toLowerCase().trim()) {
      return true;
    }

    final trainerName = (data['trainerName'] ??
            data['trainer'] ??
            data['assignedTrainerName'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    if (trainerName.isNotEmpty && trainerNames != null) {
      if (trainerNames.any((n) =>
          n.isNotEmpty &&
          (trainerName == n ||
              trainerName.contains(n) ||
              n.contains(trainerName)))) {
        return true;
      }
    }

    if (tId.isEmpty && (targetRole.isEmpty || targetRole == 'general' || targetRole == 'session')) {
      return true;
    }

    return false;
  }

  static String getNotificationSource(Map<String, dynamic> data) {
    final sender = (data['from'] ??
            data['senderRole'] ??
            data['source'] ??
            data['sender'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();

    if (sender == 'admin') return 'Admin';
    if (sender == 'client') return 'Client';

    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    if (type.contains('admin') ||
        type.contains('broadcast') ||
        type.contains('announcement') ||
        type.contains('duty') ||
        type == 'system' ||
        data['requestedBy'] != null ||
        data['targetAudience'] != null) {
      return 'Admin';
    }

    if (type.contains('session') ||
        type.contains('booking') ||
        type.contains('reschedule') ||
        type.contains('cancel') ||
        type.contains('feedback') ||
        type.contains('client') ||
        data['clientId'] != null ||
        data['bookingId'] != null) {
      return 'Client';
    }

    return 'Admin';
  }

  static bool isNotificationUnread(Map<String, dynamic> data) {
    if (data['isRead'] == true || data['read'] == true) return false;
    if (data['isRead'] == false || data['read'] == false) return true;
    return true; // Default unread
  }

  @override
  State<TrainerNotificationsScreen> createState() =>
      _TrainerNotificationsScreenState();
}

class _TrainerNotificationsScreenState
    extends State<TrainerNotificationsScreen> {
  static const Color primaryRed = Color(0xFFC7001A);
  static const Color cyanAccent = Color(0xFF01BCE3);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  final Set<String> _myTrainerIds = {};
  final Set<String> _myTrainerNames = {};
  bool _identifiersLoaded = false;
  String _selectedFilter = 'all'; // 'all', 'admin', 'client'

  @override
  void initState() {
    super.initState();
    _loadTrainerIdentifiers();
  }

  Future<void> _loadTrainerIdentifiers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final uid = user.uid;
    _myTrainerIds.add(uid);

    if (user.displayName != null && user.displayName!.isNotEmpty) {
      final name = user.displayName!.toLowerCase().trim();
      _myTrainerNames.add(name);
      for (final part in name.split(' ')) {
        if (part.length > 1) {
          _myTrainerNames.add(part);
        }
      }
    }
    if (user.email != null && user.email!.isNotEmpty) {
      _myTrainerNames.add(user.email!.toLowerCase().trim());
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final uData = userDoc.data() ?? {};
        if (uData['fullName'] != null) {
          final fn = uData['fullName'].toString().toLowerCase().trim();
          _myTrainerNames.add(fn);
          for (final part in fn.split(' ')) {
            if (part.length > 1) {
              _myTrainerNames.add(part);
            }
          }
        }
        if (uData['name'] != null) {
          final n = uData['name'].toString().toLowerCase().trim();
          _myTrainerNames.add(n);
          for (final part in n.split(' ')) {
            if (part.length > 1) {
              _myTrainerNames.add(part);
            }
          }
        }
        if (uData['trainerId'] != null) {
          _myTrainerIds.add(uData['trainerId'].toString().trim());
        }
        if (uData['id'] != null) {
          _myTrainerIds.add(uData['id'].toString().trim());
        }
      }

      final directTrainerDoc = await FirebaseFirestore.instance
          .collection('trainers')
          .doc(uid)
          .get();
      if (directTrainerDoc.exists) {
        final tData = directTrainerDoc.data() ?? {};
        if (tData['fullName'] != null) {
          final fn = tData['fullName'].toString().toLowerCase().trim();
          _myTrainerNames.add(fn);
          for (final part in fn.split(' ')) {
            if (part.length > 1) {
              _myTrainerNames.add(part);
            }
          }
        }
        if (tData['name'] != null) {
          final n = tData['name'].toString().toLowerCase().trim();
          _myTrainerNames.add(n);
          for (final part in n.split(' ')) {
            if (part.length > 1) {
              _myTrainerNames.add(part);
            }
          }
        }
        if (tData['trainerId'] != null) {
          _myTrainerIds.add(tData['trainerId'].toString().trim());
        }
        if (tData['id'] != null) {
          _myTrainerIds.add(tData['id'].toString().trim());
        }
      }

      final allTrainersSnap =
          await FirebaseFirestore.instance.collection('trainers').get();
      for (var tDoc in allTrainersSnap.docs) {
        final tData = tDoc.data();
        final tEmail = (tData['email'] ?? '').toString().toLowerCase().trim();
        final tName =
            (tData['fullName'] ?? tData['name'] ?? '').toString().toLowerCase().trim();
        if ((user.email != null && tEmail == user.email!.toLowerCase().trim()) ||
            _myTrainerNames.contains(tName) ||
            tDoc.id == uid) {
          _myTrainerIds.add(tDoc.id);
          if (tData['trainerId'] != null) {
            _myTrainerIds.add(tData['trainerId'].toString().trim());
          }
          if (tData['id'] != null) {
            _myTrainerIds.add(tData['id'].toString().trim());
          }
          if (tName.isNotEmpty) {
            _myTrainerNames.add(tName);
            for (final part in tName.split(' ')) {
              if (part.length > 1) {
                _myTrainerNames.add(part);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading trainer identifiers: $e');
    }

    if (mounted) {
      setState(() => _identifiersLoaded = true);
    }
  }

  // Helper to format time (e.g. "09:00 AM")
  String _formatTime(DateTime time) {
    int hour = time.hour;
    int minute = time.minute;
    String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    String minStr = minute.toString().padLeft(2, '0');
    return '$hour:$minStr $ampm';
  }

  // Batch update to mark all as read in Firebase
  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> unreadDocs) async {
    if (unreadDocs.isEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadDocs) {
      batch.update(doc.reference, {
        'isRead': true,
        'read': true,
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final strings = languageService.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${strings['errorUpdatingNotifications'] ?? 'Error updating notifications:'} $e',
          ),
        ),
      );
    }
  }

  // Delete/Clear all notifications with confirmation
  Future<void> _clearAllNotifications(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) {
      return;
    }

    final strings = languageService.strings;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final textColor = Theme.of(ctx).colorScheme.onSurface;
        final subTextColor = Theme.of(ctx).colorScheme.onSurfaceVariant;
        final cardColor = Theme.of(ctx).cardColor;
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            strings['clearAll'] ?? 'Clear Notifications',
            style: GoogleFonts.workSans(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          content: Text(
            strings['clearConfirm'] ??
                'Are you sure you want to delete all notifications? This action cannot be undone.',
            style: GoogleFonts.workSans(
              color: subTextColor,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                strings['cancel'] ?? 'Cancel',
                style: GoogleFonts.workSans(
                  color: subTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                strings['clear'] ?? 'Clear',
                style: GoogleFonts.workSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in docs) {
      batch.delete(doc.reference);
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings['notificationsCleared'] ??
                  'Notifications cleared successfully.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing notifications: $e'),
          ),
        );
      }
    }
  }

  // Delete a single notification
  Future<void> _deleteSingleNotification(DocumentReference ref) async {
    try {
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: _BottomNav(currentIndex: 0, strings: strings),
      body: Column(
        children: [
          const _TopHeaderBand(),

          Expanded(
            child: _uid.isEmpty
                ? Center(
                    child: Text(
                      strings['loginToViewNotifications'] ??
                          "Please log in to view notifications.",
                      style: GoogleFonts.workSans(color: subTextColor),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !_identifiersLoaded) {
                        return Center(
                          child: CircularProgressIndicator(color: brandBlue),
                        );
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      final userEmail = FirebaseAuth.instance.currentUser?.email;
                      
                      // Filter docs matching trainer
                      final matchedDocs = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return TrainerNotificationsScreen.isNotificationForTrainer(
                          data: data,
                          uid: _uid,
                          userEmail: userEmail,
                          trainerIds: _myTrainerIds,
                          trainerNames: _myTrainerNames,
                        );
                      }).toList();

                      // Sort by createdAt descending
                      matchedDocs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        
                        dynamic aDate = aData['createdAt'] ?? aData['timestamp'] ?? aData['date'];
                        dynamic bDate = bData['createdAt'] ?? bData['timestamp'] ?? bData['date'];

                        DateTime aDt = DateTime.fromMillisecondsSinceEpoch(0);
                        DateTime bDt = DateTime.fromMillisecondsSinceEpoch(0);

                        if (aDate is Timestamp) {
                          aDt = aDate.toDate();
                        } else if (aDate is DateTime) {
                          aDt = aDate;
                        } else if (aDate is String) {
                          aDt = DateTime.tryParse(aDate) ?? aDt;
                        }

                        if (bDate is Timestamp) {
                          bDt = bDate.toDate();
                        } else if (bDate is DateTime) {
                          bDt = bDate;
                        } else if (bDate is String) {
                          bDt = DateTime.tryParse(bDate) ?? bDt;
                        }

                        return bDt.compareTo(aDt);
                      });

                      // Apply category filter
                      final filteredDocs = matchedDocs.where((doc) {
                        if (_selectedFilter == 'all') return true;
                        final data = doc.data() as Map<String, dynamic>;
                        final source = TrainerNotificationsScreen.getNotificationSource(data).toLowerCase();
                        return source == _selectedFilter;
                      }).toList();

                      final unreadDocs = matchedDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isRead = data['isRead'] == true || data['read'] == true;
                        return !isRead;
                      }).toList();

                      final unreadCount = unreadDocs.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),

                          // Title with Back Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: textColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  strings['notificationTitle'] ??
                                      'Notifications',
                                  style: GoogleFonts.workSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Category Filter Chips (All, Admin, Client)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: 'All (${matchedDocs.length})',
                                  filterKey: 'all',
                                  isSelected: _selectedFilter == 'all',
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: 'From Admin',
                                  filterKey: 'admin',
                                  isSelected: _selectedFilter == 'admin',
                                  badgeColor: primaryRed,
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: 'From Clients',
                                  filterKey: 'client',
                                  isSelected: _selectedFilter == 'client',
                                  badgeColor: cyanAccent,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Unread Pill, Mark All Read & Clear All Buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                // Unread Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryRed.withValues(
                                      alpha: 0.1,
                                    ), // Dynamic Light Red
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$unreadCount ${strings['unread'] ?? 'unread'}',
                                    style: GoogleFonts.workSans(
                                      color: primaryRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                                const Spacer(),

                                // Mark all read Button
                                if (unreadCount > 0) ...[
                                  GestureDetector(
                                    onTap: () => _markAllAsRead(unreadDocs),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        border: Border.all(color: dividerColor),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.done_all_rounded,
                                            size: 15,
                                            color: textColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            strings['markAllRead'] ??
                                                'Mark read',
                                            style: GoogleFonts.workSans(
                                              color: textColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // Clear All Button
                                if (matchedDocs.isNotEmpty)
                                  GestureDetector(
                                    onTap: () =>
                                        _clearAllNotifications(matchedDocs),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            primaryRed.withValues(alpha: 0.1),
                                        border: Border.all(
                                          color: primaryRed.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 15,
                                            color: primaryRed,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            strings['clearAll'] ?? 'Clear all',
                                            style: GoogleFonts.workSans(
                                              color: primaryRed,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Notifications List
                          Expanded(
                            child: filteredDocs.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.notifications_none_rounded,
                                          size: 54,
                                          color: subTextColor.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          strings['noNotificationsYet'] ??
                                              'No notifications yet.',
                                          style: GoogleFonts.workSans(
                                            color: subTextColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: dividerColor),
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: filteredDocs.length,
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                              color: dividerColor,
                                              height: 1,
                                            ),
                                        itemBuilder: (context, index) {
                                          final doc = filteredDocs[index];
                                          final data =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          return Dismissible(
                                            key: Key(doc.id),
                                            direction:
                                                DismissDirection.endToStart,
                                            background: Container(
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.only(
                                                right: 20,
                                              ),
                                              color: primaryRed.withValues(
                                                alpha: 0.15,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    strings['delete'] ??
                                                        'Delete',
                                                    style: GoogleFonts.workSans(
                                                      color: primaryRed,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.delete_outline_rounded,
                                                    color: primaryRed,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            onDismissed: (_) {
                                              _deleteSingleNotification(
                                                doc.reference,
                                              );
                                            },
                                            child: GestureDetector(
                                              onTap: () {
                                                if (data['isRead'] != true &&
                                                    data['read'] != true) {
                                                  doc.reference.update({
                                                    'isRead': true,
                                                    'read': true,
                                                  });
                                                }
                                              },
                                              child: _buildNotificationItem(
                                                data,
                                                strings,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 24), // Bottom padding
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    required bool isSelected,
    Color? badgeColor,
  }) {
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? brandBlue).withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (badgeColor ?? brandBlue)
                : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? (badgeColor ?? brandBlue) : subTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    Map<String, dynamic> data,
    Map<String, String> strings,
  ) {
    final title =
        data['title'] ?? (strings['notificationTitle'] ?? 'Notification');
    final body = data['body'] ?? data['message'] ?? '';
    final isRead = !TrainerNotificationsScreen.isNotificationUnread(data);
    final source = TrainerNotificationsScreen.getNotificationSource(data);
    final isAdmin = source == 'Admin';

    dynamic rawDate = data['createdAt'] ?? data['timestamp'] ?? data['date'] ?? data['time'];
    DateTime? dt;
    if (rawDate is Timestamp) {
      dt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      dt = rawDate;
    } else if (rawDate is String) {
      dt = DateTime.tryParse(rawDate);
    }
    final timeStr = dt != null ? _formatTime(dt) : '';

    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final iconBgColor = isAdmin
        ? primaryRed.withValues(alpha: 0.15)
        : cyanAccent.withValues(alpha: 0.15);
    final iconColor = isAdmin ? primaryRed : cyanAccent;
    final iconData = isAdmin
        ? Icons.admin_panel_settings_outlined
        : Icons.person_outline_rounded;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),

          const SizedBox(width: 12),

          // Unread Dot (Red circle)
          if (!isRead) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: primaryRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? primaryRed.withValues(alpha: 0.12)
                            : cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAdmin ? 'ADMIN' : 'CLIENT',
                        style: GoogleFonts.workSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isAdmin ? primaryRed : cyanAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timeStr,
                  style: GoogleFonts.workSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// HEADER AND NAVIGATION WIDGETS
// ---------------------------------------------------------

class _TopHeaderBand extends StatelessWidget {
  const _TopHeaderBand();

  @override
  Widget build(BuildContext context) {
    final textShadow = Shadow(
      color: Colors.black.withValues(alpha: 0.4),
      offset: const Offset(1.5, 1.5),
      blurRadius: 3,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic Brand Blue
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Logo acts as back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Image.asset(
                'assets/images/landing_photo.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'JoE',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: _KettlebellIcon(size: 18),
                    ),
                  ),
                  TextSpan(
                    text: 'V ',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                  TextSpan(
                    text: 'FITNESS',
                    style: GoogleFonts.workSans(
                      color: _TrainerNotificationsScreenState.primaryRed,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [textShadow],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 38,
              height: 38,
              // Light Cyan Background to show it is active
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.strings});

  final int currentIndex;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home, strings['home'] ?? 'Home'),
      (
        Icons.calendar_today_outlined,
        Icons.calendar_today,
        strings['schedules'] ?? 'Schedules',
      ),
      (Icons.group_outlined, Icons.group, strings['users'] ?? 'Users'),
      (
        Icons.description_outlined,
        Icons.description,
        strings['notes'] ?? 'Notes',
      ),
      (Icons.person_outline, Icons.person, strings['profile'] ?? 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Dynamic Brand Blue
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Theme.of(
          context,
        ).colorScheme.secondary, // Dynamic cyan
        unselectedItemColor: Colors.white,
        selectedLabelStyle: GoogleFonts.workSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.workSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(item.$1, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(item.$2, size: 24),
              ),
              label: item.$3,
            ),
        ],
        onTap: (index) {
          TrainerMainScreen.switchTab(context, index);
        },
      ),
    );
  }
}

class _KettlebellIcon extends StatelessWidget {
  const _KettlebellIcon({this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _KettlebellPainter()),
  );
}

class _KettlebellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final double w = size.width, h = size.height;
    final Path handle = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.25, h * 0.05, w * 0.75, h * 0.5),
          Radius.circular(w * 0.2),
        ),
      );
    final Path body = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.5, h * 0.65), radius: w * 0.35),
      );
    Path k = Path.combine(PathOperation.union, handle, body);
    k = Path.combine(
      PathOperation.difference,
      k,
      Path()..addRect(Rect.fromLTRB(0, h * 0.94, w, h)),
    );
    k = Path.combine(
      PathOperation.difference,
      k,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.40, h * 0.20, w * 0.60, h * 0.45),
          Radius.circular(w * 0.1),
        ),
      ),
    );
    canvas.drawPath(k.shift(const Offset(1.5, 1.5)), shadowPaint);
    canvas.drawPath(k, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
