import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Modern + elegant BLE Advertiser screen
/// - Gradient/animated backdrop
/// - Glass cards, large primary toggle, subtle micro‑animations
/// - Fully responsive + scroll-safe (no RenderFlex overflows)
/// - Same logic as your original screen, with clearer UX
///
/// Route into this from your Coming Soon page ("/advertise-beta").
class AdvertiseScreen extends StatefulWidget {
  const AdvertiseScreen({super.key});

  @override
  State<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends State<AdvertiseScreen>
    with SingleTickerProviderStateMixin {
  final _peripheral = FlutterBlePeripheral();

  // UI controllers
  final _nameCtrl = TextEditingController(text: 'My Advertiser');
  final _uuidCtrl = TextEditingController(
    text: '0000180D-0000-1000-8000-00805F9B34FB',
  );

  bool _isAdvertising = false;
  bool _connectable = false; // Set true only if you have a GATT server
  String? _lastError;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _uuidCtrl.dispose();
    _pulse.dispose();
    // Best-effort stop on dispose.
    if (_isAdvertising) {
      _peripheral.stop();
    }
    super.dispose();
  }

  // ——————————————————————————————————
  // Permissions
  // ——————————————————————————————————
  Future<bool> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final sdk = info.version.sdkInt;

      Map<Permission, PermissionStatus> results = {};
      if (sdk >= 31) {
        results = await [
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ].request();
      } else {
        // Older Android often needs location for BLE hardware gating.
        results = await [
          Permission.locationWhenInUse,
        ].request();
      }

      final allGranted = results.values.every((s) => s.isGranted);
      if (!allGranted) {
        _showSnack('Bluetooth permissions are required to advertise. Please grant them in Settings.');
      }
      return allGranted;
    }

    if (Platform.isIOS) {
      // iOS prompts on first use.
      return true;
    }

    _showSnack('BLE advertising not supported on this platform.');
    return false;
  }

  // ——————————————————————————————————
  // BLE config builders
  // ——————————————————————————————————
  AdvertiseSettings _buildSettings() {
    return AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeLowLatency,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
      connectable: _connectable,
    );
  }

  AdvertiseData _buildData() {
    final name = _nameCtrl.text.trim();
    final uuid = _uuidCtrl.text.trim();

    return AdvertiseData(
      includeDeviceName: name.isNotEmpty,
      localName: name.isNotEmpty ? name : null,
      serviceUuid: uuid.isNotEmpty ? uuid : null,
      // Android-only extras (uncomment if needed):
      // manufacturerId: 0x02E5,
      // manufacturerData: [0xDE, 0xAD, 0xBE, 0xEF],
      // serviceData: {'180D': [0x42]},
    );
  }

  // ——————————————————————————————————
  // Actions
  // ——————————————————————————————————
  Future<void> _startAdvertising() async {
    setState(() => _lastError = null);

    final ok = await _ensurePermissions();
    if (!ok) return;

    // Basic validation to help users
    if (!_looksLikeUuid(_uuidCtrl.text.trim())) {
      final go = await _confirmDialog(
        title: 'UUID (128 bit version)',
        body:
        'Please make sure to use correct UUID to advertise (use UUID Generator) ',
      );
      if (!mounted || !go) return;
    }

    try {
      await _peripheral.start(
        advertiseData: _buildData(),
        advertiseSettings: _buildSettings(),
      );
      if (!mounted) return;
      setState(() => _isAdvertising = true);
      _showSnack('Advertising started');
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = e.toString());
      _showSnack('Failed to start advertising: $e');
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await _peripheral.stop();
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
      setState(() => _isAdvertising = false);
      _showSnack('Advertising stopped');
    }
  }

  bool _looksLikeUuid(String s) {
    final re = RegExp(r'^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\$');
    return re.hasMatch(s);
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label copied');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<bool> _confirmDialog({required String title, required String body}) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    ) ??
        false;
  }

  // ——————————————————————————————————
  // UI
  // ——————————————————————————————————
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('BLE Advertiser'),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          _AnimatedBackdrop(isDark: isDark, controller: _pulse),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status card
                      _StatusCard(isAdvertising: _isAdvertising, pulse: _pulse),
                      const SizedBox(height: 16),

                      // Settings card
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(
                              icon: Icons.tune_rounded,
                              title: 'Broadcast Settings',
                              subtitle: 'Name & Service UUID for discovery',
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LabeledField(
                                  label: 'Local Name',
                                  child: TextField(
                                    controller: _nameCtrl,
                                    enabled: !_isAdvertising,
                                    decoration: elegantDecoration(
                                      context,
                                      label: 'Local Name',
                                      hint: 'Shown in scanner results',
                                      prefixIcon: Icons.label_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'Service UUID',
                                  actions: [
                                    IconButton(
                                      tooltip: 'Copy UUID',
                                      icon: const Icon(Icons.copy_all_rounded),
                                      onPressed: () => _copy(_uuidCtrl.text, 'UUID'),
                                    ),
                                  ],
                                  child: TextField(
                                    controller: _uuidCtrl,
                                    enabled: !_isAdvertising,
                                    autocorrect: false,
                                    textInputAction: TextInputAction.done,
                                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f-]')),
                                      UpperCaseTextFormatter(),
                                    ],
                                    decoration: elegantDecoration(
                                      context,
                                      label: 'Service UUID (128-bit)',
                                      hint: 'e.g. 0000180D-0000-1000-8000-00805F9B34FB',
                                      prefixIcon: Icons.key_rounded,
                                      suffixActions: [
                                        IconButton(
                                          tooltip: 'Copy',
                                          icon: const Icon(Icons.content_copy_rounded),
                                          onPressed: () => _copy(_uuidCtrl.text, 'UUID'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              title: const Text('Connectable (requires a GATT server)'),
                              value: _connectable,
                              onChanged: _isAdvertising
                                  ? null
                                  : (v) => setState(() => _connectable = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Controls card
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(
                              icon: Icons.play_circle_outline,
                              title: 'Controls',
                              subtitle: 'Start/Stop advertising and view logs',
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: 220,
                                    child: ElevatedButton.icon(
                                      icon: Icon(_isAdvertising ? Icons.stop : Icons.play_arrow),
                                      label: Text(_isAdvertising ? 'Stop' : 'Start Advertising'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        textStyle: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w600),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _isAdvertising ? _stopAdvertising : _startAdvertising,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 220,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.description_outlined),
                                      label: const Text('Notes'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: () => _showNotesSheet(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_lastError != null) ...[
                              const SizedBox(height: 12),
                              _InlineError(message: _lastError!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showNotesSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: const [
            ListTile(
              leading: Icon(Icons.apple),
              title: Text('iOS limits'),
              subtitle: Text('Apps can advertise service UUID + local name; manufacturer/service data are ignored.'),
            ),
            ListTile(
              leading: Icon(Icons.android),
              title: Text('Android 12+ permissions'),
              subtitle: Text('Requires BLUETOOTH_SCAN / ADVERTISE / CONNECT at runtime.'),
            ),
            ListTile(
              leading: Icon(Icons.build_circle_outlined),
              title: Text('Connectable'),
              subtitle: Text('Enable only if a GATT server is implemented; otherwise keep OFF (beacon-style).'),
            ),
          ],
        ),
      ),
    );
  }
}

// ——————————————————————————————————
// Visual subcomponents
// ——————————————————————————————————

InputDecoration elegantDecoration(
    BuildContext context, {
      required String label,
      String? hint,
      IconData? prefixIcon,
      List<Widget>? suffixActions,
    }) {
  final theme = Theme.of(context);
  final surface = theme.colorScheme.surfaceVariant.withOpacity(0.65);

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    suffixIcon: (suffixActions != null && suffixActions.isNotEmpty)
        ? Row(mainAxisSize: MainAxisSize.min, children: suffixActions)
        : null,
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withOpacity(0.8),
        width: 2,
      ),
    ),
    hoverColor: surface,
  );
}

/// Makes typing UUIDs feel nicer: forces UPPERCASE (optional).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}


class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop({required this.isDark, required this.controller});
  final bool isDark;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final baseA = isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF);
    final baseB = isDark ? const Color(0xFF1F2937) : const Color(0xFFE0E7FF);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (math.sin(controller.value * math.pi * 2) + 1) / 2;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(baseA, Colors.purple.shade200, isDark ? 0.06 : 0.14)!,
                Color.lerp(baseB, Colors.blue.shade200, isDark ? 0.06 : 0.14)!,
              ],
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: 80 + 16 * t,
              left: -60,
              child: _blob(200, (isDark ? Colors.indigo : Colors.indigoAccent).withOpacity(0.12)),
            ),
            Positioned(
              bottom: 60 + 16 * (1 - t),
              right: -40,
              child: _blob(160, (isDark ? Colors.deepPurple : Colors.deepPurpleAccent).withOpacity(0.12)),
            ),
          ]),
        );
      },
    );
  }

  Widget _blob(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 60, spreadRadius: 10),
        ],
      ),
    ),
  );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child, this.actions});
  final String label;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const Spacer(),
            if (actions != null) ...actions!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isAdvertising, required this.pulse});
  final bool isAdvertising;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isAdvertising ? Colors.green : theme.colorScheme.outline;

    return _GlassCard(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [if (isAdvertising) BoxShadow(color: color.withOpacity(0.6), blurRadius: 12)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                isAdvertising ? 'Advertising… broadcasting your Service UUID' : 'Idle — press Start to begin advertising',
                key: ValueKey(isAdvertising),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (isAdvertising)
            FadeTransition(
              opacity: Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(
                parent: pulse,
                curve: Curves.easeInOut,
              )),
              child: Icon(Icons.waves_rounded, color: theme.colorScheme.primary),
            )
          else
            Icon(Icons.broadcast_on_home_outlined, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last error: $message',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
