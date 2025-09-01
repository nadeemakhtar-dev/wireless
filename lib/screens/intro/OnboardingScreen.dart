// === DROP-IN REPLACEMENT: OnboardingScreen (no Camera step; ask later) ===
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireless/screens/MainScreen.dart';
import 'package:wireless/widgets/OnboardingHeader/OnboardingHeader.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});
  final VoidCallback? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _index = 0;
  late List<_PermissionStep> _steps;
  bool _loading = true;

  final Map<Permission, PermissionStatus> _status = {};
  final Map<Permission, bool> _askedOnce = {};

  @override
  void initState() {
    super.initState();
    _initSteps();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _initSteps() async {
    final steps = <_PermissionStep>[];

    // ---- BLE permissions by platform / SDK ----
    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk >= 31) {
        steps.add(_PermissionStep(
          title: 'Bluetooth Access',
          subtitle: 'Needed to discover and connect to your BLE device.',
          lottie: 'assets/animations/bluetoothPermission.json',
          icon: Icons.bluetooth_rounded,
          requiredPermsBuilder: () async => {
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          },
        ));
      } else {
        steps.add(_PermissionStep(
          title: 'Location (Android 10–11)',
          subtitle: 'Required by Android to scan for nearby BLE devices.',
          lottie: 'assets/animations/location.json',
          icon: Icons.location_on_rounded,
          requiredPermsBuilder: () async => {Permission.locationWhenInUse},
        ));
      }
    } else if (Platform.isIOS) {
      steps.add(_PermissionStep(
        title: 'Bluetooth Access',
        subtitle: 'Needed to discover and connect to your BLE device.',
        lottie: 'assets/animations/bluetoothPermission.json',
        icon: Icons.bluetooth_rounded,
        requiredPermsBuilder: () async => {Permission.bluetooth},
      ));
    }

    // NOTE: Camera step intentionally removed. Ask for it later when needed.

    // Warm cache
    for (final s in steps) {
      s.requiredPerms = await s.requiredPermsBuilder();
      for (final p in s.requiredPerms) {
        _status[p] = await p.status;
      }
    }

    _steps = steps;
    _loading = false;
    _jumpToFirstPendingStep();
    if (mounted) setState(() {});
  }

  void _jumpToFirstPendingStep() {
    if (_steps.isEmpty) return;
    final firstPending = _steps.indexWhere((s) => !_isStepGranted(s));
    final target = (firstPending == -1) ? 0 : firstPending; // start from first missing (or 0)
    _index = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) _ctrl.jumpToPage(target);
    });
  }

  bool _isStepGranted(_PermissionStep step) =>
      step.requiredPerms.isEmpty ||
          step.requiredPerms.every((p) => (_status[p]?.isGranted ?? false));

  Future<void> _requestCurrentStep() async {
    if (_loading) return;
    final step = _steps[_index];

    for (final p in step.requiredPerms) {
      _askedOnce[p] = true;
    }

    final results = <Permission, PermissionStatus>{};
    for (final p in step.requiredPerms) {
      results[p] = await p.request();
    }

    // iOS: give CoreBluetooth time to settle
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    for (final p in step.requiredPerms) {
      _status[p] = await p.status;
    }
    if (mounted) setState(() {});

    final granted = _isStepGranted(step);

    bool needsSettings = false;
    if (Platform.isAndroid) {
      needsSettings = results.values.any((s) => s.isPermanentlyDenied);
    } else if (Platform.isIOS) {
      // For iOS BT, no permanentlyDenied. Only Settings if restricted or still denied after asking.
      needsSettings = step.requiredPerms.any((p) {
        final s = _status[p];
        if (s == PermissionStatus.restricted) return true;
        if (s == PermissionStatus.denied && (_askedOnce[p] ?? false)) return true;
        return false;
      });
    }

    if (!granted && needsSettings && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permission needed'),
          content: Text(
            Platform.isIOS
                ? 'Please enable the permission in iOS Settings to continue.'
                : 'You’ve permanently denied one or more permissions. Please enable them in Settings to continue.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open Settings')),
          ],
        ),
      );
      if (go == true) {
        await openAppSettings();
        for (final p in step.requiredPerms) {
          _status[p] = await p.status;
        }
        if (mounted) setState(() {});
      }
    }

    if (_isStepGranted(step)) {
      _goNext();
    }
  }

  void _goNext() {
    if (_index < _steps.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
      setState(() => _index += 1);
    } else {
      _finish(); // last page
    }
  }

  Future<void> _finish() async {
    // Finishing is always allowed so the user never gets stuck.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', true);

    widget.onFinished?.call();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _index == (_steps.length);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            buildBrandHeader(title: 'Wireless', tag: 'Aerofit Inc. '),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _steps.length,
                itemBuilder: (_, i) => _PermissionStepPage(
                  step: _steps[i],
                  granted: _isStepGranted(_steps[i]),
                ),
              ),
            ),

            // Non-last pages: Skip + Allow/Next
            // Last page: primary shows Finish
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  _Dots(count: _steps.length, index: _index),
                  const Spacer(),

                  // if (!isLast)
                    TextButton(
                      onPressed: _goNext, // Skip always enabled
                      child: const Text('Skip'),
                    ),
                  // if (!isLast) const SizedBox(width: 8),

                  FilledButton.icon(
                    onPressed: _isStepGranted(_steps[_index])
                        ? (isLast ? _finish : _goNext)
                        : _requestCurrentStep,
                    icon: Icon(
                      _isStepGranted(_steps[_index])
                          ? (isLast ? Icons.check_rounded : Icons.arrow_forward_rounded)
                          : Icons.lock_open_rounded,
                    ),
                    label: Text(
                      _isStepGranted(_steps[_index])
                          ? (isLast ? 'Finish' : 'Next')
                          : 'Allow',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      backgroundColor: const Color(0xFF203A43),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('© Aerofit Inc.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- VIEW WIDGETS ---------- */

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    final active = Theme.of(context).colorScheme.primary;
    final base = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: List.generate(count, (i) {
        final sel = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: sel ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: sel ? active : base,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _PermissionStepPage extends StatelessWidget {
  const _PermissionStepPage({required this.step, required this.granted});
  final _PermissionStep step;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const gradient = [Color(0xFF203A43), Color(0xFF2C5364)];
    return LayoutBuilder(
      builder: (_, c) => SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              height: c.maxHeight * .45,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Lottie.asset(step.lottie, fit: BoxFit.contain, repeat: true),
                  Positioned(right: 12, top: 12, child: _Badge(granted: granted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(step.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(step.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14.5, height: 1.35)),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 0), child: _PermList(perms: step.requiredPerms)),
            const SizedBox(height: 8),
            Text(
              granted ? 'Granted' : 'Tap Allow to continue',
              style: TextStyle(color: granted ? Colors.green[700] : cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.granted});
  final bool granted;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: granted ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(granted ? Icons.check_circle : Icons.info, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(granted ? 'Granted' : 'Required', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PermList extends StatelessWidget {
  const _PermList({required this.perms});
  final Set<Permission> perms;

  String _label(Permission p) {
    switch (p) {
      case Permission.bluetoothScan:
        return 'Bluetooth Scan (Android 12+)';
      case Permission.bluetoothConnect:
        return 'Bluetooth Connect (Android 12+)';
      case Permission.bluetooth:
        return 'Bluetooth (iOS)';
      case Permission.locationWhenInUse:
        return 'Location (While in Use)';
      default:
        return p.toString();
    }
  }

  IconData _icon(Permission p) {
    if (p == Permission.locationWhenInUse) return Icons.location_on_rounded;
    return Icons.bluetooth_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: perms
          .map(
            (p) => Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(_icon(p), color: cs.primary),
              const SizedBox(width: 10),
              Text(_label(p), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      )
          .toList(),
    );
  }
}

/* ---------- Model ---------- */
class _PermissionStep {
  _PermissionStep({
    required this.title,
    required this.subtitle,
    required this.lottie,
    required this.icon,
    required this.requiredPermsBuilder,
  });

  final String title;
  final String subtitle;
  final String lottie;
  final IconData icon;
  final Future<Set<Permission>> Function() requiredPermsBuilder;
  Set<Permission> requiredPerms = const {};
}
