import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---> NEW: IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class TrainerClientReviewsScreen extends StatefulWidget {
  const TrainerClientReviewsScreen({super.key});

  @override
  State<TrainerClientReviewsScreen> createState() =>
      _TrainerClientReviewsScreenState();
}

class _TrainerClientReviewsScreenState
    extends State<TrainerClientReviewsScreen> {
  static const Color darkBlue = Color(0xFF00225D);
  static const Color headerBlue = Color(0xFF003AA3);
  static const Color primaryRed = Color(0xFFC7001A);
  static const Color bgGrey = Color(0xFFFAFAFA);
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color textGrey = Color(0xFF6B7280);

  // ---> UPDATED: Now uses translated months! <---
  String _formatDate(DateTime date, Map<String, String> strings) {
    const monthKeys = [
      'monthJan',
      'monthFeb',
      'monthMar',
      'monthApr',
      'monthMay',
      'monthJun',
      'monthJul',
      'monthAug',
      'monthSep',
      'monthOct',
      'monthNov',
      'monthDec',
    ];

    // Fallback english names just in case
    const fallbackMonths = [
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

    String monthStr =
        strings[monthKeys[date.month - 1]] ?? fallbackMonths[date.month - 1];
    return '${date.day} $monthStr ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // ---> Get Strings Here <---
    final strings = languageService.strings;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          const _TopHeaderBand(),
          Expanded(
            child: uid == null
                ? Center(
                    child: Text(
                      strings['authError'] ??
                          'Authentication error. Please log in again.',
                      style: GoogleFonts.workSans(color: textGrey),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          strings['clientReviews'] ?? 'Client Reviews',
                          style: GoogleFonts.workSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: darkBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('feedbacks')
                              .where('trainerId', isEqualTo: uid)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: darkBlue,
                                ),
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star_outline_rounded,
                                      size: 64,
                                      color: borderGrey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      strings['noReviews'] ??
                                          'No reviews found yet.',
                                      style: GoogleFonts.workSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final docs = snapshot.data!.docs;
                            double totalScore = 0.0;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              totalScore += data['rating'] != null
                                  ? (double.tryParse(
                                          data['rating'].toString(),
                                        ) ??
                                        5.0)
                                  : 5.0;
                            }
                            final double averageRating =
                                totalScore / docs.length;

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildSummaryCard(
                                    averageRating: averageRating,
                                    totalReviews: docs.length,
                                    strings: strings,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      0,
                                      24,
                                      40,
                                    ),
                                    itemCount: docs.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 16),
                                    itemBuilder: (context, index) =>
                                        _buildReviewCard(
                                          docs[index].data()
                                              as Map<String, dynamic>,
                                          strings,
                                        ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required double averageRating,
    required int totalReviews,
    required Map<String, String> strings,
  }) {
    String base = strings['basedOn'] ?? 'Based on';
    String reviewWord = totalReviews == 1
        ? (strings['reviewWord'] ?? 'review')
        : (strings['reviewsWord'] ?? 'reviews');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: headerBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: headerBlue.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            averageRating.toStringAsFixed(1),
            style: GoogleFonts.workSans(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < averageRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFD700),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$base $totalReviews $reviewWord',
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(
    Map<String, dynamic> feedback,
    Map<String, String> strings,
  ) {
    final clientName =
        feedback['clientName']?.toString() ??
        strings['anonymous'] ??
        'Anonymous';
    final memberType =
        feedback['memberType']?.toString() ?? strings['member'] ?? 'MEMBER';
    final reviewText = feedback['reviewText']?.toString() ?? '';
    final clientImage = feedback['clientImageUrl']?.toString() ?? '';
    final Timestamp? t = feedback['createdAt'];

    // ---> UPDATED: Passing strings map to the formatter <---
    final String formattedDate = _formatDate(
      t?.toDate() ?? DateTime.now(),
      strings,
    );

    int rating = feedback['rating'] != null
        ? (double.tryParse(feedback['rating'].toString())?.round() ?? 5)
        : 5;
    String initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF3F4F6),
                backgroundImage: clientImage.isNotEmpty
                    ? NetworkImage(clientImage)
                    : null,
                child: clientImage.isEmpty
                    ? Text(
                        initial,
                        style: GoogleFonts.workSans(
                          fontSize: 16,
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
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
                        fontWeight: FontWeight.w800,
                        color: darkBlue,
                      ),
                    ),
                    Text(
                      memberType.toUpperCase(),
                      style: GoogleFonts.workSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedDate,
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textGrey,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: borderGrey, thickness: 1, height: 1),
          ),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: primaryRed,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            reviewText.isNotEmpty
                ? '"$reviewText"'
                : (strings['noWrittenReview'] ?? 'No written review provided.'),
            style: GoogleFonts.workSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: reviewText.isNotEmpty
                  ? const Color(0xFF374151)
                  : const Color(0xFF9CA3AF),
              fontStyle: reviewText.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// HEADER WIDGET (With Back Button)
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
      decoration: const BoxDecoration(
        color: Color(0xFF003AA3),
        borderRadius: BorderRadius.only(
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
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.transparent,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
                      color: const Color(0xFFC7001A),
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
        ],
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
