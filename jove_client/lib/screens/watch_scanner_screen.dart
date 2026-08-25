import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class WatchScannerScreen extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onDevicePaired;

  const WatchScannerScreen({super.key, this.onDevicePaired});

  @override
  State<WatchScannerScreen> createState() => _WatchScannerScreenState();
}

class _WatchScannerScreenState extends State<WatchScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _streamController;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  String _statusText = 'Scanning for nearby smart watches & bands...';
  bool _isPairing = false;
  String? _pairingDeviceName;
  int _pairingProgress = 0;

  final List<Map<String, dynamic>> _discoveredDevices = [];
  final List<_StarParticle> _stars = [];

  @override
  void initState() {
    super.initState();

    // 1. Radar wave expanding animation
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 2. Glowing icon pulse & float animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // 3. Background stars twinkle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // 4. Data stream line pulse
    _streamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Generate random background ambient star particles
    final random = math.Random();
    for (int i = 0; i < 35; i++) {
      _stars.add(_StarParticle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2.2 + 0.8,
        opacity: random.nextDouble() * 0.7 + 0.3,
      ));
    }

    _startSimulatedDiscovery();
  }

  void _startSimulatedDiscovery() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _statusText = 'Searching Bluetooth Low Energy (BLE) frequencies...';
    });

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _discoveredDevices.add({
        'id': 'apple_watch_u2',
        'name': 'Apple Watch Ultra 2',
        'brand': 'Apple',
        'category': 'Smartwatch',
        'icon': Icons.apple,
        'color': Colors.white,
        'rssi': '-44 dBm',
        'signal': 0.96,
        'battery': 94,
        'mac': 'D8:30:62:8B:12:F1',
      });
      _statusText = '1 smart watch discovered nearby...';
    });

    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _discoveredDevices.add({
        'id': 'galaxy_watch_6',
        'name': 'Galaxy Watch 6 Classic',
        'brand': 'Samsung',
        'category': 'Wear OS Watch',
        'icon': Icons.watch_outlined,
        'color': const Color(0xFF38BDF8),
        'rssi': '-53 dBm',
        'signal': 0.88,
        'battery': 86,
        'mac': 'FC:F5:28:C0:4A:22',
      });
      _statusText = '2 smart watches discovered nearby...';
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _discoveredDevices.add({
        'id': 'mi_band_8',
        'name': 'Xiaomi Smart Band 8 Pro',
        'brand': 'Xiaomi',
        'category': 'Fitness Band',
        'icon': Icons.watch_rounded,
        'color': const Color(0xFFFF7A00),
        'rssi': '-62 dBm',
        'signal': 0.82,
        'battery': 91,
        'mac': 'E4:95:6E:12:4A:8B',
      });
      _statusText = '3 devices found. Tap to pair & sync.';
    });

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _discoveredDevices.add({
        'id': 'garmin_forerunner',
        'name': 'Garmin Forerunner 965',
        'brand': 'Garmin',
        'category': 'GPS Sports Watch',
        'icon': Icons.directions_run_rounded,
        'color': const Color(0xFF34D399),
        'rssi': '-69 dBm',
        'signal': 0.76,
        'battery': 78,
        'mac': 'A0:B1:C2:D3:E4:F5',
      });
      _discoveredDevices.add({
        'id': 'smart_scale_s2',
        'name': 'BLE Smart Body Scale S2',
        'brand': 'Withings',
        'category': 'Smart Scale',
        'icon': Icons.scale_outlined,
        'color': const Color(0xFFA78BFA),
        'rssi': '-74 dBm',
        'signal': 0.70,
        'battery': 98,
        'mac': '00:1A:7D:DA:71:13',
      });
      _statusText = 'Ready to connect. Select your watch or band.';
    });
  }

  // --- PAIR AND CONNECT DEVICE ---
  Future<void> _pairDevice(Map<String, dynamic> device) async {
    if (_isPairing) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isPairing = true;
      _pairingDeviceName = device['name'];
      _pairingProgress = 15;
    });

    // Step 1: Handshake
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _pairingProgress = 45);

    // Step 2: Configure Health Streams
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _pairingProgress = 85);

    // Step 3: Write to Firestore
    if (currentUser?.uid != null) {
      try {
        final now = DateTime.now();
        final String todayDate = DateFormat('yyyy-MM-dd').format(now);

        final Map<String, dynamic> connectedDeviceData = {
          'id': device['id'],
          'name': device['name'],
          'brand': device['brand'],
          'category': device['category'],
          'battery': device['battery'],
          'mac': device['mac'],
          'status': 'connected',
          'connectedAt': FieldValue.serverTimestamp(),
        };

        // Realistic seed data from watch
        final int initialSteps = 8420;
        final double initialSleep = 7.5;
        final int initialHydration = 2200;
        final double initialWeight = 68.5;

        WriteBatch batch = FirebaseFirestore.instance.batch();
        DocumentReference userRef =
            FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
        DocumentReference historyRef =
            userRef.collection('progress_history').doc(todayDate);

        batch.set(userRef, {
          'connectedDevice': connectedDeviceData,
          'deviceSyncSettings': {
            'syncSteps': true,
            'syncSleep': true,
            'syncHydration': true,
            'syncWeight': true,
            'autoSyncBackground': true,
          },
          'lastDeviceSync': FieldValue.serverTimestamp(),
          'steps': initialSteps,
          'sleep': initialSleep,
          'weight': initialWeight,
          'dailySteps.$todayDate': initialSteps,
          'dailySleep.$todayDate': initialSleep,
          'dailyHydration.$todayDate': initialHydration,
          'dailyWeight.$todayDate': initialWeight,
        }, SetOptions(merge: true));

        batch.set(historyRef, {
          'date': todayDate,
          'steps': initialSteps,
          'sleep': initialSleep,
          'hydration': initialHydration,
          'weight': initialWeight,
          'syncedViaDevice': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();
      } catch (e) {
        debugPrint('Error pairing device: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _pairingProgress = 100);
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (widget.onDevicePaired != null) {
      widget.onDevicePaired!(device);
    }

    Navigator.pop(context, device);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _streamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. AURA VIOLET/INDIGO COSMIC BACKGROUND (MATCHING USER REFERENCE)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0xFF0D0824),
                    Color(0xFF1B1147),
                    Color(0xFF331D78),
                    Color(0xFF6366F1),
                  ],
                  stops: [0.0, 0.35, 0.60, 0.75, 0.90, 1.0],
                ),
              ),
            ),
          ),

          // 2. AMBIENT GLOWING RADAR & STAR PARTICLES
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_radarController, _particleController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _CosmicRadarPainter(
                    radarProgress: _radarController.value,
                    starTwinkle: _particleController.value,
                    stars: _stars,
                  ),
                );
              },
            ),
          ),

          // 3. MAIN FOREGROUND CONTENT
          SafeArea(
            child: Column(
              children: [
                _buildTopHeader(),
                const SizedBox(height: 10),

                // Center visual animation (Star beacon connecting to Watch avatar)
                _buildCenterScannerAnimation(),

                const SizedBox(height: 20),

                // Dynamic Status Badge
                _buildStatusBanner(),

                const SizedBox(height: 16),

                // Discovered Devices List
                Expanded(
                  child: _buildDiscoveredDevicesList(),
                ),
              ],
            ),
          ),

          // 4. PAIRING OVERLAY (IF PAIRING IN PROGRESS)
          if (_isPairing) _buildPairingModalOverlay(),
        ],
      ),
    );
  }

  // --- TOP APP BAR ---
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Smart Device Radar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _discoveredDevices.clear();
                _statusText = 'Restarting Bluetooth scan...';
              });
              _startSimulatedDiscovery();
            },
          ),
        ],
      ),
    );
  }

  // --- CENTER VISUAL SCANNER (MATCHES USER IMAGE) ---
  Widget _buildCenterScannerAnimation() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _streamController]),
      builder: (context, _) {
        final floatOffset = math.sin(_pulseController.value * math.pi) * 6.0;

        return Container(
          height: 180,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // STREAMING DATA PULSES (Connecting Left & Right)
              Positioned(
                left: 100,
                right: 100,
                child: SizedBox(
                  height: 30,
                  child: CustomPaint(
                    painter: _DataStreamPainter(
                      progress: _streamController.value,
                    ),
                  ),
                ),
              ),

              // LEFT BEACON: 4-POINT GLOWING STAR (EXACT AS IMAGE)
              Positioned(
                left: 36,
                child: Transform.translate(
                  offset: Offset(0, -floatOffset),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _FourPointStarPainter(),
                    ),
                  ),
                ),
              ),

              // RIGHT NODE: FROSTED GLASS AVATAR WITH WATCH BADGE (EXACT AS IMAGE)
              Positioned(
                right: 36,
                child: Transform.translate(
                  offset: Offset(0, floatOffset),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.watch_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),

                      // TOP-RIGHT MINI FLOATING BADGE (AS IN USER IMAGE)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.bluetooth_audio_rounded,
                            color: Color(0xFF1E1E1E),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- STATUS BANNER ---
  Widget _buildStatusBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- DISCOVERED DEVICES LIST ---
  Widget _buildDiscoveredDevicesList() {
    if (_discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF818CF8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Listening for BLE beacons...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final String name = device['name'];
        final String category = device['category'];
        final String rssi = device['rssi'];
        final int battery = device['battery'];
        final Color brandColor = device['color'];
        final IconData icon = device['icon'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _pairDevice(device),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: brandColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: brandColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                category,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$rssi • $battery%',
                                style: const TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF4F46E5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Pair',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- PAIRING MODAL OVERLAY ---
  Widget _buildPairingModalOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_connected_rounded,
                  color: Color(0xFF818CF8),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Pairing with $_pairingDeviceName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pairingProgress < 50
                    ? 'Establishing Bluetooth handshake...'
                    : _pairingProgress < 90
                        ? 'Configuring Steps, Sleep & Hydration data stream...'
                        : 'Device connected successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _pairingProgress / 100.0,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 4-POINT GLOWING STAR PAINTER (MATCHES USER IMAGE) ---
class _FourPointStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double rOut = size.width * 0.48;

    // Draw 4-point star curve
    path.moveTo(cx, cy - rOut);
    path.quadraticBezierTo(cx, cy, cx + rOut, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + rOut);
    path.quadraticBezierTo(cx, cy, cx - rOut, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - rOut);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- DATA STREAM PULSE LINES PAINTER ---
class _DataStreamPainter extends CustomPainter {
  final double progress;

  _DataStreamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 2 parallel dashed lines
    final y1 = size.height * 0.35;
    final y2 = size.height * 0.65;

    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), paint);

    // Traveling light pulses
    final pulseX = progress * size.width;
    canvas.drawLine(
      Offset(pulseX, y1),
      Offset((pulseX + 24).clamp(0.0, size.width), y1),
      glowPaint,
    );
    canvas.drawLine(
      Offset((size.width - pulseX - 24).clamp(0.0, size.width), y2),
      Offset((size.width - pulseX).clamp(0.0, size.width), y2),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DataStreamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- COSMIC RADAR & STAR PARTICLES PAINTER ---
class _StarParticle {
  final double x, y, size, opacity;
  _StarParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
  });
}

class _CosmicRadarPainter extends CustomPainter {
  final double radarProgress;
  final double starTwinkle;
  final List<_StarParticle> stars;

  _CosmicRadarPainter({
    required this.radarProgress,
    required this.starTwinkle,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Star Particles
    for (final s in stars) {
      final starPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (s.opacity * (0.6 + 0.4 * starTwinkle)).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height * 0.75),
        s.size,
        starPaint,
      );
    }

    // 2. Concentric Radar Pulse Rings
    final center = Offset(size.width / 2, 160);
    final maxRadius = size.width * 0.75;

    for (int i = 0; i < 3; i++) {
      final double ringProgress = (radarProgress + i * 0.33) % 1.0;
      final double radius = ringProgress * maxRadius;
      final double alpha = (1.0 - ringProgress).clamp(0.0, 0.4);

      final ringPaint = Paint()
        ..color = const Color(0xFF818CF8).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicRadarPainter oldDelegate) => true;
}
