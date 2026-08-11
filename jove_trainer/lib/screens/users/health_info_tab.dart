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
  _HealthCondition({required this.id, required this.name});
}

class _Medication {
  final String id;
  final String name;
  _Medication({required this.id, required this.name});
}

class _HealthInfoTabState extends State<HealthInfoTab> {
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
      // 1. Fetch Procedures
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

      // 2. Fetch Medications
      final medsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('medications')
          .get();
      final medications = medsSnap.docs.map((d) {
        return _Medication(
          id: d.id,
          name:
              (d.data()['name'] as String?) ??
              (strings['medication'] ?? 'Medication'),
        );
      }).toList();

      // 3. Fetch Conditions
      final conditionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .collection('healthConditions')
          .get();
      final conditions = conditionsSnap.docs.map((d) {
        return _HealthCondition(
          id: d.id,
          name:
              (d.data()['conditionName'] as String?) ??
              (strings['condition'] ?? 'Condition'),
        );
      }).toList();

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

  // --- ADD / MANAGE METHODS ---

  Future<void> _addProcedure() async {
    final strings = languageService.strings;
    final nameCtrl = TextEditingController();
    final statusCtrl = TextEditingController();
    DateTime? selectedDate;
    final textColor = Theme.of(context).colorScheme.onSurface;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor, // Dynamic Dialog BG
            title: Text(
              strings['addProcedure'] ?? 'Add Procedure',
              style: GoogleFonts.workSans(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: strings['procedureName'] ?? 'Procedure Name',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: statusCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: strings['recoveryStatus'] ?? 'Recovery Status',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedDate == null
                        ? (strings['selectDate'] ?? 'Select Date')
                        : '${selectedDate!.month}/${selectedDate!.year}',
                    style: TextStyle(color: textColor),
                  ),
                  trailing: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setStateDialog(() => selectedDate = d);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(strings['cancel'] ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.clientId)
                      .collection('proceduresSurgeries')
                      .add({
                        'procedureName': nameCtrl.text.trim(),
                        'recoveryStatus': statusCtrl.text.trim(),
                        'procedureDate': selectedDate?.toIso8601String(),
                      });
                  if (context.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                child: Text(strings['addWord'] ?? 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMedication() async {
    final strings = languageService.strings;
    final ctrl = TextEditingController();
    final textColor = Theme.of(context).colorScheme.onSurface;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          strings['addMedication'] ?? 'Add Medication',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: strings['egIbuprofen'] ?? 'e.g. Ibuprofen',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings['cancel'] ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.clientId)
                  .collection('medications')
                  .add({'name': ctrl.text.trim()});
              if (context.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: Text(strings['addWord'] ?? 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCondition() async {
    final strings = languageService.strings;
    final ctrl = TextEditingController();
    final textColor = Theme.of(context).colorScheme.onSurface;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          strings['addCondition'] ?? 'Add Condition',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: strings['egHypertension'] ?? 'e.g. Hypertension',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings['cancel'] ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.clientId)
                  .collection('healthConditions')
                  .add({'conditionName': ctrl.text.trim()});
              if (context.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: Text(strings['addWord'] ?? 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String collection, String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.clientId)
        .collection(collection)
        .doc(docId)
        .delete();
    _loadData();
  }

  void _manageCondition(_HealthCondition condition) {
    final strings = languageService.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor, // Dynamic Bottom Sheet
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${strings['manage'] ?? 'Manage'}: ${condition.name}',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    strings['deleteCondition'] ?? 'Delete Condition',
                    style: GoogleFonts.workSans(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteItem('healthConditions', condition.id);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    strings['cancel'] ?? 'Cancel',
                    style: GoogleFonts.workSans(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final headerColor = Theme.of(context).primaryColor;
    final brandBlue = Theme.of(context).colorScheme.primary;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: brandBlue));
    }

    final hasAnything =
        _procedures.isNotEmpty ||
        _medications.isNotEmpty ||
        _conditions.isNotEmpty;

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dividerColor), // Dynamic border
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header (Always keeps brand color)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: headerColor,
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFBB0013), // Keep red heart
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings['physicalConditionsProfile'] ??
                        'Physical Conditions Profile',
                    style: GoogleFonts.workSans(
                      color: Colors.white, // Text stays white on header
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area (Changes with theme)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasAnything)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        strings['noHealthInfo'] ??
                            'No health information recorded yet.',
                        style: GoogleFonts.workSans(
                          color: subTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // 1. Procedures
                  _SectionLabel(
                    strings['proceduresSurgeries'] ?? 'Procedures & Surgeries',
                    onAdd: _addProcedure,
                  ),
                  const SizedBox(height: 8),
                  if (_procedures.isEmpty)
                    _EmptyNote(strings['noneRecorded'] ?? 'None recorded.')
                  else
                    ..._procedures.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProcedureCard(
                          procedure: p,
                          onDelete: () =>
                              _deleteItem('proceduresSurgeries', p.id),
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  // 2. Medications
                  _SectionLabel(
                    strings['medicationsPhysical'] ?? 'Medications (Physical)',
                    onAdd: _addMedication,
                  ),
                  const SizedBox(height: 8),
                  if (_medications.isEmpty)
                    _EmptyNote(strings['noneRecorded'] ?? 'None recorded.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _medications
                          .map(
                            (m) => _Pill(
                              text: m.name,
                              onDelete: () => _deleteItem('medications', m.id),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 18),

                  // 3. Conditions
                  _SectionLabel(
                    strings['healthConditions'] ?? 'Health Conditions',
                    onAdd: _addCondition,
                  ),
                  const SizedBox(height: 8),
                  if (_conditions.isEmpty)
                    _EmptyNote(strings['noneRecorded'] ?? 'None recorded.')
                  else
                    ..._conditions.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ConditionRow(
                          condition: c,
                          onManage: () => _manageCondition(c),
                        ),
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

// ---------------------------------------------------------
// HELPER WIDGETS
// ---------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.onAdd});
  final String text;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final brandBlue = Theme.of(context).colorScheme.primary;

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
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.workSans(
              color: textColor, // Dynamic Text
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brandBlue.withValues(
                alpha: 0.1,
              ), // Subtle dynamic background
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.add, color: brandBlue, size: 14),
                const SizedBox(width: 4),
                Text(
                  strings['addWord'] ?? 'Add',
                  style: GoogleFonts.workSans(
                    color: brandBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
      style: GoogleFonts.workSans(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({required this.procedure, required this.onDelete});
  final _Procedure procedure;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // Slight inset look
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
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
                    procedure.recoveryStatus != null) ...[
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
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: subTextColor, size: 18),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.onDelete});
  final String text;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.workSans(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.cancel, color: subTextColor, size: 16),
          ),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.condition, required this.onManage});
  final _HealthCondition condition;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              condition.name,
              style: GoogleFonts.workSans(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onManage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF17CC1A), // Keep action green
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              strings['manage'] ?? 'Manage',
              style: GoogleFonts.workSans(
                color: Colors.white, // Keep white on green
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
