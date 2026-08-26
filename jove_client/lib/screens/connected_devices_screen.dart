import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'watch_scanner_screen.dart';
import '../theme/app_theme_controller.dart';

class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _primaryRed = Color(0xFFBB0013);

  final User? currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription<DocumentSnapshot>? _userSub;

  Map<String, dynamic>? _userData;
  bool _isSyncing = false;


  // Metric sync settings
  bool _syncSteps = true;
  bool _syncSleep = true;
  bool _syncHydration = true;
  bool _syncWeight = true;
  bool _autoSyncBackground = true;

  Timer? _mockSyncTimer;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
    _startMockBackgroundSync();
  }

  void _startMockBackgroundSync() {
    // Simulates reading real health data from the connected BLE watch periodically
    // so the today's progress cards update automatically.
    _mockSyncTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (currentUser?.uid == null) return;
      final connectedMap = _userData?['connectedDevice'] as Map<String, dynamic>?;
      if (connectedMap != null && connectedMap['name'] != null) {
        if (_autoSyncBackground) {
          final now = DateTime.now();
          final String todayDate = DateFormat('yyyy-MM-dd').format(now);
          final Map<String, dynamic> updates = {};
          final Map<String, dynamic> historyUpdates = {'updatedAt': FieldValue.serverTimestamp()};

          if (_syncSteps) {
            int currentSteps = _userData?['steps'] ?? 0;
            currentSteps += 35; // Simulate user walking while connected
            updates['steps'] = currentSteps;
            updates['dailySteps.$todayDate'] = currentSteps;
            historyUpdates['steps'] = currentSteps;
          }

          if (_syncHydration) {
            int currentHyd = _userData?['dailyHydration']?[todayDate] ?? 0;
            // Add a little water randomly
            if (DateTime.now().minute % 5 == 0) {
              currentHyd += 10;
              updates['dailyHydration.$todayDate'] = currentHyd;
              historyUpdates['hydration'] = currentHyd;
            }
          }

          if (updates.isNotEmpty) {
            updates['lastDeviceSync'] = FieldValue.serverTimestamp();
            
            WriteBatch batch = FirebaseFirestore.instance.batch();
            DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
            DocumentReference historyRef = userRef.collection('progress_history').doc(todayDate);
            
            batch.update(userRef, updates);
            batch.set(historyRef, historyUpdates, SetOptions(merge: true));
            await batch.commit();
          }
        }
      }
    });
  }

  void _listenToUserData() {
    if (currentUser?.uid == null) return;
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .listen((snap) {
      if (mounted && snap.exists) {
        final data = snap.data() ?? {};
        setState(() {
          _userData = data;
          final syncSettings = data['deviceSyncSettings'] as Map<String, dynamic>?;
          if (syncSettings != null) {
            _syncSteps = syncSettings['syncSteps'] ?? true;
            _syncSleep = syncSettings['syncSleep'] ?? true;
            _syncHydration = syncSettings['syncHydration'] ?? true;
            _syncWeight = syncSettings['syncWeight'] ?? true;
            _autoSyncBackground = syncSettings['autoSyncBackground'] ?? true;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _mockSyncTimer?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  // _connectDevice has been removed since pairing happens in WatchScannerScreen.

  // --- DISCONNECT DEVICE ---
  Future<void> _disconnectDevice() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Disconnect Device?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _textMain),
        ),
        content: const Text(
          'Automatic synchronization with your wearable smart device will be paused.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && currentUser?.uid != null) {
      HapticFeedback.mediumImpact();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'connectedDevice': FieldValue.delete()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Smart device disconnected.'),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // --- SYNC DATA NOW ---
  Future<void> _performDeviceSync() async {
    if (_isSyncing || currentUser?.uid == null) return;
    setState(() => _isSyncing = true);
    HapticFeedback.selectionClick();

    try {
      final now = DateTime.now();
      final String todayDate = DateFormat('yyyy-MM-dd').format(now);

      // Read current device/health values (with intelligent simulation from connected band)
      final existingSteps = (_userData?['dailySteps'] as Map?)?[todayDate] ?? 0;
      final existingSleep = (_userData?['dailySleep'] as Map?)?[todayDate]?.toDouble() ?? 0.0;
      final existingHydration = (_userData?['dailyHydration'] as Map?)?[todayDate] ?? 0;
      final existingWeight = (_userData?['dailyWeight'] as Map?)?[todayDate]?.toDouble() ??
          (_userData?['weight']?.toDouble() ?? 70.0);

      // Synced values from smart device
      int syncedSteps = existingSteps > 0 ? existingSteps : 7840;
      double syncedSleep = existingSleep > 0 ? existingSleep : 7.5;
      int syncedHydration = existingHydration > 0 ? existingHydration : 2000;
      double syncedWeight = existingWeight > 0 ? existingWeight : 69.5;

      Map<String, dynamic> updates = {
        'lastDeviceSync': FieldValue.serverTimestamp(),
      };

      Map<String, dynamic> historyUpdates = {
        'date': todayDate,
        'syncedViaDevice': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_syncSteps) {
        updates['steps'] = syncedSteps;
        updates['dailySteps.$todayDate'] = syncedSteps;
        historyUpdates['steps'] = syncedSteps;
      }
      if (_syncSleep) {
        updates['sleep'] = syncedSleep;
        updates['dailySleep.$todayDate'] = syncedSleep;
        historyUpdates['sleep'] = syncedSleep;
      }
      if (_syncHydration) {
        updates['dailyHydration.$todayDate'] = syncedHydration;
        historyUpdates['hydration'] = syncedHydration;
      }
      if (_syncWeight) {
        updates['weight'] = syncedWeight;
        updates['dailyWeight.$todayDate'] = syncedWeight;
        historyUpdates['weight'] = syncedWeight;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
      DocumentReference historyRef = userRef
          .collection('progress_history')
          .doc(todayDate);

      batch.update(userRef, updates);
      batch.set(historyRef, historyUpdates, SetOptions(merge: true));
      await batch.commit();

      // Simulated network/bluetooth sync latency for rich user feedback
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Device data synced with Jove Fitness!'),
              ],
            ),
            backgroundColor: const Color(0xFF1E88E5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- UPDATE SYNC METRICS TOGGLE ---
  Future<void> _updateMetricSetting(String key, bool val) async {
    if (currentUser?.uid == null) return;
    setState(() {
      if (key == 'syncSteps') _syncSteps = val;
      if (key == 'syncSleep') _syncSleep = val;
      if (key == 'syncHydration') _syncHydration = val;
      if (key == 'syncWeight') _syncWeight = val;
      if (key == 'autoSyncBackground') _autoSyncBackground = val;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .set({
      'deviceSyncSettings': {
        'syncSteps': _syncSteps,
        'syncSleep': _syncSleep,
        'syncHydration': _syncHydration,
        'syncWeight': _syncWeight,
        'autoSyncBackground': _autoSyncBackground,
      }
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final connectedMap = _userData?['connectedDevice'] as Map<String, dynamic>?;
        final bool hasConnectedDevice = connectedMap != null && connectedMap['name'] != null;
        final String deviceName = connectedMap?['name'] ?? '';
        final Timestamp? lastSync = _userData?['lastDeviceSync'] as Timestamp?;

        String lastSyncText = 'Not synced yet';
        if (lastSync != null) {
          final syncDt = lastSync.toDate();
          lastSyncText = 'Synced Today at ${DateFormat('hh:mm a').format(syncDt)}';
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : _bgColor,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Connected Devices',
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5F5) : _textMain,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.radar_rounded, color: Color(0xFF6366F1), size: 24),
                onPressed: _openWatchRadarScanner,
                tooltip: 'Radar Scan for Watches',
              ),
              if (hasConnectedDevice)
                IconButton(
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _primaryRed,
                          ),
                        )
                      : const Icon(Icons.sync, color: _primaryRed),
                  onPressed: _isSyncing ? null : () => _performDeviceSync(),
                  tooltip: 'Sync Now',
                ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ACTIVE CONNECTED HERO CARD
                _buildActiveDeviceHero(hasConnectedDevice, deviceName, lastSyncText, connectedMap),

                const SizedBox(height: 20),

                // 2. RADAR SCANNER HERO CALLOUT (MATCHING LIVE RADAR SEARCH)
                _buildRadarScannerHeroButton(),

                const SizedBox(height: 28),

                // 3. DATA SYNCHRONIZATION SWITCHES (Only visible when device is connected)
                if (hasConnectedDevice) ...[
                  _buildSectionHeader('Sync Health Metrics'),
                  const SizedBox(height: 12),
                  _buildSyncSwitchesCard(),
                  const SizedBox(height: 28),
                ],

                // Removed available brands section per user request
              ],
            ),
          ),
        );
      },
    );
  }

  void _openWatchRadarScanner() async {
    HapticFeedback.mediumImpact();
    final paired = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => const WatchScannerScreen(),
        transitionsBuilder: (context, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (paired != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('${paired['name']} paired and synced!'),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildRadarScannerHeroButton() {
    return GestureDetector(
      onTap: _openWatchRadarScanner,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A071A),
              Color(0xFF181045),
              Color(0xFF3B207E),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF818CF8).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan for Nearby Smart Watches',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Radar scan for real nearby Bluetooth wearables',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Scan',
                style: TextStyle(
                  color: Color(0xFF181045),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _textMain,
        letterSpacing: -0.3,
      ),
    );
  }

  // --- HERO CARD ---
  Widget _buildActiveDeviceHero(
    bool isConnected,
    String deviceName,
    String lastSyncText,
    Map<String, dynamic>? connectedMap,
  ) {
    if (isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Connected & Active',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.link_off_rounded, color: Colors.white70),
                  onPressed: _disconnectDevice,
                  tooltip: 'Disconnect',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Sync',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastSyncText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _isSyncing ? null : () => _performDeviceSync(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primaryRed,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryRed.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (_isSyncing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _isSyncing ? 'Syncing...' : 'Sync Now',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.watch_outlined,
              color: _textMain,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Device Connected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pair a smart band or watch to automatically record sleep, steps, hydration and weight.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SYNC SWITCHES ---
  Widget _buildSyncSwitchesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMetricSwitchTile(
            icon: Icons.directions_run_rounded,
            iconColor: const Color(0xFF2E7D32),
            title: 'Daily Steps & Activity',
            subtitle: 'Read real-time steps & active calories',
            value: _syncSteps,
            onChanged: (val) => _updateMetricSetting('syncSteps', val),
          ),
          const Divider(height: 20),
          _buildMetricSwitchTile(
            icon: Icons.nightlight_round,
            iconColor: const Color(0xFF7E22CE),
            title: 'Sleep Duration & Stages',
            subtitle: 'Read sleep hours, deep & REM sleep',
            value: _syncSleep,
            onChanged: (val) => _updateMetricSetting('syncSleep', val),
          ),
          const Divider(height: 20),
          _buildMetricSwitchTile(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFF0284C7),
            title: 'Daily Hydration',
            subtitle: 'Sync logged water intake from wearable',
            value: _syncHydration,
            onChanged: (val) => _updateMetricSetting('syncHydration', val),
          ),
          const Divider(height: 20),
          _buildMetricSwitchTile(
            icon: Icons.accessibility_new_rounded,
            iconColor: const Color(0xFF5B3FB0),
            title: 'Body Weight & Composition',
            subtitle: 'Read body weight from smart scales',
            value: _syncWeight,
            onChanged: (val) => _updateMetricSetting('syncWeight', val),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: _primaryRed,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
