import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import the sub-screens for adding and editing notes
import 'add_visit_note_screen.dart';
import 'edit_visit_note_screen.dart';

import '../../services/language_service.dart';
import '../home/trainer_main_screen.dart';

import '../../services/trainer_data_service.dart';

class TrainerNotesScreen extends StatefulWidget {
  final bool isEmbeddedInShell;
  const TrainerNotesScreen({super.key, this.isEmbeddedInShell = false});

  @override
  State<TrainerNotesScreen> createState() => _TrainerNotesScreenState();
}

class _TrainerNotesScreenState extends State<TrainerNotesScreen>
    with AutomaticKeepAliveClientMixin {
  // 0: Add notes, 1: Past notes
  int _selectedTab = 0;

  @override
  bool get wantKeepAlive => true;

  bool _isLoadingClients = true;
  List<Map<String, dynamic>> _clients = [];

  // Search controller for past notes
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Rotating colors for client avatars (Kept static for consistent visual identity)
  final List<Map<String, Color>> _avatarColors = [
    {
      'bg': const Color(0xFFF3E8FF),
      'text': const Color(0xFF6B21A8),
    }, // Light Purple
    {
      'bg': const Color(0xFFFFEDD5),
      'text': const Color(0xFFC2410C),
    }, // Light Orange
    {
      'bg': const Color(0xFFDBEAFE),
      'text': const Color(0xFF1D4ED8),
    }, // Light Blue
    {
      'bg': const Color(0xFFFEE2E2),
      'text': const Color(0xFFB91C1C),
    }, // Light Red
    {
      'bg': const Color(0xFFDCFCE7),
      'text': const Color(0xFF166534),
    }, // Light Green
  ];

  @override
  void initState() {
    super.initState();
    if (TrainerDataService().isInitialized) {
      _parseFromCache();
      _fetchClients(showSpinner: false);
    } else {
      _fetchClients(showSpinner: true);
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _parseFromCache() {
    final cache = TrainerDataService();
    if (!cache.isInitialized) return;
    _processDocs(
      cache.myTrainerIds,
      cache.myTrainerNames,
      cache.allUsersDocs,
      cache.allTrainersDocs,
      cache.allSessionsDocs,
      cache.allBookingsDocs,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> _myTrainerIds = {};
  Set<String> _myTrainerNames = {};



  Future<void> _fetchClients({bool showSpinner = true, bool force = false}) async {
    if (showSpinner && _clients.isEmpty) {
      if (mounted) setState(() => _isLoadingClients = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingClients = false);
      return;
    }

    try {
      final cache = TrainerDataService();
      if (!cache.isInitialized) {
        await cache.preloadAll(notify: false);
      } else if (force) {
        await cache.preloadAll(notify: false, force: true);
      } else {
        cache.preloadAll(notify: false, force: true).then((_) {
          if (mounted) _parseFromCache();
        });
      }
      _parseFromCache();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingClients = false);
      }
    }
  }

  void _processDocs(
    Set<String> myTrainerIds,
    Set<String> myTrainerNames,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> usersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allTrainersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingsDocs,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    // 1. Discover all clients belonging to this trainer (assigned, booked, sessions, or completed)
    final Set<String> relatedClientIds = {};
    for (var bDoc in bookingsDocs) {
      final bData = bDoc.data();
      final bTrainerId = (bData['trainerId'] ?? bData['assignedTrainerId'] ?? '').toString().trim();
      final bTrainerName = (bData['trainerName'] ?? bData['trainer'] ?? '').toString().toLowerCase().trim();
      final bClientId = (bData['clientId'] ?? bData['userId'] ?? '').toString().trim();
      if (bClientId.isEmpty) continue;

      bool isMyBooking = (bTrainerId.isNotEmpty && myTrainerIds.contains(bTrainerId)) ||
          (bTrainerName.isNotEmpty && myTrainerNames.any((n) => n.isNotEmpty && (bTrainerName == n || bTrainerName.contains(n) || n.contains(bTrainerName)))) ||
          (allTrainersDocs.length == 1);

      if (isMyBooking) {
        relatedClientIds.add(bClientId);
      }
    }

    for (var sDoc in sessionsDocs) {
      final sData = sDoc.data();
      final sTrainerId = (sData['trainerId'] ?? sData['assignedTrainerId'] ?? '').toString().trim();
      final sTrainerName = (sData['trainerName'] ?? sData['trainer'] ?? '').toString().toLowerCase().trim();
      final sClientId = (sData['clientId'] ?? sData['userId'] ?? '').toString().trim();
      if (sClientId.isEmpty) continue;

      bool isMySession = (sTrainerId.isNotEmpty && myTrainerIds.contains(sTrainerId)) ||
          (sTrainerName.isNotEmpty && myTrainerNames.any((n) => n.isNotEmpty && (sTrainerName == n || sTrainerName.contains(n) || n.contains(sTrainerName)))) ||
          (allTrainersDocs.length == 1);

      if (isMySession) {
        relatedClientIds.add(sClientId);
      }
    }

    // 2. Process users and include all clients assigned to or associated with this trainer
    List<Map<String, dynamic>> fetchedClients = [];
    final strings = languageService.strings;

    for (int i = 0; i < usersDocs.length; i++) {
      final doc = usersDocs[i];
      final data = doc.data();
      if (doc.id == uid) continue;
      final role = (data['role'] ?? '').toString().toLowerCase();
      if (role == 'trainer' || role == 'admin') continue;

      final assignedId = (data['assignedTrainerId'] ?? data['trainerId'] ?? data['assignedTrainer'] ?? '').toString().trim();
      final assignedName = (data['assignedTrainerName'] ?? data['assignedTrainer'] ?? '').toString().toLowerCase().trim();

      bool isMyClient = false;
      if (assignedId.isNotEmpty && myTrainerIds.contains(assignedId)) {
        isMyClient = true;
      } else if (assignedName.isNotEmpty && myTrainerNames.any((n) => n.isNotEmpty && (assignedName == n || assignedName.contains(n) || n.contains(assignedName)))) {
        isMyClient = true;
      } else if (relatedClientIds.contains(doc.id)) {
        isMyClient = true;
      } else if (allTrainersDocs.length == 1) {
        isMyClient = true;
      }

      if (!isMyClient) continue;

      final fullName = (data['fullName'] ?? data['name'] ?? (strings['unknownClient'] ?? 'Unknown Client')).toString();
      final firstName = fullName.trim().split(' ').first;

      final parts = fullName.trim().split(' ');
      String initials = '';
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials += parts[0][0];
        if (parts.length > 1 && parts.last.isNotEmpty) {
          initials += parts.last[0];
        }
      }
      initials = initials.toUpperCase();
      if (initials.isEmpty) initials = '?';

      final package = data['package']?.toString() ?? data['plan']?.toString() ?? 'Standard';
      final goal = data['goal']?.toString() ?? data['fitnessGoal']?.toString() ?? 'Fitness';
      final details = '$package · $goal';

      final photoUrl = data['photoURL']?.toString() ?? data['photoUrl']?.toString() ?? data['profileImage']?.toString() ?? data['image']?.toString();
      final colorTheme = _avatarColors[fetchedClients.length % _avatarColors.length];

      fetchedClients.add({
        'id': doc.id,
        'name': firstName,
        'fullName': fullName,
        'initials': initials,
        'photoUrl': photoUrl,
        'details': details,
        'bgColor': colorTheme['bg'],
        'textColor': colorTheme['text'],
      });
    }

    if (mounted) {
      setState(() {
        _myTrainerIds = myTrainerIds;
        _myTrainerNames = myTrainerNames;
        _clients = fetchedClients;
        _isLoadingClients = false;
      });
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
    super.build(context);
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final dividerColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: widget.isEmbeddedInShell
          ? null
          : _BottomNav(currentIndex: 3, strings: strings),
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
            strings['selectClients'] ?? 'Select Client',
            style: GoogleFonts.workSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _isLoadingClients
              ? Center(
                  child: CircularProgressIndicator(
                    color: brandBlue,
                    strokeWidth: 3,
                  ),
                )
              : _clients.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: subTextColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings['noClientsAssigned'] ??
                              'No clients assigned to you yet.',
                          style: GoogleFonts.workSans(
                            color: subTextColor,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: _clients.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddVisitNoteScreen(
                              clientId: client['id'],
                              clientName: client['fullName'] ?? client['name'],
                              clientInitials: client['initials'],
                              bgColor: client['bgColor'],
                              textColor: client['textColor'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dividerColor, width: 1.0),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: client['bgColor'],
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: client['photoUrl'] != null &&
                                        client['photoUrl'].toString().isNotEmpty
                                    ? Image.network(
                                        client['photoUrl'],
                                        fit: BoxFit.cover,
                                        width: 46,
                                        height: 46,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          color: client['bgColor'],
                                          alignment: Alignment.center,
                                          child: Text(
                                            client['initials'],
                                            style: GoogleFonts.workSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: client['textColor'],
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: client['bgColor'],
                                        alignment: Alignment.center,
                                        child: Text(
                                          client['initials'],
                                          style: GoogleFonts.workSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: client['textColor'],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    client['fullName'] ?? client['name'],
                                    style: GoogleFonts.workSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    client['details'] ?? 'Assigned Client',
                                    style: GoogleFonts.workSans(
                                      fontSize: 12,
                                      color: subTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC7001A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Color(0xFFC7001A),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    strings['addNote'] ?? 'Add Note',
                                    style: GoogleFonts.workSans(
                                      color: const Color(0xFFC7001A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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

              // Filter results based on trainerId and search query
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final noteTrainerId = (data['trainerId'] ?? '').toString().trim();
                final noteTrainerName = (data['trainerName'] ?? '').toString().toLowerCase().trim();

                bool isMyNote = noteTrainerId == uid ||
                    _myTrainerIds.contains(noteTrainerId) ||
                    (_myTrainerNames.isNotEmpty && noteTrainerName.isNotEmpty && _myTrainerNames.any((n) => n.isNotEmpty && (noteTrainerName == n || noteTrainerName.contains(n)))) ||
                    (_myTrainerIds.length == 1);

                if (!isMyNote) return false;

                final clientName = (data['clientName'] ?? '').toString().toLowerCase();
                return clientName.contains(_searchQuery);
              }).toList();

              // Sort by createdAt descending
              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['createdAt'];
                final bTime = (b.data() as Map<String, dynamic>)['createdAt'];
                DateTime aDate = aTime is Timestamp ? aTime.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                DateTime bDate = bTime is Timestamp ? bTime.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });

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
