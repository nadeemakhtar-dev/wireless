// lib/splash_screen.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireless/screens/MainScreen.dart';

import 'BluetoothActivateScreen.dart';
import 'ScanScreen.dart';
import 'intro/OnboardingScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _ble = FlutterReactiveBle();
  Timer? _timer;
  String _version = 'v1.0.0'; // fallback
  bool isFirstTime = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadVersion();
    // Small splash delay, then route based on BT status
    _timer = Timer(const Duration(seconds: 4), _routeNext);


  }

  Future<void> _initServices() async {
    final prefs = await SharedPreferences.getInstance();


  }


  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('hasOnboarded') ?? false;
    return !seen;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', true);
  }

  /// Wait for a stable (non-unknown) BLE status briefly.
  Future<BleStatus> getStableBleStatus(FlutterReactiveBle ble) async {
    try {
      return await ble.statusStream
          .where((s) => s != BleStatus.unknown)
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return BleStatus.unknown;
    }
  }

  /// Is Bluetooth considered ON for routing decisions?
  bool isBluetoothOn(BleStatus status) {
    // Treat "ready" as ON; "poweredOff" as OFF; others are indeterminate -> false
    if (status == BleStatus.ready) return true;
    if (status == BleStatus.poweredOff) return false;
    return false;
  }

  /// Is Location Services ON? (Only required on Android for BLE scans)
  Future<bool> isLocationServicesOn() async {
    if (Platform.isAndroid) {
      return await Geolocator.isLocationServiceEnabled();
    }
    return true; // iOS does not require LS to be ON for central BLE usage
  }

  /// Convenience: are all preconditions satisfied?
  Future<bool> arePreconditionsSatisfied(FlutterReactiveBle ble) async {
    final status = await getStableBleStatus(ble);
    final btOn = isBluetoothOn(status);
    final locOn = await isLocationServicesOn();

    // Android requires BOTH BT & Location Services ON
    // iOS requires only BT ON
    if (Platform.isAndroid) {
      return btOn && locOn;
    } else {
      return btOn;
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version}');
    } catch (_) {}
  }

  Future<void> _routeNext() async {
    if (!mounted) return;
    // Grab the latest known status (first item from stream)

    // // 1) First-run check
    // if (await isFirstLaunch()) {
    //   developer.log('First launch → Onboarding', name: 'Splash');
    //   if (!mounted) return;
    //   Navigator.of(context).pushReplacement(
    //     MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    //   );
    //   // Mark as seen when onboarding completes (best done inside OnboardingScreen),
    //   // but if you want to mark immediately:
    //   // await markOnboardingSeen();
    //   return;
    // }

    // 2) Not first run → check preconditions
    final status = await getStableBleStatus(_ble);
    final btOn = isBluetoothOn(status);
    final locOn = await isLocationServicesOn();

    developer.log(
      'Post-onboarding checks',
      name: 'Splash',
      error: 'status=$status, btOn=$btOn, locOn=$locOn',
    );

    final goMain = Platform.isAndroid ? (btOn && locOn) : btOn;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => goMain ? HomePage() : const BluetoothActivateScreen(),
      ),
    );

    // BleStatus status;
    // try {
    //   // wait a bit for BLE stack to initialize
    //   status = await _ble.statusStream.first.timeout(const Duration(seconds: 2));
    // } catch (_) {
    //   status = BleStatus.unknown;
    // }

// Decide the destination
    final needsActivation = switch (status) {
      BleStatus.ready => false,
      _ => true, // poweredOff, unauthorized, unsupported, locationServicesDisabled, unknown
    };

// Print to console
    print('BLE status: $status, needsActivation: $needsActivation');

// Or log with a tag (shows up nicely in IDE / DevTools)
    developer.log(
      'needsActivation evaluated',
      name: 'BluetoothCheck',
      error: 'status=$status, needsActivation=$needsActivation',
    );



    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => needsActivation
            ? const BluetoothActivateScreen()
            : HomePage(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.85, end: 1.0),
                  builder: (context, scale, child) => Opacity(
                    opacity: (scale - 0.85) / (1.0 - 0.85),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: Lottie.asset(
                              'assets/animations/scan.json',
                              repeat: true,
                              reverse: false,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const _CircleLogo(), // Logo on top

                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Wireless',
                          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Aerofit Technologies INC.',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              // Positioned(
              //   left: 24, right: 24, bottom: 112,
              //   child: const Center(
              //     child: CircularProgressIndicator(strokeWidth: 4, valueColor: AlwaysStoppedAnimation(Colors.white54)),
              //   ),
              // ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _version,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        "Made with love in  🇮🇳",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        "© Copyright 2025",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleLogo extends StatelessWidget {
  const _CircleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [BoxShadow(blurRadius: 20, spreadRadius: 2, color: Colors.black26, offset: Offset(0, 8))],
      ),
      child: const Center(
        child: Icon(Icons.bluetooth_connected, size: 44, color: Colors.white),
      ),
    );
  }
}
