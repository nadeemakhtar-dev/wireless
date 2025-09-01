import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with SingleTickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  // State
  bool _done = false;
  bool _flashOn = false;
  bool _paused = false;
  CameraFacing _facing = CameraFacing.back;

  // Scan line animation
  late final AnimationController _scanCtrl;
  late final Animation<double> _scanAnim;

  // Size of cutout (responsive)
  double get _cutoutSize {
    final w = MediaQuery.of(context).size.width;
    // comfortable window on phones/tablets
    return w * 0.72; // tweak
  }

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload handling
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  void _onQRViewCreated(QRViewController qrController) async {
    controller = qrController;

    // Initial capability states
    final flash = await controller?.getFlashStatus() ?? false;
    final info = await controller?.getCameraInfo();
    setState(() {
      _flashOn = flash;
      _facing = info ?? CameraFacing.back;
    });

    controller!.scannedDataStream.listen((scanData) async {
      if (_done) return;
      final value = scanData.code ?? '';
      if (value.isNotEmpty) {
        HapticFeedback.mediumImpact();
        _done = true;
        await controller?.pauseCamera();
        if (!mounted) return;
        Navigator.of(context).pop(value);
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool granted) {
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan')),
      );
    }
  }

  Future<void> _toggleFlash() async {
    await controller?.toggleFlash();
    final status = await controller?.getFlashStatus() ?? false;
    setState(() => _flashOn = status);
    HapticFeedback.selectionClick();
  }

  Future<void> _flipCamera() async {
    await controller?.flipCamera();
    final info = await controller?.getCameraInfo();
    setState(() => _facing = info ?? CameraFacing.back);
    HapticFeedback.selectionClick();
  }

  Future<void> _togglePause() async {
    if (_paused) {
      await controller?.resumeCamera();
    } else {
      await controller?.pauseCamera();
    }
    setState(() => _paused = !_paused);
    HapticFeedback.selectionClick();
  }

  Future<void> _retry() async {
    // If a code was captured but user wants to keep scanning
    _done = false;
    if (_paused) {
      await controller?.resumeCamera();
      setState(() => _paused = false);
    }
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cutout = _cutoutSize;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF203A43),
        title: const Text('Scan & Connect', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Retry',
            onPressed: _retry,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera + overlay
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
            overlay: QrScannerOverlayShape(
              borderColor: Colors.amber,
              borderRadius: 14,
              borderLength: 36,
              borderWidth: 8,
              cutOutSize: cutout,
            ),
          ),

          // Dim + gradient (outside cutout) for elegance
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Animated scan line inside cutout
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: cutout,
                  height: cutout,
                  child: AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) {
                      final y = (cutout - 2) * _scanAnim.value;
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: y,
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Hint text
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _paused ? 'Scanner paused' : 'Align QR within the frame',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // Glassy control bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: _ControlsBar(
              flashOn: _flashOn,
              facing: _facing,
              paused: _paused,
              onToggleFlash: _toggleFlash,
              onFlip: _flipCamera,
              onPauseResume: _togglePause,
              onRetry: _retry,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.flashOn,
    required this.facing,
    required this.paused,
    required this.onToggleFlash,
    required this.onFlip,
    required this.onPauseResume,
    required this.onRetry,
  });

  final bool flashOn;
  final CameraFacing facing;
  final bool paused;

  final VoidCallback onToggleFlash;
  final VoidCallback onFlip;
  final VoidCallback onPauseResume;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;
    final secondary = Colors.white70;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _RoundButton(
              icon: flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              label: flashOn ? 'Flash On' : 'Flash Off',
              onTap: onToggleFlash,
              primary: flashOn,
            ),
            const SizedBox(width: 10),
            _RoundButton(
              icon: Icons.cameraswitch_rounded,
              label: facing == CameraFacing.back ? 'Rear' : 'Front',
              onTap: onFlip,
            ),
            const SizedBox(width: 10),
            _RoundButton(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: paused ? 'Resume' : 'Pause',
              onTap: onPauseResume,
            ),
            const Spacer(),
            _PillButton(
              icon: Icons.refresh_rounded,
              label: 'Retry',
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.black : Colors.white;
    final bg = primary ? Colors.amber : Colors.white.withOpacity(0.1);
    final bd = primary ? Colors.amber : Colors.white24;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.black87 : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
