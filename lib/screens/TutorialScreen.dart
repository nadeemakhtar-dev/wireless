import 'package:flutter/material.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      Tab(icon: Icon(Icons.rocket_launch_outlined), text: 'Start'),
      Tab(icon: Icon(Icons.memory_outlined), text: 'BLE Basics'),
      Tab(icon: Icon(Icons.usb_outlined), text: 'BLE vs Serial'),
      Tab(icon: Icon(Icons.wifi_tethering), text: 'Advertising'),
      Tab(icon: Icon(Icons.place_outlined), text: 'iBeacon'),
      Tab(icon: Icon(Icons.app_registration), text: 'Use Cases'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(

          iconTheme: IconThemeData(
            color: Colors.white
          ),
          backgroundColor: Color(0xFF2C5364),
          title: const Text('Wireless • Tutorial',style: TextStyle(color: Colors.white),),
          bottom: TabBar(
              tabs: tabs,
              unselectedLabelColor: Colors.white,
              labelColor: Colors.amber,
              isScrollable: true
          ),
        ),
        body: const TabBarView(
          children: [
            _StartTab(),
            _BleBasicsTab(),
            _BleVsSerialTab(),
            _AdvertisingTab(),
            _IBeaconTab(),
            _UseCasesTab(),
          ],
        ),
      ),
    );
  }
}

// ------------------- 1) START -------------------

class _StartTab extends StatelessWidget {
  const _StartTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _HeroCard(
          icon: Icons.wifi_tethering,
          title: 'Scan BLE & iBeacons with Wireless',
          subtitle:
          'This app listens for Bluetooth Low Energy (BLE) advertisements and detects iBeacon transmitters.\n'
              'You can scan, view UUID/Major/Minor, signal strength (RSSI), and rough proximity.',
        ),
        const SizedBox(height: 12),
        _SectionTitle('Quick Start'),
        _StepList(steps: const [
          ('Enable Bluetooth', 'Turn on Bluetooth (and Location Services on some Android phones).'),
          ('Open Scan', 'Tap Start Scan to begin listening for nearby BLE devices and iBeacons.'),
          ('View Results', 'Tap an item to see details. Use the UUID filter for iBeacons.'),
          ('Understand Distance', 'Proximity is estimated from RSSI and Tx power — it’s an approximation.'),
        ]),
        const SizedBox(height: 12),
        Card(
          color: cs.secondaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: cs.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Privacy note: scanning is passive — your phone only listens and does not connect to beacons.',
                    style: TextStyle(color: cs.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------- 2) BLE BASICS -------------------

class _BleBasicsTab extends StatelessWidget {
  const _BleBasicsTab();

  @override
  Widget build(BuildContext context) {
    return _ScrollCards(children: const [
      _InfoCard(
        icon: Icons.memory_outlined,
        title: 'BLE Architecture (high level)',
        bullets: [
          'BLE is designed for low power, intermittent data.',
          'Two major layers you’ll meet: GAP (advertising/roles) and GATT (services/characteristics).',
          'Devices usually advertise (to be discovered) and optionally accept connections for GATT data.',
        ],
      ),
      _InfoCard(
        icon: Icons.cast_rounded,
        title: 'GAP (Generic Access Profile)',
        bullets: [
          'Defines roles: Advertiser, Scanner/Observer, Broadcaster, and Central/Peripheral.',
          'Advertising packets announce presence or share small data without a connection.',
          'Your phone acts as a Scanner; beacons are typically Advertisers.',
        ],
      ),
      _InfoCard(
        icon: Icons.folder_open,
        title: 'GATT (Generic Attribute Profile)',
        bullets: [
          'Defines how data is structured when connected (Services → Characteristics).',
          'Use when you need to read/write sensor data, receive notifications, etc.',
          'iBeacons typically do NOT use GATT; you detect them via advertising only.',
        ],
      ),
      _DiagramCard(
        title: 'BLE data paths',
        lines: [
          '┌──────────────┐           ┌─────────────┐',
          '│  Advertiser  │  ~~~~~~~> │   Scanner   │  (GAP: advertising, no connection)',
          '└──────────────┘           └─────────────┘',
          '',
          '┌──────────────┐  connect  ┌─────────────┐',
          '│  Peripheral  │ <-------> │   Central   │  (GATT: services/characteristics)',
          '└──────────────┘           └─────────────┘',
        ],
      ),
    ]);
  }
}

// ------------------- 3) BLE vs BLUETOOTH SERIAL -------------------

class _BleVsSerialTab extends StatelessWidget {
  const _BleVsSerialTab();

  @override
  Widget build(BuildContext context) {
    return _ScrollCards(children: const [
      _InfoCard(
        icon: Icons.usb_outlined,
        title: 'BLE vs Bluetooth Classic (Serial/SPP)',
        bullets: [
          'Bluetooth Classic (SPP/Serial) streams continuous data (like a virtual COM port).',
          'BLE is event/packet oriented and optimized for low power, short bursts of data.',
          'Classic uses different radios/profiles (e.g., A2DP, SPP). BLE uses GAP/GATT.',
        ],
      ),
      _InfoCard(
        icon: Icons.tips_and_updates_outlined,
        title: 'What this means in practice',
        bullets: [
          'If your device exposes Serial (SPP), you need Bluetooth Classic libraries—not BLE.',
          'If your device is a beacon or sensor that advertises, your app can detect it without connecting (BLE).',
          'Many wearables/sensors use BLE and expose GATT; iBeacons are purely advertisers.',
        ],
      ),
    ]);
  }
}

// ------------------- 4) ADVERTISING -------------------

class _AdvertisingTab extends StatelessWidget {
  const _AdvertisingTab();

  @override
  Widget build(BuildContext context) {
    return _ScrollCards(children: const [
      _InfoCard(
        icon: Icons.wifi_tethering,
        title: 'What is an Advertiser?',
        bullets: [
          'Any BLE device broadcasting advertising packets over the air.',
          'Scanners (like your phone) listen; no connection is required to hear them.',
          'Advertising data can include device name, service UUIDs, or manufacturer data.',
        ],
      ),
      _InfoCard(
        icon: Icons.sensors_outlined,
        title: 'How scanning works',
        bullets: [
          'Your phone scans radio channels for advertising packets.',
          'When a packet matches interest (e.g., iBeacon pattern), it’s surfaced in the UI.',
          'RSSI (signal strength) gives a rough idea of distance (closer → stronger).',
        ],
      ),
    ]);
  }
}

// ------------------- 5) IBEACON -------------------

class _IBeaconTab extends StatelessWidget {
  const _IBeaconTab();

  @override
  Widget build(BuildContext context) {
    return _ScrollCards(children: const [
      _InfoCard(
        icon: Icons.place_outlined,
        title: 'What is an iBeacon?',
        bullets: [
          'An Apple-defined format for BLE advertising packets.',
          'Each packet carries: UUID (16B), Major (2B), Minor (2B), and Measured Tx Power (1B).',
          'Apps detect iBeacons by parsing manufacturer data (no GATT connection).',
        ],
      ),
      _DiagramCard(
        title: 'iBeacon packet layout (Manufacturer Data)',
        lines: [
          'Company ID (0x004C, Apple) | Type 0x02 | Len 0x15 | UUID (16B) | Major (2B) | Minor (2B) | TxPower (1B)',
          'e.g. 4C 00 02 15  E2 C5 6D B5 DF FB 48 D2 B0 60 D0 F5 A7 10 96 E0  00 01 00 01  C5',
        ],
      ),
      _InfoCard(
        icon: Icons.map_outlined,
        title: 'Why UUID / Major / Minor?',
        bullets: [
          'UUID identifies a group (e.g., all beacons in a venue).',
          'Major groups subsets (e.g., a floor); Minor pinpoints one beacon.',
          'Tx Power helps estimate distance together with live RSSI.',
        ],
      ),
    ]);
  }
}

// ------------------- 6) USE CASES & HOW THE APP WORKS -------------------

class _UseCasesTab extends StatelessWidget {
  const _UseCasesTab();

  @override
  Widget build(BuildContext context) {
    return _ScrollCards(children: const [
      _InfoCard(
        icon: Icons.business_outlined,
        title: 'Common applications of iBeacons',
        bullets: [
          'Indoor wayfinding (museums, malls, airports).',
          'Proximity prompts (exhibit info, coupons near displays).',
          'Check-in/check-out and occupancy.',
          'Asset tracking and zone presence.',
          'Contextual triggers for smart home or installations.',
        ],
      ),
      _InfoCard(
        icon: Icons.app_shortcut_outlined,
        title: 'How this app works (at a glance)',
        bullets: [
          'Scans BLE advertising packets in the foreground.',
          'Parses iBeacon frames (Apple company ID + layout) to list nearby beacons.',
          'Shows UUID/Major/Minor, name, RSSI, and rough proximity.',
          'Optional filters to narrow by UUID.',
        ],
      ),
      _InfoCard(
        icon: Icons.tips_and_updates_outlined,
        title: 'Tips & accuracy notes',
        bullets: [
          'Distance from RSSI is approximate; walls, people, and orientation affect it.',
          'For best results, keep the phone unobstructed and near line-of-sight.',
          'On some Android versions, Location Services must be ON to receive BLE ads.',
        ],
      ),
    ]);
  }
}

// ===================== Reusable UI widgets =====================

class _ScrollCards extends StatelessWidget {
  final List<Widget> children;
  const _ScrollCards({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _HeroCard({Key? key, required this.icon, required this.title, required this.subtitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36, color: cs.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      )),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> bullets;
  const _InfoCard({Key? key, required this.icon, required this.title, required this.bullets}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...bullets.map(
                        (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(b)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagramCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _DiagramCard({Key? key, required this.title, required this.lines}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mono = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      color: cs.onSurfaceVariant,
    );
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(lines.join('\n'), style: mono),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final List<(String, String)> steps;
  const _StepList({Key? key, required this.steps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          children: [
            ...steps.asMap().entries.map((e) {
              final idx = e.key + 1;
              final (title, body) = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: cs.primary,
                      child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(body, style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
