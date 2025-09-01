// main.dart — Complete example with gradient background and static top title
// No third‑party packages required
// Run as-is (after adding image assets to pubspec.yaml)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Scanner',
      theme: ThemeData.dark(),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (_) => const IntroScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

// ----------------------
// MODELS
// ----------------------
class OnboardingPageModel {
  final String keyId;
  final String title;
  final String description;
  final String assetImage; // path to your vertical image asset

  const OnboardingPageModel({
    required this.keyId,
    required this.title,
    required this.description,
    required this.assetImage,
  });
}

// ----------------------
// WIDGET: BLE ONBOARDING CAROUSEL (GRADIENT + STATIC TITLE)
// ----------------------
class BleOnboardingCarousel extends StatefulWidget {
  final List<OnboardingPageModel> pages; // supply 4 pages
  final bool autoScroll;
  final Duration autoScrollInterval; // default 2800ms
  final bool loop;
  final VoidCallback? onSkip;
  final VoidCallback? onDone;
  final ValueChanged<int>? onIndexChange;
  final Color primaryColor; // accents (dots & buttons)
  final String appTitle; // static title shown at top (white)

  const BleOnboardingCarousel({
    super.key,
    required this.pages,
    this.autoScroll = true,
    this.autoScrollInterval = const Duration(milliseconds: 2800),
    this.loop = true,
    this.onSkip,
    this.onDone,
    this.onIndexChange,
    this.primaryColor = const Color(0xFF10B981), // emerald
    this.appTitle = 'Wireless', // <-- change to your app name
  });

  @override
  State<BleOnboardingCarousel> createState() => _BleOnboardingCarouselState();
}

class _BleOnboardingCarouselState extends State<BleOnboardingCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _setupAutoScroll();
  }

  void _setupAutoScroll() {
    _timer?.cancel();
    if (!widget.autoScroll || widget.pages.length <= 1) return;
    _timer = Timer.periodic(
      widget.autoScrollInterval < const Duration(seconds: 1)
          ? const Duration(seconds: 1)
          : widget.autoScrollInterval,
          (_) {
        if (!mounted) return;
        final last = widget.pages.length - 1;
        final next = _index + 1;
        if (next > last) {
          if (!widget.loop) return; // stop at last
          _animateTo(0);
        } else {
          _animateTo(next);
        }
      },
    );
  }

  void _animateTo(int page) {
    setState(() => _index = page);
    widget.onIndexChange?.call(page);
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant BleOnboardingCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoScroll != widget.autoScroll ||
        oldWidget.autoScrollInterval != widget.autoScrollInterval ||
        oldWidget.loop != widget.loop ||
        oldWidget.pages.length != widget.pages.length) {
      _setupAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    if (pages.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: Container(
          // Gradient background
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Static app title at top
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Text(
                  widget.appTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Text(
                  "Designed & Developed by Aerofit Inc.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              // PAGES
              PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  widget.onIndexChange?.call(i);
                },
                itemBuilder: (context, i) {
                  final p = pages[i];
                  return _OnboardingSlide(
                    title: p.title,
                    description: p.description,
                    assetImage: p.assetImage,
                  );
                },
              ),

              // BOTTOM CONTROLS
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: widget.onSkip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF93A4B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    _Dots(
                      count: pages.length,
                      index: _index,
                      activeColor: widget.primaryColor,
                    ),

                    TextButton(
                      onPressed: () {
                        final last = pages.length - 1;
                        if (_index >= last) {
                          widget.onDone?.call();
                        } else {
                          _animateTo(_index + 1);
                        }
                      },
                      child: Text(
                        _index == pages.length - 1 ? 'Done' : 'Next',
                        style: TextStyle(
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------
// SLIDE
// ----------------------
class _OnboardingSlide extends StatelessWidget {
  final String title;
  final String description;
  final String assetImage;

  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.assetImage,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Tall vertical image taking ~65% height
        SizedBox(
          height: size.height * 0.65,
          width: size.width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Image.asset(
              assetImage,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Text block
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFFDAE5EE), // slightly lighter for gradient
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 88), // space for bottom bar
      ],
    );
  }
}

// ----------------------
// DOTS
// ----------------------
class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;

  const _Dots({
    required this.count,
    required this.index,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? activeColor : const Color(0xFF5F7586),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ----------------------
// INTRO SCREEN (feeds 4 pages)
// ----------------------
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = <OnboardingPageModel>[
      const OnboardingPageModel(
        keyId: 'blescan',
        title: 'BLE Scanner',
        description: 'Scans for BLE devices and provides detailed information about the BLE device',
        assetImage: 'assets/images/s1.JPG',
      ),
      const OnboardingPageModel(
        keyId: 'radar',
        title: 'Radar Scan',
        description: 'Discover nearby BLE devices in real time with a dynamic radar‑style sweep.',
        assetImage: 'assets/images/s5.JPG',
      ),
      const OnboardingPageModel(
        keyId: 'qrcode',
        title: 'QR Code Scan',
        description: 'Pair faster by scanning device QR codes; auto‑detects formats and connects instantly.',
        assetImage: 'assets/images/s6.JPG',
      ),
      const OnboardingPageModel(
        keyId: 'ibeacon',
        title: 'iBeacon Scanner',
        description: 'Monitor beacon regions, view UUID/major/minor, RSSI and proximity at a glance.',
        assetImage: 'assets/images/s2.JPG',
      ),
      const OnboardingPageModel(
        keyId: 'deviceInfo',
        title: 'Device Info',
        description: 'Get your own device info without navigating to other apps.',
        assetImage: 'assets/images/s7.JPG',
      ),
      const OnboardingPageModel(
        keyId: 'gatt',
        title: 'GATT Server',
        description: 'Host a local GATT server and broadcast custom advertisements for testing.',
        assetImage: 'assets/images/s3.JPG',
      ),

    ];

    return BleOnboardingCarousel(
      pages: pages,
      autoScroll: true,
      autoScrollInterval: const Duration(milliseconds: 3200), // customize duration here
      loop: true,
      onSkip: () => Navigator.of(context).pushReplacementNamed('/home'),
      onDone: () => context.go('/home'),
      primaryColor: const Color(0xFF10B981),
      appTitle: 'Wireless', // <-- your app title (white, fixed at top)
    );
  }
}

// ----------------------
// HOME PLACEHOLDER
// ----------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Home Screen', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}

// ----------------------
// ASSETS (pubspec.yaml reminder)
// ----------------------
// flutter:
//   assets:
//     - assets/images/1.png
//     - assets/images/2.png
//     - assets/images/3.png
//     - assets/images/4.png
