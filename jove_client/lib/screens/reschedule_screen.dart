import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- IMPORTED TRANSLATIONS

class RescheduleScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const RescheduleScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  late List<DateTime> _next6Days;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();

  bool _isChecking = false;
  bool _isUpdating = false;
  String _availabilityStatus = 'none';

  static const Color _darkBlue = Color(0xFF00225D);
  static const Color _cyan = Color(0xFF00B4D8);
  static const Color _red = Color(0xFFBB0013);

  @override
  void initState() {
    super.initState();
    _generateNext6Days();
    _selectedTime = const TimeOfDay(hour: 10, minute: 30);
  }

  void _generateNext6Days() {
    _next6Days = [];
    DateTime today = DateTime.now();
    for (int i = 0; i < 6; i++) {
      _next6Days.add(today.add(Duration(days: i)));
    }
    _selectedDate = _next6Days[1];
  }

  String _formatTimeStrict(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _availabilityStatus = 'none';
      });
    }
  }

  void _checkAvailability() {
    setState(() => _isChecking = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _availabilityStatus = 'available';
      });
    });
  }

  Future<void> _confirmReschedule() async {
    if (_selectedDate == null || _selectedTime == null) return;

    setState(() => _isUpdating = true);
    try {
      String newDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      String newTime = _formatTimeStrict(_selectedTime!);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'date': newDate,
            'time': newTime,
            'status': 'confirmed',
            'rescheduleReason': _reasonController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reschedule_success'.tr()), // TRANSLATED
          backgroundColor: Colors.green,
        ),
      );

      // Return smoothly to Home
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reschedule_fail'.tr())), // TRANSLATED
      );
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Optionally dynamically set DateFormat locale: DateFormat('MMM yyyy', context.locale.languageCode)
    String currentMonthYear = DateFormat('MMM yyyy').format(_selectedDate!);
    String oldDateDisplay = '';
    try {
      DateTime oldDt = DateTime.parse(widget.bookingData['date']);
      oldDateDisplay = DateFormat('MMM dd, yyyy').format(oldDt).toUpperCase();
    } catch (e) {
      oldDateDisplay = widget.bookingData['date'] ?? 'tbd'.tr(); // TRANSLATED
    }

    String trainerName =
        widget.bookingData['trainerName'] ?? 'unassigned'.tr(); // TRANSLATED

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: _darkBlue,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              border: Border(bottom: BorderSide(color: _cyan, width: 6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'reschedule_title'.tr(), // TRANSLATED
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none, color: _cyan),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'current_session'.tr(), // TRANSLATED
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: _cyan, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: _darkBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.bookingData['sessionType'] ??
                                    'training_default'.tr(), // TRANSLATED
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _darkBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'trainer_name_format'.tr(
                                        namedArgs: {'trainerName': trainerName},
                                      ), // TRANSLATED
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'date_label'.tr(), // TRANSLATED
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              oldDateDisplay,
                              style: const TextStyle(
                                color: _darkBlue,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'time_label'.tr(), // TRANSLATED
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.bookingData['time'] ?? '',
                              style: const TextStyle(
                                color: _darkBlue,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'select_new_date'.tr(), // TRANSLATED
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _darkBlue,
                        ),
                      ),
                      Text(
                        currentMonthYear,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _darkBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 85,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _next6Days.length,
                      itemBuilder: (context, index) {
                        DateTime date = _next6Days[index];
                        bool isSelected = _selectedDate == date;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              _availabilityStatus = 'none';
                            });
                          },
                          child: Container(
                            width: 65,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _darkBlue : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? _cyan
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? _cyan
                                        : Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : _darkBlue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'select_time_title'.tr(), // TRANSLATED
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'enter_time_hint'.tr(), // TRANSLATED
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedTime == null
                                            ? 'select_time_btn'
                                                  .tr() // TRANSLATED
                                            : _formatTimeStrict(_selectedTime!),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isChecking
                                    ? null
                                    : _checkAvailability,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isChecking
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'btn_check'.tr(), // TRANSLATED
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (_availabilityStatus == 'available') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatTimeStrict(_selectedTime!),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'reason_optional'.tr(), // TRANSLATED
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'reason_hint'.tr(), // TRANSLATED
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_availabilityStatus == 'available' && !_isUpdating)
                          ? _confirmReschedule
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isUpdating
                          ? const SizedBox.shrink()
                          : const Icon(
                              Icons.check_box,
                              color: Colors.white,
                              size: 20,
                            ),
                      label: _isUpdating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'confirm_changes'.tr(), // TRANSLATED
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF001233),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStaticNavItem(
              0,
              Icons.home_filled,
              'home_nav'.tr(),
              false,
            ), // TRANSLATED
            _buildStaticNavItem(
              1,
              Icons.calendar_month,
              'booking_nav'.tr(),
              true,
            ), // TRANSLATED
            _buildStaticNavItem(
              2,
              Icons.insert_chart_rounded,
              'stats_nav'.tr(),
              false,
            ), // TRANSLATED
            _buildStaticNavItem(
              3,
              Icons.chat_bubble_rounded,
              'chats_nav'.tr(),
              false,
            ), // TRANSLATED
            _buildStaticNavItem(
              4,
              Icons.person_rounded,
              'profile_nav'.tr(),
              false,
            ), // TRANSLATED
          ],
        ),
      ),
    );
  }

  Widget _buildStaticNavItem(
    int index,
    IconData icon,
    String label,
    bool isSelected,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSelected ? 10.0 : 6.0,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF01BCE3) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey.shade400,
            size: 22,
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
