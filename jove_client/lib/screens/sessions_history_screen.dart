import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme_controller.dart';

class SessionsHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? trainerSessions;

  const SessionsHistoryScreen({super.key, this.trainerSessions});

  @override
  State<SessionsHistoryScreen> createState() => _SessionsHistoryScreenState();
}

class _SessionsHistoryScreenState extends State<SessionsHistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isShowingHistory = false;
  
  late final Stream<QuerySnapshot> _bookingStream;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _bookingStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: _user.uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppThemeController.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black,
                size: 18,
              ),
            ),
          ),
        ),
        title: Text(
          'programs'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _user == null
          ? Center(child: Text('please_sign_in'.tr()))
          : Column(
              children: [
                const SizedBox(height: 16),
                _buildSegmentedControl(),
                const SizedBox(height: 24),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _bookingStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFBB0013)));
                      }
                      
                      final docs = snapshot.data?.docs ?? [];
                      
                      final now = DateTime.now();
                      final todayFormatted = DateFormat('yyyy-MM-dd').format(now);
                      
                      List<DocumentSnapshot> filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? '';
                        final date = data['date'] ?? '';
                        
                        bool isPast = false;
                        try {
                          final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
                          isPast = parsedDate.isBefore(DateTime(now.year, now.month, now.day));
                        } catch (_) {
                           isPast = date.compareTo(todayFormatted) < 0;
                        }
                        
                        // History shows past sessions or cancelled/completed sessions
                        final isCancelledOrCompleted = status == 'cancelled' || status == 'completed';
                        return isPast || isCancelledOrCompleted;
                      }).toList();
                      
                      filteredDocs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        DateTime? aDate;
                        DateTime? bDate;
                        try {
                          aDate = DateFormat('yyyy-MM-dd').parse(aData['date'] ?? '');
                          bDate = DateFormat('yyyy-MM-dd').parse(bData['date'] ?? '');
                        } catch (_) {}
                        
                        if (aDate != null && bDate != null) {
                          return bDate.compareTo(aDate);
                        }
                        return 0;
                      });

                      if (!_isShowingHistory) {
                        final sessions = widget.trainerSessions ?? [];
                        if (sessions.isEmpty) {
                          return Center(
                            child: Text(
                              'no_upcoming_sessions'.tr(),
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54, 
                                fontSize: 16
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            return _buildTrainerSessionCard(sessions[index], index);
                          },
                        );
                      }

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Text(
                            'no_past_sessions_found'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54, 
                              fontSize: 16
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          return _buildSessionCard(
                            filteredDocs[index].data() as Map<String, dynamic>,
                            index,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSegmentedControl() {
    final bool isDark = AppThemeController.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isShowingHistory = false);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: !_isShowingHistory ? const Color(0xFFD4FF3F) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'available_sessions'.tr(),
                    style: TextStyle(
                      color: !_isShowingHistory 
                          ? Colors.black 
                          : (isDark ? Colors.white54 : Colors.black54),
                      fontWeight: !_isShowingHistory ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isShowingHistory = true);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _isShowingHistory ? const Color(0xFFD4FF3F) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'history'.tr(),
                    style: TextStyle(
                      color: _isShowingHistory 
                          ? Colors.black 
                          : (isDark ? Colors.white54 : Colors.black54),
                      fontWeight: _isShowingHistory ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerSessionCard(Map<String, dynamic> session, int index) {
    // Using the same beautiful gradients
    final List<LinearGradient> cardGradients = [
      const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFC026D3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2DD4BF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFEAB308)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    
    final gradient = cardGradients[index % cardGradients.length];
    final String title = session['name'] ?? 'Training Session';
    final String subtitle = session['sub'] ?? 'Customized Workout';
    final IconData icon = session['icon'] ?? Icons.fitness_center;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              icon,
              size: 100,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> data, int index) {
    final List<LinearGradient> cardGradients = [
      const LinearGradient(
        colors: [Color(0xFFC084FC), Color(0xFFF3E8FF)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFBAE6FD), Color(0xFFFFEDD5)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF4ADE80), Color(0xFFBBF7D0)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFFCD34D), Color(0xFFFEF3C7)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFFDA4AF), Color(0xFFFFE4E6)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ];

    final gradient = cardGradients[index % cardGradients.length];
    final trainerName = data['trainerName'] ?? 'Trainer';
    final sessionType = data['sessionType'] ?? 'Training Session';
    
    // Format the date for display
    String dateStr = data['date'] ?? 'TBD';
    try {
      final d = DateFormat('yyyy-MM-dd').parse(dateStr);
      dateStr = DateFormat('dd MMM yyyy').format(d);
    } catch (_) {}
    
    final timeStr = data['time'] ?? 'TBD';
    
    final isEven = index % 2 == 0;
    final imageAsset = isEven ? 'assets/images/male.png' : 'assets/images/female.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 180,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            top: 20,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                width: 140,
              ),
            ),
          ),
          
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainerName,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: Text(
                    sessionType,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _buildPill(dateStr),
                    const SizedBox(width: 8),
                    _buildPill(timeStr),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
