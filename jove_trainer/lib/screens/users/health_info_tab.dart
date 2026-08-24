import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---> IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class HealthInfoTab extends StatefulWidget {
  const HealthInfoTab({super.key, required this.clientId});
  final String clientId;

  @override
  State<HealthInfoTab> createState() => _HealthInfoTabState();
}

class _Procedure {
  final String id;
  final String name;
  final String? date;
  final String? rawDate;
  final String? recoveryStatus;

  _Procedure({
    required this.id,
    required this.name,
    this.date,
    this.rawDate,
    this.recoveryStatus,
  });
}

class _HealthCondition {
  final String id;
  final String name;
  bool isSolved;

  _HealthCondition({
    required this.id,
    required this.name,
    this.isSolved = false,
  });
}

class _Medication {
  final String id;
  final String name;
  _Medication({required this.id, required this.name});
}

class _HealthInfoTabState extends State<HealthInfoTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  List<_Procedure> _procedures = [];
  List<_Medication> _medications = [];
  List<_HealthCondition> _conditions = [];

  static const _monthKeys = [
    '',
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final strings = languageService.strings;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .get();
      final userData = userDoc.data() ?? {};

      final resolvedConditions = (userData['resolvedConditions'] as Map?) ?? {};

      // 1. Fetch Procedures
      final proceduresSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('proceduresSurgeries')
          .get();

      List<_Procedure> procedures = proceduresSnap.docs.map((d) {
        final data = d.data();
        String? dateLabel;
        final dateStr = data['procedureDate'] as String?;
        if (dateStr != null) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null && parsed.month >= 1 && parsed.month <= 12) {
            final monthStr =
                strings[_monthKeys[parsed.month]] ?? _monthKeys[parsed.month];
            dateLabel = '$monthStr ${parsed.year}';
          }
        }
        return _Procedure(
          id: d.id,
          name: data['procedureName'] ?? (strings['procedure'] ?? 'Procedure'),
          date: dateLabel,
          rawDate: dateStr,
          recoveryStatus: data['recoveryStatus'],
        );
      }).toList();

      final existingProcNames = procedures.map((p) => p.name.toLowerCase().trim()).toSet();

      final rawSurgeries = userData['surgeries'] ?? userData['proceduresSurgeries'] ?? userData['procedures'];
      if (rawSurgeries is List) {
        for (int i = 0; i < rawSurgeries.length; i++) {
          final item = rawSurgeries[i];
          final name = item is Map ? (item['name'] ?? item['surgeryName'] ?? item['procedureName']) : item.toString();
          final nameStr = name.toString().trim();
          if (nameStr.isNotEmpty && !existingProcNames.contains(nameStr.toLowerCase())) {
            existingProcNames.add(nameStr.toLowerCase());
            final date = item is Map ? item['date']?.toString() : null;
            final recovery = item is Map ? (item['recoveryStatus'] ?? (item['ongoingRehab'] == true ? 'Ongoing Rehab' : null))?.toString() : null;
            procedures.add(_Procedure(
              id: 'u_$i',
              name: nameStr,
              date: date,
              recoveryStatus: recovery,
            ));
          }
        }
      }

      // 2. Fetch Medications
      final medsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('medications')
          .get();
      List<_Medication> medications = medsSnap.docs.map((d) {
        return _Medication(
          id: d.id,
          name:
              (d.data()['name'] as String?) ??
              (strings['medication'] ?? 'Medication'),
        );
      }).toList();

      final existingMedNames = medications.map((m) => m.name.toLowerCase().trim()).toSet();

      final rawMeds = userData['medications'] ?? userData['prescriptions'] ?? userData['drugs'];
      if (rawMeds is List) {
        for (int i = 0; i < rawMeds.length; i++) {
          final item = rawMeds[i];
          final name = item is Map ? (item['name'] ?? item['medicationName']) : item.toString();
          final nameStr = name.toString().trim();
          if (nameStr.isNotEmpty && !existingMedNames.contains(nameStr.toLowerCase())) {
            existingMedNames.add(nameStr.toLowerCase());
            medications.add(_Medication(id: 'u_$i', name: nameStr));
          }
        }
      }

      // 3. Fetch Conditions
      final conditionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('healthConditions')
          .get();
      List<_HealthCondition> conditions = conditionsSnap.docs.map((d) {
        final data = d.data();
        final name = (data['conditionName'] as String?) ?? (strings['condition'] ?? 'Condition');
        final isSolved = resolvedConditions[name] == true || data['isSolved'] == true || data['status'] == 'solved' || data['status'] == 'resolved';
        return _HealthCondition(
          id: d.id,
          name: name,
          isSolved: isSolved,
        );
      }).toList();

      final existingConditionNames = conditions.map((c) => c.name.toLowerCase().trim()).toSet();

      final rawConditions = userData['medicalConditions'] ?? userData['conditions'] ?? userData['healthConditions'] ?? userData['injuries'];
      if (rawConditions is List) {
        for (int i = 0; i < rawConditions.length; i++) {
          final item = rawConditions[i];
          final name = item is Map ? (item['name'] ?? item['conditionName'] ?? item['title']) : item.toString();
          final nameStr = name.toString().trim();
          if (nameStr.isNotEmpty && !existingConditionNames.contains(nameStr.toLowerCase())) {
            existingConditionNames.add(nameStr.toLowerCase());
            final isSolved = resolvedConditions[nameStr] == true || (item is Map && (item['isSolved'] == true || item['status'] == 'solved' || item['status'] == 'resolved'));
            conditions.add(_HealthCondition(
              id: 'u_$i',
              name: nameStr,
              isSolved: isSolved,
            ));
          }
        }
      } else if (rawConditions is String && rawConditions.isNotEmpty) {
        final nameStr = rawConditions.trim();
        if (!existingConditionNames.contains(nameStr.toLowerCase())) {
          existingConditionNames.add(nameStr.toLowerCase());
          final isSolved = resolvedConditions[nameStr] == true;
          conditions.add(_HealthCondition(id: 'u_0', name: nameStr, isSolved: isSolved));
        }
      }

      if (userData['physicalConstraints'] is List) {
        final list = userData['physicalConstraints'] as List;
        for (int i = 0; i < list.length; i++) {
          final item = list[i];
          final name = item is Map ? (item['name'] ?? item['title'] ?? item['area']) : item.toString();
          final nameStr = name.toString().trim();
          if (nameStr.isNotEmpty && !existingConditionNames.contains(nameStr.toLowerCase())) {
            existingConditionNames.add(nameStr.toLowerCase());
            final isSolved = resolvedConditions[nameStr] == true || (item is Map && (item['isSolved'] == true || item['status'] == 'solved' || item['status'] == 'resolved'));
            conditions.add(_HealthCondition(
              id: 'pc_$i',
              name: nameStr,
              isSolved: isSolved,
            ));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _procedures = procedures;
        _medications = medications;
        _conditions = conditions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Health info load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleConditionSolved(_HealthCondition condition) async {
    final newState = !condition.isSolved;
    setState(() {
      condition.isSolved = newState;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .set({
            'resolvedConditions': {
              condition.name: newState,
            }
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Condition state update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = languageService.strings;
    final brandBlue = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final dividerColor = Theme.of(context).dividerColor;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: brandBlue),
      );
    }

    final hasAnything = _procedures.isNotEmpty ||
        _medications.isNotEmpty ||
        _conditions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dividerColor, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Dark Header Band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: brandBlue,
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFFBB0013),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings['physicalConditionsProfile'] ??
                        'Physical Conditions Profile',
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasAnything)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        strings['noHealthInfo'] ??
                            'No health information recorded yet.',
                        style: GoogleFonts.workSans(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // 1. Conditions & Constraints
                  if (_conditions.isNotEmpty) ...[
                    _SectionLabel(
                      strings['healthConditions'] ?? 'Health Conditions & Injuries',
                    ),
                    const SizedBox(height: 10),
                    ..._conditions.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ConditionRow(
                          condition: c,
                          onToggleSolved: () => _toggleConditionSolved(c),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Procedures & Surgeries
                  if (_procedures.isNotEmpty) ...[
                    _SectionLabel(
                      strings['proceduresSurgeries'] ?? 'Procedures & Surgeries',
                    ),
                    const SizedBox(height: 10),
                    ..._procedures.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProcedureCard(procedure: p),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Medications
                  if (_medications.isNotEmpty) ...[
                    _SectionLabel(
                      strings['medicationsPhysical'] ?? 'Medications (Physical)',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _medications
                          .map((m) => _Pill(text: m.name))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// HELPER WIDGETS
// ---------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFBB0013),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.workSans(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({required this.procedure});
  final _Procedure procedure;

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C4FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.healing_rounded,
              color: Color(0xFF00C4FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  procedure.name,
                  style: GoogleFonts.workSans(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (procedure.date != null ||
                    (procedure.recoveryStatus != null &&
                        procedure.recoveryStatus!.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (procedure.date != null)
                        '${strings['dateWord'] ?? 'Date'}: ${procedure.date}',
                      if (procedure.recoveryStatus != null &&
                          procedure.recoveryStatus!.isNotEmpty)
                        '${strings['recoveryWord'] ?? 'Recovery'}: ${procedure.recoveryStatus}',
                    ].join(' • '),
                    style: GoogleFonts.workSans(
                      color: subTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final cardBg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.medication_liquid_rounded,
            color: Color(0xFFBB0013),
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.workSans(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.condition,
    required this.onToggleSolved,
  });
  final _HealthCondition condition;
  final VoidCallback onToggleSolved;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).scaffoldBackgroundColor;

    final isSolved = condition.isSolved;

    final solvedBg = isDark
        ? const Color(0xFF14532D).withValues(alpha: 0.6)
        : const Color(0xFFDCFCE7);
    final solvedColor = isDark
        ? const Color(0xFF4ADE80)
        : const Color(0xFF15803D);

    final activeBg = isDark
        ? const Color(0xFF78350F).withValues(alpha: 0.5)
        : const Color(0xFFFEF3C7);
    final activeColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSolved
              ? solvedColor.withValues(alpha: 0.3)
              : Theme.of(context).dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSolved ? solvedColor : activeColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSolved ? Icons.check_circle_rounded : Icons.report_problem_rounded,
              color: isSolved ? solvedColor : activeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              condition.name,
              style: GoogleFonts.workSans(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: isSolved ? TextDecoration.lineThrough : null,
                decorationColor: solvedColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleSolved,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSolved ? solvedBg : activeBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSolved ? solvedColor : activeColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSolved ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSolved ? solvedColor : activeColor,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSolved ? 'Solved' : 'Active',
                    style: GoogleFonts.workSans(
                      color: isSolved ? solvedColor : activeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
