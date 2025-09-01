// lib/screens/radar_scan_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:lottie/lottie.dart';
import 'package:wireless/services/ConnectionManager.dart';
import 'package:wireless/widgets/RadarFooter.dart';

class RadarScanScreen extends StatefulWidget {
  const RadarScanScreen({super.key, required this.ble});
  final ConnectionManager ble;

  @override
  State<RadarScanScreen> createState() => _RadarScanScreenState();
}

class _RadarScanScreenState extends State<RadarScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  StreamSubscription<DiscoveredDevice>? _scanSub;
  final _devices = <String, DiscoveredDevice>{};
  bool _scanning = false;
  Timer? _autoStop;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _startScan();
  }

  void _startScan() {
    _devices.clear();
    setState(() => _scanning = true);
    _scanSub?.cancel();
    _scanSub = widget.ble.scan().listen((d) {
      // keep unnamed devices out
      if (d.name.isEmpty) return;
      setState(() => _devices[d.id] = d);
    }, onError: (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan error: $e')));
      setState(() => _scanning = false);
    }, onDone: () {
      if (!mounted) return;
      setState(() => _scanning = false);
    });

    _autoStop?.cancel();
    _autoStop = Timer(const Duration(seconds: 15), _stopScan);
  }

  void _stopScan() {
    _scanSub?.cancel();
    _autoStop?.cancel();
    if (mounted) setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _autoStop?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // --- Distance bucketing ---
  bool _isNear(DiscoveredDevice d) => d.rssi >= -60; // tweak if needed
  // Optionally add a middle band if you want 3 buckets:
  // bool _isMid(DiscoveredDevice d) => d.rssi < -60 && d.rssi >= -80;

  // Map RSSI to [0..1] radius (0=center, 1=edge)
  double _radiusFromRssi(int rssi) {
    // clamp RSSI in [-100, -40], then invert so stronger signal sits nearer center
    final clamped = rssi.clamp(-100, -40);
    final t = (clamped + 100) / 60.0; // 0..1 (−100 -> 0, −40 -> 1)
    return 1.0 - t; // 0 (strong) near center, 1 (weak) near edge
  }

  double _angleFromId(String id) {
    // stable pseudo-random angle from device id
    final h = id.codeUnits.fold<int>(0, (p, c) => (p * 31 + c) & 0x7fffffff);
    return (h % 360) * pi / 180.0;
  }

  @override
  Widget build(BuildContext context) {
    final near = _devices.values.where(_isNear).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final far = _devices.values.where((d) => !_isNear(d)).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white
        ),
        title: const Text('Radar Scan',style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF203A43),
        actions: [
          IconButton(
            tooltip: _scanning ? 'Stop scan' : 'Start scan',
            onPressed: _scanning ? _stopScan : _startScan,
            icon: Icon(_scanning ? Icons.stop_circle_outlined : Icons.play_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          // Radar animation
          Expanded(
            flex: 6,
            child: LayoutBuilder(
              builder: (context, c) {
                final size = min(c.maxWidth, c.maxHeight);
                return Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Radar animation
                        Positioned.fill(
                          child: Lottie.asset(
                            'assets/animations/scan.json',
                            width: 300,
                            height: 300,
                            repeat: _scanning,
                          ),
                        ),
                        Center(
                          child: Icon(
                            Icons.bluetooth_audio,
                            color: Colors.blueGrey,
                            size: 40,

                          ),
                        ),

                        // Device dots overlay
                        ..._devices.values.map((d) {
                          final letter = d.name.isNotEmpty ? d.name[0].toUpperCase() : '?';
                          return Positioned(
                            // still compute cx, cy from RSSI & angle if you want radial positioning
                            left: 150 + Random().nextInt(100) - 18, // placeholder example
                            top: 150 + Random().nextInt(100) - 18,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(d),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(letter, style: const TextStyle(color: Colors.white)),
                              ),
                            ),
                          );
                        }),
                        // Device dots
                        ..._devices.values.map((d) {
                          final r = _radiusFromRssi(d.rssi) * 0.45; // keep within rings
                          final theta = _angleFromId(d.id);
                          final cx = size / 2 + size * r * cos(theta);
                          final cy = size / 2 + size * r * sin(theta);
                          final letter = d.name.isNotEmpty ? d.name[0].toUpperCase() : '?';
                          return Positioned(
                            left: cx - 18,
                            top: cy - 18,
                            child: Tooltip(
                              message: '${d.name}\n${d.id}\n${d.rssi} dBm',
                              child: GestureDetector(
                                onTap: () async {
                                  // connect and navigate
                                  Navigator.of(context).pop(d); // return the device to previous screen if you prefer
                                },
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.85),
                                  child: Text(
                                    letter,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Lists
          Expanded(
            flex: 7,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                _SectionHeader(title: 'Near Devices', count: near.length, icon: Icons.near_me_rounded),
                ...near.map((d) => _deviceTile(d)),
                const SizedBox(height: 12),
                _SectionHeader(title: 'Far Devices', count: far.length, icon: Icons.waves_rounded),
                ...far.map((d) => _deviceTile(d)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      // 👇 Elegant, fixed footer
      bottomNavigationBar: RadarFooter(
        scanning: _scanning,
        near: near.length,
        far: far.length,
        onToggle: _scanning ? _stopScan : _startScan,
      ),
     
    );
  }

  Widget _deviceTile(DiscoveredDevice d) {
    final letter = d.name.isNotEmpty ? d.name[0].toUpperCase() : '?';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Text(letter, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
        title: Text(d.name),
        subtitle: Text(d.id),
        trailing: CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          child: Text(
            '${d.rssi}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        onTap: () async {
          // stop scan & connect
          _stopScan();
          if (!mounted) return;
          // Navigate back to a screen that does the connect,
          // or connect here if you prefer:
          // await widget.ble.connect(d.id).firstWhere((s) => s.connectionState == DeviceConnectionState.connected);
          Navigator.of(context).pop(d); // return selected device
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, required this.icon});
  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
          ),
        ],
      ),
    );
  }
}

// Paints the radar: concentric rings + rotating sweep
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});
  final double progress; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF90CAF9).withOpacity(.45);

    // Rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }

    // Grid cross
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF90CAF9).withOpacity(.3);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    // Sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi / 6, // 30° sweep
        colors: [
          const Color(0xFF42A5F5).withOpacity(.35),
          const Color(0xFF42A5F5).withOpacity(.02),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.srcOver;

    final angle = progress * 2 * pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final path = Path()..moveTo(0, 0)..arcTo(Rect.fromCircle(center: Offset.zero, radius: radius), 0, pi / 6, false)..close();
    canvas.drawPath(path, sweepPaint);
    canvas.restore();

    // Center dot
    final dot = Paint()..color = const Color(0xFF42A5F5);
    canvas.drawCircle(center, 3, dot);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}
