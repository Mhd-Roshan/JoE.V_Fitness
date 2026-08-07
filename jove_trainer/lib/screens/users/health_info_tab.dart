import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HealthInfoTab extends StatefulWidget {
  const HealthInfoTab({super.key, required this.clientId});
  final String clientId;

  @override
  State<HealthInfoTab> createState() => _HealthInfoTabState();
}

class _Procedure {
  final String name;
  final String? date;
  final String? recoveryStatus;
  _Procedure({required this.name, this.date, this.recoveryStatus});
}

class _HealthCondition {
  final String id;
  final String name;
  _HealthCondition({required this.id, required this.name});
}

class _HealthInfoTabState extends State<HealthInfoTab> {
  bool _loading = true;
  List<_Procedure> _procedures = [];
  List<String> _medications = [];
  List<_HealthCondition> _conditions = [];

  static const _months = [
    '',
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Real Firestore reads only, mirroring the same subcollections used
  // in the admin panel (proceduresSurgeries, medications,
  // healthConditions). No fallback/sample data.
  Future<void> _loadData() async {
    try {
      final proceduresSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('proceduresSurgeries')
          .get();

      final procedures = proceduresSnap.docs.map((d) {
        final data = d.data();
        String? dateLabel;
        final dateStr = data['procedureDate'] as String?;
        if (dateStr != null) {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) {
            dateLabel = '${_months[parsed.month]} ${parsed.year}';
          }
        }
        return _Procedure(
          name: data['procedureName'] ?? 'Procedure',
          date: dateLabel,
          recoveryStatus: data['recoveryStatus'],
        );
      }).toList();

      final medsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('medications')
          .get();
      final medications = medsSnap.docs
          .map((d) => (d.data()['name'] as String?) ?? 'Medication')
          .toList();

      final conditionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('healthConditions')
          .get();
      final conditions = conditionsSnap.docs
          .map(
            (d) => _HealthCondition(
              id: d.id,
              name: (d.data()['conditionName'] as String?) ?? 'Condition',
            ),
          )
          .toList();

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasAnything =
        _procedures.isNotEmpty ||
        _medications.isNotEmpty ||
        _conditions.isNotEmpty;

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC0C0C0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFF00225D),
              child: const Row(
                children: [
                  Icon(Icons.favorite, color: Color(0xFFBB0013), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Physical Conditions Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF00225D),
              child: !hasAnything
                  ? const Text(
                      'No health information recorded yet.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Procedures & Surgeries'),
                        const SizedBox(height: 8),
                        if (_procedures.isEmpty)
                          const _EmptyNote('None recorded.')
                        else
                          ..._procedures.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ProcedureCard(procedure: p),
                            ),
                          ),

                        const SizedBox(height: 18),
                        _SectionLabel('Medications (Physical)'),
                        const SizedBox(height: 8),
                        if (_medications.isEmpty)
                          const _EmptyNote('None recorded.')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _medications
                                .map((m) => _Pill(text: m))
                                .toList(),
                          ),

                        const SizedBox(height: 18),
                        _SectionLabel('Health Conditions'),
                        const SizedBox(height: 8),
                        if (_conditions.isEmpty)
                          const _EmptyNote('None recorded.')
                        else
                          ..._conditions.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ConditionRow(condition: c),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFFBB0013),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({required this.procedure});
  final _Procedure procedure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            procedure.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (procedure.date != null || procedure.recoveryStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (procedure.date != null) 'Date: ${procedure.date}',
                if (procedure.recoveryStatus != null)
                  'Recovery: ${procedure.recoveryStatus}',
              ].join(' • '),
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.condition});
  final _HealthCondition condition;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              condition.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // A "manage condition" edit sheet will be wired here once that
              // flow is built.
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF17CC1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Manage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
