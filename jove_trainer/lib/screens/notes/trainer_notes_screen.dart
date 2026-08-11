import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jove_trainer/screens/profile/trainer_profile_screen.dart';

// Import your other screens for the bottom navigation to work
import '../home/trainer_home_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import '../users/trainer_users_screen.dart';
// Import the sub-screens for adding and editing notes
import 'add_visit_note_screen.dart';
import 'edit_visit_note_screen.dart';

// ---> NEW: IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class TrainerNotesScreen extends StatefulWidget {
  const TrainerNotesScreen({super.key});

  @override
  State<TrainerNotesScreen> createState() => _TrainerNotesScreenState();
}

class _TrainerNotesScreenState extends State<TrainerNotesScreen> {
  // 0: Add notes, 1: Past notes
  int _selectedTab = 0;

  bool _isLoadingClients = true;
  List<Map<String, dynamic>> _clients = [];

  // Search controller for past notes
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Rotating colors for client avatars (Kept static for consistent visual identity)
  final List<Map<String, Color>> _avatarColors = [
    {
      'bg': const Color(0xFFE0E7FF),
      'text': const Color(0xFF3730A3),
    }, // Light Indigo
    {
      'bg': const Color(0xFFF3E8FF),
      'text': const Color(0xFF6B21A8),
    }, // Light Purple
    {
      'bg': const Color(0xFFFEE2E2),
      'text': const Color(0xFF991B1B),
    }, // Light Red
    {
      'bg': const Color(0xFFDCFCE7),
      'text': const Color(0xFF166534),
    }, // Light Green
  ];

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoadingClients = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoadingClients = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('trainerId', isEqualTo: uid)
          .get();

      List<Map<String, dynamic>> fetchedClients = [];
      final strings = languageService.strings; // Fetch language map

      for (int i = 0; i < snap.docs.length; i++) {
        final doc = snap.docs[i];
        final data = doc.data();
        final name =
            data['fullName'] ??
            data['name'] ??
            (strings['unknownClient'] ?? 'Unknown Client');

        // Use just the first name for the UI chip
        final firstName = name.trim().split(' ').first;

        // Generate Initials
        final parts = name.trim().split(' ');
        String initials = '';
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          initials += parts[0][0];
          if (parts.length > 1 && parts.last.isNotEmpty) {
            initials += parts.last[0];
          }
        }
        initials = initials.toUpperCase();
        if (initials.isEmpty) {
          initials = '?';
        }

        // Pick a color theme based on the index
        final colorTheme = _avatarColors[i % _avatarColors.length];

        fetchedClients.add({
          'id': doc.id,
          'name': firstName,
          'initials': initials,
          'bgColor': colorTheme['bg'],
          'textColor': colorTheme['text'],
        });
      }

      if (mounted) {
        setState(() {
          _clients = fetchedClients;
          _isLoadingClients = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      if (mounted) {
        setState(() {
          _isLoadingClients = false;
        });
      }
    }
  }

  // --- Helper to format date like "Wed 25 Jun" ---
  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  // --- Check if trainer is allowed to edit (24-hour rule) ---
  void _attemptEdit(
    BuildContext context,
    Map<String, dynamic> noteData,
    String noteId,
    DateTime createdAt,
  ) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final strings = languageService.strings; // Fetch language strings

    if (difference.inHours >= 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings['editLocked'] ??
                'Edit Locked: This note is older than 24 hours. Only admins can edit it now.',
            style: GoogleFonts.workSans(),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EditVisitNoteScreen(noteId: noteId, noteData: noteData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final dividerColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: _BottomNav(currentIndex: 3, strings: strings),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TopHeaderBand(),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Screen Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    strings['visitNotes'] ?? 'Visit Notes',
                    style: GoogleFonts.workSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Toggle Switch (Add notes / Past notes)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: dividerColor.withValues(
                        alpha: 0.3,
                      ), // Adapts to theme
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: strings['addNotes'] ?? 'Add notes',
                            icon: Icons.edit_note_rounded,
                            isSelected: _selectedTab == 0,
                            onTap: () => setState(() {
                              _selectedTab = 0;
                              _searchController.clear();
                            }),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: strings['pastNotes'] ?? 'Past notes',
                            icon: Icons.history_rounded,
                            isSelected: _selectedTab == 1,
                            onTap: () => setState(() {
                              _selectedTab = 1;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Content Area based on Tab Selection
                Expanded(
                  child: _selectedTab == 0
                      ? _buildAddNotesView(strings)
                      : _buildPastNotesView(strings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ADD NOTES VIEW ---
  Widget _buildAddNotesView(Map<String, String> strings) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            strings['selectClients'] ?? 'Select Clients',
            style: GoogleFonts.workSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal Client List
        SizedBox(
          height: 48,
          child: _isLoadingClients
              ? Center(
                  child: CircularProgressIndicator(
                    color: brandBlue,
                    strokeWidth: 3,
                  ),
                )
              : _clients.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    strings['noClientsFound'] ?? 'No clients found.',
                    style: GoogleFonts.workSans(
                      color: subTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: _clients.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final client = _clients[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddVisitNoteScreen(
                              clientId: client['id'],
                              clientName: client['name'],
                              clientInitials: client['initials'],
                              bgColor: client['bgColor'],
                              textColor: client['textColor'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: dividerColor, width: 1.0),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: client['bgColor'],
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                client['initials'],
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: client['textColor'],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              client['name'],
                              style: GoogleFonts.workSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- PAST NOTES VIEW ---
  Widget _buildPastNotesView(Map<String, String> strings) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox();
    }

    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.workSans(
              fontSize: 14,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: strings['filterByClient'] ?? 'Filter by client name...',
              hintStyle: GoogleFonts.workSans(
                color: subTextColor,
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search, color: subTextColor),
              filled: true,
              fillColor: cardColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: dividerColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: brandBlue, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Firebase Stream
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('visit_notes')
                .where('trainerId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: brandBlue),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    strings['noPastNotes'] ?? 'No past notes found.',
                    style: GoogleFonts.workSans(color: subTextColor),
                  ),
                );
              }

              // Filter results based on search query
              final docs = snapshot.data!.docs.where((doc) {
                final clientName = doc['clientName'].toString().toLowerCase();
                return clientName.contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    strings['noMatchingNotes'] ?? 'No matching notes.',
                    style: GoogleFonts.workSans(color: subTextColor),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                itemCount: docs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final clientName =
                      data['clientName'] ??
                      (strings['unknownClient'] ?? 'Unknown');

                  // Generate Initials
                  final parts = clientName.toString().trim().split(' ');
                  String initials = 'U';
                  if (parts.isNotEmpty && parts.first.isNotEmpty) {
                    initials = parts.first[0];
                    if (parts.length > 1 && parts.last.isNotEmpty) {
                      initials += parts.last[0];
                    }
                  }

                  // Date Handling
                  final Timestamp? t = data['createdAt'];
                  final DateTime createdAt = t?.toDate() ?? DateTime.now();

                  // Combine texts for display
                  String notePreview = "";
                  if (data['exercisesPerformed'] != null &&
                      data['exercisesPerformed'].toString().isNotEmpty) {
                    notePreview += "${data['exercisesPerformed']} ";
                  }
                  if (data['observation'] != null &&
                      data['observation'].toString().isNotEmpty) {
                    notePreview += "${data['observation']} ";
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dividerColor, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Dark Red Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B0000),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials.toUpperCase(),
                                style: GoogleFonts.workSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
                                    style: GoogleFonts.workSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(createdAt),
                                    style: GoogleFonts.workSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Edit Icon
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: brandBlue,
                                size: 20,
                              ),
                              onPressed: () => _attemptEdit(
                                context,
                                data,
                                doc.id,
                                createdAt,
                              ),
                            ),
                          ],
                        ),
                        if (notePreview.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            notePreview.trim(),
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: textColor.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// COMPONENT WIDGETS
// ---------------------------------------------------------

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final brandBlue = Theme.of(context).colorScheme.primary;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? brandBlue : subTextColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? brandBlue : subTextColor,
                ),
              ),
            ),
          ],
        ),
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
    final whiteTitleStyle = GoogleFonts.workSans(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: [textShadow],
    );
    final redTitleStyle = GoogleFonts.workSans(
      color: const Color(0xFFC7001A),
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: [textShadow],
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
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
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
                  TextSpan(text: 'JoE', style: whiteTitleStyle),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: _KettlebellIcon(size: 18),
                    ),
                  ),
                  TextSpan(text: 'V ', style: whiteTitleStyle),
                  TextSpan(text: 'FITNESS', style: redTitleStyle),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white, // Kept white to pop on blue background
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
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerHomeScreen()),
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerSchedulesScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerUsersScreen()),
            );
          } else if (index == 3) {
            // Already on Notes
          } else if (index == 4) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerProfileScreen()),
            );
          }
        },
      ),
    );
  }
}

class _KettlebellIcon extends StatelessWidget {
  const _KettlebellIcon({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KettlebellPainter()),
    );
  }
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
    final double w = size.width;
    final double h = size.height;
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
    Path kettlebell = Path.combine(PathOperation.union, handle, body);
    final Path bottomCut = Path()..addRect(Rect.fromLTRB(0, h * 0.94, w, h));
    kettlebell = Path.combine(PathOperation.difference, kettlebell, bottomCut);
    final Path hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.40, h * 0.20, w * 0.60, h * 0.45),
          Radius.circular(w * 0.1),
        ),
      );
    kettlebell = Path.combine(PathOperation.difference, kettlebell, hole);
    canvas.drawPath(kettlebell.shift(const Offset(1.5, 1.5)), shadowPaint);
    canvas.drawPath(kettlebell, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
