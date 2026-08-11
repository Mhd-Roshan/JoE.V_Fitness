import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'session_history_tab.dart';
import 'health_info_tab.dart';
import '../home/trainer_home_screen.dart';
import '../schedules/trainer_schedules_screen.dart';
import 'trainer_users_screen.dart';
import '../notes/trainer_notes_screen.dart';
import '../profile/trainer_profile_screen.dart';

// ---> IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class TrainerUserProfileScreen extends StatefulWidget {
  final String clientId;

  const TrainerUserProfileScreen({super.key, required this.clientId});

  @override
  State<TrainerUserProfileScreen> createState() =>
      _TrainerUserProfileScreenState();
}

class _TrainerUserProfileScreenState extends State<TrainerUserProfileScreen> {
  bool _loading = true;
  int _selectedTab = 0; // 0: Overview, 1: Sessions, 2: Health info
  String _activeFilterKey = 'allTime';

  // Fetched Data
  String _fullName = '—';
  String? _photoUrl;
  String _status = 'inactive';
  String _packageName = '—';
  double? _currentWeightKg;
  double? _startWeightKg;
  double? _heightCm;
  int? _dailySteps;
  double? _waterL;
  double? _sleepHours;
  int? _age;
  String _goal = '—';
  String _area = '—';
  int _totalSessions = 0;

  // Semantic Colors (Stay the same across themes)
  static const Color cyanAccent = Color(0xFF01BCE3);
  static const Color greenText = Color(0xFF17CC1A);
  static const Color progressSteps = Color(0xFF01BCE3);
  static const Color progressWater = Color(0xFF2E51A2);
  static const Color progressSleep = Color(0xFFA932B2);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .get();
      final userData = userSnap.data() ?? {};

      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('clientProfile')
          .doc(widget.clientId)
          .get();
      final profileData = profileSnap.data() ?? {};

      final subsSnap = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('clientId', isEqualTo: widget.clientId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      final subData = subsSnap.docs.isNotEmpty
          ? subsSnap.docs.first.data()
          : <String, dynamic>{};

      Query progressQuery = FirebaseFirestore.instance
          .collection('progressLogs')
          .doc(widget.clientId)
          .collection('entries')
          .orderBy('createdAt', descending: true);

      if (_activeFilterKey == 'last7Days') {
        final cutOff = DateTime.now().subtract(const Duration(days: 7));
        progressQuery = progressQuery.where(
          'createdAt',
          isGreaterThanOrEqualTo: cutOff,
        );
      } else if (_activeFilterKey == 'last30Days') {
        final cutOff = DateTime.now().subtract(const Duration(days: 30));
        progressQuery = progressQuery.where(
          'createdAt',
          isGreaterThanOrEqualTo: cutOff,
        );
      }

      final progressSnap = await progressQuery.limit(1).get();
      final latestProgress = progressSnap.docs.isNotEmpty
          ? progressSnap.docs.first.data() as Map<String, dynamic>
          : <String, dynamic>{};

      final sessionsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('clientId', isEqualTo: widget.clientId)
          .get();

      int filteredSessionCount = 0;
      if (_activeFilterKey == 'allTime') {
        filteredSessionCount = sessionsSnap.docs.length;
      } else {
        DateTime cutOff = _activeFilterKey == 'last7Days'
            ? DateTime.now().subtract(const Duration(days: 7))
            : DateTime.now().subtract(const Duration(days: 30));

        for (var doc in sessionsSnap.docs) {
          final data = doc.data();
          Timestamp? ts =
              data['date'] ?? data['createdAt'] ?? data['startTime'];
          if (ts != null && ts.toDate().isAfter(cutOff)) {
            filteredSessionCount++;
          }
        }
      }

      int? age;
      final dobStr = profileData['dob'] as String?;
      if (dobStr != null) {
        final dob = DateTime.tryParse(dobStr);
        if (dob != null) {
          final now = DateTime.now();
          age = now.year - dob.year;
          if (now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day)) {
            age -= 1;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _fullName = userData['fullName'] ?? 'Unknown Client';
        _photoUrl = userData['photoURL'];
        _status = subData['status'] ?? 'inactive';
        _packageName = subData['packageName'] ?? '—';
        _currentWeightKg = (latestProgress['weightKg'] as num?)?.toDouble();
        _startWeightKg = (profileData['startWeightKg'] as num?)?.toDouble();
        _heightCm =
            (profileData['heightCm'] as num?)?.toDouble() ??
            (profileData['startHeightCm'] as num?)?.toDouble();
        _dailySteps = (latestProgress['steps'] as num?)?.toInt();
        _waterL = (latestProgress['waterL'] as num?)?.toDouble();
        _sleepHours = (latestProgress['sleepHours'] as num?)?.toDouble();
        _age = age;
        _goal = profileData['primaryGoal'] ?? '—';
        _area = profileData['location'] ?? '—';
        _totalSessions = filteredSessionCount;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Client profile load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- FILTER UI BOTTOM SHEET ---
  void _showFilterOptions(Map<String, String> strings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(
        context,
      ).cardColor, // Dynamic Bottom Sheet Color
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings['filterDataBy'] ?? 'Filter Data By',
                style: GoogleFonts.workSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: Theme.of(context).dividerColor),
              _filterTile('allTime', strings['allTime'] ?? 'All Time'),
              _filterTile('last7Days', strings['last7Days'] ?? 'Last 7 Days'),
              _filterTile(
                'last30Days',
                strings['last30Days'] ?? 'Last 30 Days',
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _filterTile(String filterKey, String displayName) {
    bool isSelected = _activeFilterKey == filterKey;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? cyanAccent : subTextColor,
      ),
      title: Text(
        displayName,
        style: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
        ),
      ),
      onTap: () {
        setState(() => _activeFilterKey = filterKey);
        Navigator.pop(context);
        _loadData();
      },
    );
  }

  // Helpers
  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '—';
    final first = parts.first[0];
    final second = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0]
        : '';
    return (first + second).toUpperCase();
  }

  String _fmt(double? val) => val == null
      ? '—'
      : (val == val.toInt() ? val.toInt().toString() : val.toStringAsFixed(1));

  double get _stepPercent => ((_dailySteps ?? 0) / 10000).clamp(0.0, 1.0);
  double get _waterPercent => ((_waterL ?? 0) / 4.0).clamp(0.0, 1.0);
  double get _sleepPercent => ((_sleepHours ?? 0) / 8.0).clamp(0.0, 1.0);

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
      bottomNavigationBar: _BottomNav(
        currentIndex: 2, // Index 2 is Users
        strings: strings,
      ),
      body: Column(
        children: [
          const _TopHeaderBand(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: brandBlue))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: cyanAccent,
                    backgroundColor: cardColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // Back Button, Title & FILTER BUTTON
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                  strings['userProfile'] ?? 'User Profile',
                                  style: GoogleFonts.workSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _showFilterOptions(strings),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: dividerColor),
                                    ),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      color: textColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Profile Avatar
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: brandBlue,
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? Image.network(
                                          _photoUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: dividerColor,
                                          alignment: Alignment.center,
                                          child: Text(
                                            _initials,
                                            style: GoogleFonts.workSans(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              // Status Dot
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color:
                                        cardColor, // Frame matches background
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: bgColor,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _status == 'active'
                                          ? cyanAccent
                                          : subTextColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Name
                          Text(
                            _fullName,
                            style: GoogleFonts.workSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Status & Package
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.workSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              children: [
                                TextSpan(
                                  text: _status == 'active'
                                      ? (strings['activeNow'] ?? 'ACTIVE NOW')
                                      : _status.toUpperCase(),
                                  style: TextStyle(
                                    color: _status == 'active'
                                        ? greenText
                                        : subTextColor,
                                  ),
                                ),
                                TextSpan(
                                  text: '  •  ',
                                  style: TextStyle(color: subTextColor),
                                ),
                                TextSpan(
                                  text: _packageName,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          // Tag showing the active filter
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${strings['showing'] ?? 'Showing:'} ${strings[_activeFilterKey] ?? 'Filter'}",
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cyanAccent,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Stats Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: strings['weightCaps'] ?? 'WEIGHT',
                                    value: _fmt(_currentWeightKg),
                                    unit: 'kg',
                                    isHighlighted: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    title: strings['heightCaps'] ?? 'HEIGHT',
                                    value: _fmt(_heightCm),
                                    unit: 'cm',
                                    isHighlighted: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    title:
                                        strings['sessions']?.toUpperCase() ??
                                        'SESSIONS',
                                    value: '$_totalSessions',
                                    unit: strings['total'] ?? 'Total',
                                    isHighlighted: false,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Tab Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: dividerColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TabButton(
                                      label: strings['overview'] ?? 'Overview',
                                      isSelected: _selectedTab == 0,
                                      onTap: () =>
                                          setState(() => _selectedTab = 0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TabButton(
                                      label: strings['sessions'] ?? 'Sessions',
                                      isSelected: _selectedTab == 1,
                                      onTap: () =>
                                          setState(() => _selectedTab = 1),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TabButton(
                                      label:
                                          strings['healthInfo'] ??
                                          'Health info',
                                      isSelected: _selectedTab == 2,
                                      onTap: () =>
                                          setState(() => _selectedTab = 2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Tab Content
                          if (_selectedTab == 0) _buildOverviewTab(strings),
                          if (_selectedTab == 1)
                            SessionHistoryTab(clientId: widget.clientId),
                          if (_selectedTab == 2)
                            HealthInfoTab(clientId: widget.clientId),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, String> strings) {
    final weightDelta = (_currentWeightKg != null && _startWeightKg != null)
        ? _currentWeightKg! - _startWeightKg!
        : null;

    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // PROGRESS CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings['progress'] ?? 'Progress',
                  style: GoogleFonts.workSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Weight Progress Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        strings['weight'] ?? 'Weight',
                        style: GoogleFonts.workSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: subTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            color: textColor,
                          ),
                          children: [
                            TextSpan(
                              text: '${_fmt(_currentWeightKg)}kg ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_startWeightKg != null)
                              TextSpan(
                                text:
                                    '(${strings['startWord'] ?? 'start'} ${_fmt(_startWeightKg)} kg)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: subTextColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        weightDelta == null || weightDelta == 0
                            ? '—'
                            : (weightDelta > 0
                                  ? '⬆ ${_fmt(weightDelta.abs())} kg'
                                  : '⬇ ${_fmt(weightDelta.abs())} kg'),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (weightDelta != null && weightDelta <= 0)
                              ? greenText
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['dailySteps'] ?? 'Daily steps',
                  value: _dailySteps != null ? '$_dailySteps' : '—',
                  percent: _stepPercent,
                  color: progressSteps,
                ),
                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['waterL'] ?? 'Water (L)',
                  value: _waterL != null ? '${_fmt(_waterL)}L' : '—',
                  percent: _waterPercent,
                  color: progressWater,
                ),
                const SizedBox(height: 16),
                _ProgressBarRow(
                  label: strings['sleepH'] ?? 'Sleep (H)',
                  value: _sleepHours != null ? '${_fmt(_sleepHours)}h' : '—',
                  percent: _sleepPercent,
                  color: progressSleep,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // DETAILS CARD
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 1.5),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: strings['age'] ?? 'Age',
                  value: _age != null
                      ? '$_age ${strings['yrs'] ?? 'yrs'}'
                      : '—',
                ),
                _DetailRow(
                  label: strings['weight'] ?? 'Weight',
                  value: _currentWeightKg != null
                      ? '${_fmt(_currentWeightKg)}\nkg'
                      : '—',
                  multiLineValue: true,
                ),
                _DetailRow(
                  label: strings['startWeight'] ?? 'Start weight',
                  value: _startWeightKg != null
                      ? '${_fmt(_startWeightKg)} kg'
                      : '—',
                ),
                _DetailRow(
                  label: strings['startHeight'] ?? 'Start height',
                  value: _heightCm != null ? '${_fmt(_heightCm)} cm' : '—',
                ),
                _DetailRow(label: strings['goal'] ?? 'Goal', value: _goal),
                _DetailRow(
                  label: strings['area'] ?? 'Area',
                  value: _area,
                  hideBorder: true,
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
// COMPONENT WIDGETS
// ---------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.isHighlighted,
  });
  final String title;
  final String value;
  final String unit;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Smart colors for Dark and Light mode
    Color bg = isHighlighted
        ? (isDark
              ? const Color(0xFF01BCE3).withValues(alpha: 0.15)
              : const Color(0xFFA5C4F2))
        : (isDark ? Theme.of(context).cardColor : const Color(0xFF00225D));

    Color border = isHighlighted
        ? Colors.transparent
        : (isDark ? Theme.of(context).dividerColor : Colors.transparent);

    Color textCol = isHighlighted
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;

    Color subTextCol = isHighlighted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: (isHighlighted || isDark)
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.workSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subTextCol,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.workSans(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: textCol,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: GoogleFonts.workSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: subTextCol,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
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
        child: Text(
          label,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            color: isSelected ? textColor : subTextColor,
          ),
        ),
      ),
    );
  }
}

class _ProgressBarRow extends StatelessWidget {
  const _ProgressBarRow({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });
  final String label;
  final String value;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.workSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.hideBorder = false,
    this.multiLineValue = false,
  });
  final String label;
  final String value;
  final bool hideBorder;
  final bool multiLineValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: hideBorder
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.5,
                ),
              ),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: multiLineValue
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.workSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              height: multiLineValue ? 1.2 : 1,
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
        color: Theme.of(context).primaryColor, // Dynamic Header Color
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
            child: Image.asset(
              'assets/images/landing_photo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
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
                color: Colors.white, // Always white on header
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
        color: Theme.of(context).primaryColor, // Dynamic Footer Color
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
        selectedItemColor: Theme.of(context).colorScheme.secondary,
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
          // Properly ordered navigation
          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const TrainerHomeScreen()),
              (route) => false,
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TrainerNotesScreen()),
            );
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
