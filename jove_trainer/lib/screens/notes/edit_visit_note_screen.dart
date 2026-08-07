import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditVisitNoteScreen extends StatefulWidget {
  final String noteId;
  final Map<String, dynamic> noteData;

  const EditVisitNoteScreen({
    super.key,
    required this.noteId,
    required this.noteData,
  });

  @override
  State<EditVisitNoteScreen> createState() => _EditVisitNoteScreenState();
}

class _EditVisitNoteScreenState extends State<EditVisitNoteScreen> {
  static const Color darkBlue = Color(0xFF00225D);
  static const Color headerBlue = Color(0xFF003AA3);
  static const Color primaryRed = Color(0xFFC7001A);
  static const Color bgGrey = Color(0xFFFAFAFA);
  static const Color borderGrey = Color(0xFFE5E7EB);

  late TextEditingController _exercisesController;
  late TextEditingController _observationController;
  late TextEditingController _nextFocusController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields with existing data
    _exercisesController = TextEditingController(
      text: widget.noteData['exercisesPerformed'] ?? '',
    );
    _observationController = TextEditingController(
      text: widget.noteData['observation'] ?? '',
    );
    _nextFocusController = TextEditingController(
      text: widget.noteData['nextFocus'] ?? '',
    );
  }

  @override
  void dispose() {
    _exercisesController.dispose();
    _observationController.dispose();
    _nextFocusController.dispose();
    super.dispose();
  }

  // Update Data in Firebase
  Future<void> _updateNote() async {
    if (_exercisesController.text.trim().isEmpty &&
        _observationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fields cannot be entirely empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('visit_notes')
          .doc(widget.noteId)
          .update({
            'exercisesPerformed': _exercisesController.text.trim(),
            'observation': _observationController.text.trim(),
            'nextFocus': _nextFocusController.text.trim(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Go back
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.noteData['clientName'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          const _TopHeaderBand(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editing Note for $clientName',
                    style: GoogleFonts.workSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildDividerWithText('UPDATE VISIT NOTES DETAILS'),
                  const SizedBox(height: 24),

                  _buildInputField(
                    title: 'Exercises Performed',
                    hint: 'e.g. Squats 3x15...',
                    controller: _exercisesController,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    title: 'Observation',
                    hint: 'Energy level, form...',
                    controller: _observationController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    title: 'Next Focus Core',
                    hint: 'e.g. Core work...',
                    controller: _nextFocusController,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _updateNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
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
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Updating...' : 'Update Visit Notes',
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

  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: borderGrey, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: GoogleFonts.workSans(
              color: const Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider(color: borderGrey, thickness: 1)),
      ],
    );
  }

  Widget _buildInputField({
    required String title,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.workSans(
            fontSize: 14,
            color: darkBlue,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.workSans(
              color: const Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: borderGrey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: darkBlue, width: 1.5),
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
        color: _EditVisitNoteScreenState.headerBlue,
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
                      color: _EditVisitNoteScreenState.primaryRed,
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
