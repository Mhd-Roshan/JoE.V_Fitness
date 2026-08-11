import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---> NEW: IMPORT LANGUAGE SERVICE <---
import '../../services/language_service.dart';

class AddVisitNoteScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientInitials;
  final Color bgColor;
  final Color textColor;

  const AddVisitNoteScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientInitials,
    required this.bgColor,
    required this.textColor,
  });

  @override
  State<AddVisitNoteScreen> createState() => _AddVisitNoteScreenState();
}

class _AddVisitNoteScreenState extends State<AddVisitNoteScreen> {
  // Keep brand red static
  static const Color primaryRed = Color(0xFFC7001A);

  final TextEditingController _exercisesController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  final TextEditingController _nextFocusController = TextEditingController();

  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedSessionType; // Will be set in build() based on translations

  bool _isSaving = false;

  @override
  void dispose() {
    _exercisesController.dispose();
    _observationController.dispose();
    _nextFocusController.dispose();
    super.dispose();
  }

  // Save Data to Firebase
  Future<void> _saveNote() async {
    final strings = languageService.strings;

    // Basic validation
    if (_exercisesController.text.trim().isEmpty &&
        _observationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings['enterNotesBeforeSaving'] ??
                'Please enter some notes before saving.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Save to a 'visit_notes' collection in Firestore
      await FirebaseFirestore.instance.collection('visit_notes').add({
        'trainerId': uid,
        'clientId': widget.clientId,
        'clientName': widget.clientName,
        'sessionTime': _selectedTime.format(context),
        'sessionType': _selectedSessionType ?? 'Strength',
        'exercisesPerformed': _exercisesController.text.trim(),
        'observation': _observationController.text.trim(),
        'nextFocus': _nextFocusController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings['visitNotesSaved'] ?? 'Visit notes saved successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Go back to the previous screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${strings['errorSavingNote'] ?? 'Error saving note:'} $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = languageService.strings;

    // ---> DYNAMIC THEME COLORS <---
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    // Dynamically build the session types list based on language
    final List<String> sessionTypes = [
      strings['strength'] ?? 'Strength',
      strings['cardio'] ?? 'Cardio',
      strings['hiit'] ?? 'HIIT',
      strings['mobility'] ?? 'Mobility',
      strings['recovery'] ?? 'Recovery',
      strings['yoga'] ?? 'Yoga',
    ];

    // Set a default selected session type if null
    _selectedSessionType ??= sessionTypes.first;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const _TopHeaderBand(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title showing who the note is for
                  Row(
                    children: [
                      Text(
                        strings['newNoteFor'] ?? 'New Note for ',
                        style: GoogleFonts.workSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      // Client Pill
                      Container(
                        padding: const EdgeInsets.only(
                          left: 4,
                          right: 12,
                          top: 4,
                          bottom: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.bgColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                widget.clientInitials,
                                style: GoogleFonts.workSans(
                                  color: widget.textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.clientName,
                              style: GoogleFonts.workSans(
                                color: widget.textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Session Time Section
                  _buildSectionTitle(strings['sessionTime'] ?? 'Session Time'),
                  const SizedBox(height: 12),
                  _buildSessionTimeSelector(sessionTypes),
                  const SizedBox(height: 30),

                  // Divider: VISIT NOTES DETAILS
                  _buildDividerWithText(
                    strings['visitNotesDetails'] ?? 'VISIT NOTES DETAILS',
                  ),
                  const SizedBox(height: 24),

                  // Input Fields
                  _buildInputField(
                    title:
                        strings['exercisesPerformed'] ?? 'Exercises Performed',
                    hint:
                        strings['exercisesHint'] ??
                        'e.g. Squats 3x15, Push-ups 3x12, Deadlift 3x8',
                    controller: _exercisesController,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    title: strings['observation'] ?? 'Observation',
                    hint:
                        strings['observationHint'] ??
                        'Energy level, form, pain points,\nimprovements, vitals...',
                    controller: _observationController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    title: strings['nextFocusCore'] ?? 'Next Focus Core',
                    hint:
                        strings['nextFocusHint'] ??
                        'e.g. Core work, increase cardio intensity',
                    controller: _nextFocusController,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isSaving
                            ? (strings['saving'] ?? 'Saving...')
                            : (strings['saveVisitNotes'] ?? 'Save Visit Notes'),
                        style: GoogleFonts.workSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers for this page ---
  Widget _buildSectionTitle(String title) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Text(
      title,
      style: GoogleFonts.workSans(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );
  }

  Widget _buildSessionTimeSelector(List<String> sessionTypes) {
    final primaryBlue = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selectable Time
          GestureDetector(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) setState(() => _selectedTime = time);
            },
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _selectedTime.format(context),
                  style: GoogleFonts.workSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '·',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          // Selectable Session Type
          PopupMenuButton<String>(
            initialValue: _selectedSessionType,
            onSelected: (String item) =>
                setState(() => _selectedSessionType = item),
            itemBuilder: (BuildContext context) =>
                sessionTypes.map((String item) {
                  return PopupMenuItem<String>(value: item, child: Text(item));
                }).toList(),
            child: Row(
              children: [
                Text(
                  _selectedSessionType ?? '',
                  style: GoogleFonts.workSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerWithText(String text) {
    final dividerColor = Theme.of(context).dividerColor;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: GoogleFonts.workSans(
              color: subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
      ],
    );
  }

  Widget _buildInputField({
    required String title,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final brandBlue = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.workSans(
            fontSize: 14,
            color: textColor, // Text dynamically adjusts
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.workSans(
              color: subTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// HEADER (No Bottom Nav on this page)
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
        color: Theme.of(context).primaryColor, // Dynamic Header Blue
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back button logic
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'JoE ',
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
                      color: _AddVisitNoteScreenState.primaryRed,
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
