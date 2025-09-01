import 'dart:developer' as dev;
import 'dart:io';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../utils/HomeController.dart';

/// Lightweight in-app logger with timestamped lines you can also copy/clear.
class BleLog {
  static final ValueNotifier<List<String>> lines = ValueNotifier<List<String>>([]);
  static const _max = 500; // keep memory bounded

  static void add(String message) {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts] $message';
    dev.log(line, name: 'BLE'); // also send to IDE console
    final next = List<String>.from(lines.value)..add(line);
    if (next.length > _max) next.removeRange(0, next.length - _max);
    lines.value = next;
  }

  static void clear() => lines.value = <String>[];

  static Future<void> copyToClipboard(BuildContext context) async {
    final text = lines.value.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    }
  }
}

class GattServerScreen extends StatelessWidget {
  const GattServerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HomeController>();

    void logStateSnapshot(HomeController c) {
      BleLog.add('State: isBleOn=${c.isBleOn}, isAdvertising=${c.isAdvertising}, devices=${c.devices.length}');
    }

    Future<void> _askAllBlePermissions(BuildContext context) async {
      BleLog.add('Requesting BLE permissions…');

      // Always try plugin’s built-in prompt (if it does something on iOS/Android)
      try {
        await BlePeripheral.askBlePermission();
        BleLog.add('BlePeripheral.askBlePermission() completed');
      } catch (e) {
        BleLog.add('BlePeripheral.askBlePermission() error: $e');
      }

      // Android-specific runtime permissions
      if (Platform.isAndroid) {
        // On Android 12+ these are separate runtime grants
        final requests = <Permission>[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise, // <-- ADVERTISE
        ];

        // On Android < 12, scanning needs location.
        // permission_handler will no-op if not required.
        requests.add(Permission.location);

        final results = await requests.request();
        results.forEach((perm, status) {
          BleLog.add('Permission ${perm.value}: $status');
        });

        // Helpful toast if advertise is denied
        if (results[Permission.bluetoothAdvertise]?.isDenied == true ||
            results[Permission.bluetoothAdvertise]?.isPermanentlyDenied == true) {
          BleLog.add('⚠️ BLUETOOTH_ADVERTISE denied — advertising will fail.');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Advertising permission denied')),
            );
          }
        }
      }
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Peripheral'),
        centerTitle: true,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Show logs',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => _showLogsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Status',
                      subtitle: 'Current adapter & advertising state',
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 8),
                    _StatusRow(),
                    const SizedBox(height: 16),

                    _SectionHeader(
                      title: 'Core Actions',
                      subtitle: 'Permissions and GATT services',
                      icon: Icons.build_circle_outlined,
                    ),
                    const SizedBox(height: 8),
                    _ActionGrid(
                      onAskPermission: () async {
                        BleLog.add('Ask Permission pressed');
                        try {
                          // await BlePeripheral.askBlePermission();
                          await _askAllBlePermissions(context);
                          BleLog.add('Permissions request completed');
                        } catch (e, st) {
                          BleLog.add('Permissions error: $e');
                          dev.log('permission error', error: e, stackTrace: st);
                        }
                      },
                      onAddServices: () async {
                        BleLog.add('Add Services pressed');
                        try {
                          await controller.addServices();
                          BleLog.add('Services added');
                        } catch (e, st) {
                          BleLog.add('Add services FAILED: $e');
                          dev.log('add services error', error: e, stackTrace: st);
                        }
                      },
                      onGetServices: () async {
                        BleLog.add('Get Services pressed');
                        try {
                          await controller.getAllServices();
                          BleLog.add('Queried services successfully');
                        } catch (e, st) {
                          BleLog.add('Get services FAILED: $e');
                          dev.log('get services error', error: e, stackTrace: st);
                        }
                      },
                      onRemoveServices: () async {
                        BleLog.add('Remove Services pressed');
                        try {
                          await controller.removeServices();
                          BleLog.add('Services removed');
                        } catch (e, st) {
                          BleLog.add('Remove services FAILED: $e');
                          dev.log('remove services error', error: e, stackTrace: st);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    _SectionHeader(
                      title: 'Advertising',
                      subtitle: 'Start or stop broadcasting',
                      icon: Icons.campaign_outlined,
                    ),
                    const SizedBox(height: 8),
                    _AdvertisingCard(
                      onToggle: (value) async {
                        if (value) {
                          BleLog.add('Advertising start requested');
                          try {
                            await controller.startAdvertising();
                            BleLog.add('Advertising STARTED');
                            controller.isAdvertising = true;
                          } catch (e, st) {
                            BleLog.add('Start advertising FAILED: $e');
                            dev.log('start advertising error', error: e, stackTrace: st);
                          }
                        } else {
                          BleLog.add('Advertising stop requested');
                          try {
                            await BlePeripheral.stopAdvertising();
                            BleLog.add('Advertising STOPPED');
                            controller.isAdvertising = false;
                          } catch (e, st) {
                            BleLog.add('Stop advertising FAILED: $e');
                            dev.log('stop advertising error', error: e, stackTrace: st);
                          }
                        }
                        controller.notifyListeners();
                        logStateSnapshot(controller);
                      },
                    ),
                    const SizedBox(height: 16),

                    _SectionHeader(
                      title: 'Characteristic',
                      subtitle: 'Push updated value to subscribers',
                      icon: Icons.memory_outlined,
                    ),
                    const SizedBox(height: 8),
                    _CharacteristicCard(
                      onUpdate: () async {
                        BleLog.add('Update Characteristic pressed');
                        try {
                          await controller.updateCharacteristic();
                          BleLog.add('Characteristic updated');
                        } catch (e, st) {
                          BleLog.add('Characteristic update FAILED: $e');
                          dev.log('update char error', error: e, stackTrace: st);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Quick inline log head (collapsed preview)
                    _InlineLogPreview(),
                  ],
                ),
              ),
            ),

            // Devices list
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Connected / Seen Devices',
                  subtitle: 'Devices that interacted with this peripheral',
                  icon: Icons.devices_other_outlined,
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: _DevicesList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        onViewServices: () async {
          BleLog.add('View Services pressed');
          try {
            await controller.getAllServices();
            BleLog.add('Services viewed/refreshed');
          } catch (e, st) {
            BleLog.add('View services FAILED: $e');
            dev.log('view services error', error: e, stackTrace: st);
          }
        },
        onToggleAdvertising: (isAdv) async {
          if (isAdv) {
            BleLog.add('Stop Advertising pressed');
            try {
              await BlePeripheral.stopAdvertising();
              controller.isAdvertising = false;
              BleLog.add('Advertising STOPPED');
            } catch (e, st) {
              BleLog.add('Stop advertising FAILED: $e');
              dev.log('stop advertising error', error: e, stackTrace: st);
            }
          } else {
            BleLog.add('Start Advertising pressed');
            try {
              await controller.startAdvertising();
              controller.isAdvertising = true;
              BleLog.add('Advertising STARTED');
            } catch (e, st) {
              BleLog.add('Start advertising FAILED: $e');
              dev.log('start advertising error', error: e, stackTrace: st);
            }
          }
          controller.notifyListeners();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'gatt-logs-fab',
        onPressed: () => _showLogsSheet(context),
        icon: const Icon(Icons.article_outlined),
        label: const Text('Logs'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Selector<HomeController, bool>(
            selector: (_, c) => c.isBleOn,
            builder: (_, isOn, __) => _StatusTile(
              label: 'Bluetooth',
              value: isOn ? 'On' : 'Off',
              icon: isOn ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isOn ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Selector<HomeController, bool>(
            selector: (_, c) => c.isAdvertising,
            builder: (_, isAdv, __) => _StatusTile(
              label: 'Advertising',
              value: isAdv ? 'Active' : 'Stopped',
              icon: isAdv ? Icons.campaign : Icons.campaign_outlined,
              color: isAdv ? theme.colorScheme.primary : theme.disabledColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onAskPermission,
    required this.onAddServices,
    required this.onGetServices,
    required this.onRemoveServices,
  });

  final Future<void> Function() onAskPermission;
  final Future<void> Function() onAddServices;
  final Future<void> Function() onGetServices;
  final Future<void> Function() onRemoveServices;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: onAskPermission,
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Ask Permission'),
        ),
        OutlinedButton.icon(
          onPressed: onAddServices,
          icon: const Icon(Icons.playlist_add_outlined),
          label: const Text('Add Services'),
        ),
        OutlinedButton.icon(
          onPressed: onGetServices,
          icon: const Icon(Icons.view_list_outlined),
          label: const Text('Get Services'),
        ),
        OutlinedButton.icon(
          onPressed: onRemoveServices,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remove Services'),
        ),
      ],
    );
  }
}

class _AdvertisingCard extends StatelessWidget {
  const _AdvertisingCard({required this.onToggle});
  final Future<void> Function(bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Toggle to start/stop BLE advertising'),
            ),
            Selector<HomeController, bool>(
              selector: (_, c) => c.isAdvertising,
              builder: (_, isAdv, __) => Switch(
                value: isAdv,
                onChanged: (value) => onToggle(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacteristicCard extends StatelessWidget {
  const _CharacteristicCard({required this.onUpdate});
  final Future<void> Function() onUpdate;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.memory_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Update characteristic value for connected centrals'),
            ),
            ElevatedButton.icon(
              onPressed: onUpdate,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Update'),
            )
          ],
        ),
      ),
    );
  }
}

class _InlineLogPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 8),
                const Expanded(child: Text('Logs (latest 5)')),
                TextButton(
                  onPressed: () => _showLogsSheet(context),
                  child: const Text('Open'),
                )
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<String>>(
              valueListenable: BleLog.lines,
              builder: (_, lines, __) {
                final last = lines.length <= 5 ? lines : lines.sublist(lines.length - 5);
                if (last.isEmpty) {
                  return const Text('No logs yet');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: last.map((e) => Text('• $e', maxLines: 2, overflow: TextOverflow.ellipsis)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesList extends StatefulWidget {

  @override
  State<_DevicesList> createState() => _DevicesListState();
}

class _DevicesListState extends State<_DevicesList> {
  int? _lastCount;

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (_, c, __) {

        final count = c.devices.length;
        // Log device count changes when the list rebuilds
        // Defer the log until AFTER this frame finishes building
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_lastCount != count) {
            BleLog.add('Devices rebuild: count=$count');
            _lastCount = count;
          }
        });

        if (count == 0) {
          return _EmptyState(
            title: 'No devices yet',
            message: 'Once a central scans or connects, it will appear here.',
            action: ElevatedButton.icon(
              onPressed: () async {
                BleLog.add('Refresh Services (empty state) pressed');
                try {
                  await c.getAllServices();
                  BleLog.add('Services refreshed (empty state)');
                } catch (e, st) {
                  BleLog.add('Refresh services FAILED: $e');
                  dev.log('refresh services error', error: e, stackTrace: st);
                }
              },
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Refresh Services'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: c.devices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final name = c.devices[index];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.devices_other_outlined),
                title: Text(name.isEmpty ? '(Unknown device)' : name),
                subtitle: const Text('Last seen just now'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  BleLog.add('Device tapped: ${name.isEmpty ? '(unknown)' : name}');
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_outlined, size: 42),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onViewServices,
    required this.onToggleAdvertising,
  });

  final Future<void> Function() onViewServices;
  final Future<void> Function(bool isCurrentlyAdvertising) onToggleAdvertising;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewServices,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Services'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Selector<HomeController, bool>(
                  selector: (_, c) => c.isAdvertising,
                  builder: (_, isAdv, __) => FilledButton.icon(
                    onPressed: () => onToggleAdvertising(isAdv),
                    icon: Icon(isAdv ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                    label: Text(isAdv ? 'Stop Advertising' : 'Start Advertising'),
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

/// Bottom sheet UI for logs
void _showLogsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.article_outlined),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('BLE Logs')),
                  IconButton(
                    tooltip: 'Copy all',
                    onPressed: () => BleLog.copyToClipboard(context),
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () => BleLog.clear(),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: BleLog.lines,
                    builder: (_, lines, __) {
                      if (lines.isEmpty) {
                        return const Center(child: Text('No logs yet'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: lines.length,
                        itemBuilder: (_, i) => SelectableText(lines[i]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
