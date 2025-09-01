import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // ===== Keys for SharedPreferences =====
  static const _kByNameEnabled        = 'byNameEnabled';
  static const _kByRssiEnabled        = 'byRssiEnabled';
  static const _kByServiceUuidEnabled = 'byServiceUuidEnabled';
  static const _kFavoritesOnly        = 'favoritesOnly';
  static const _kNameText             = 'nameText';
  static const _kServiceUuidText      = 'serviceUuidText';
  static const _kRssiValue            = 'rssiValue';

  // Favourite devices storage
  static const _kFavDevicesList       = 'favoriteDevicesList';        // List<String> of device names/ids
  static const _kFavEnabledSet        = 'favoriteDevicesEnabledSet';  // List<String> of selected device names/ids

  // ===== State =====
  bool byNameEnabled = false;
  bool byRssiEnabled = false;
  bool byServiceUuidEnabled = false;
  bool favoritesOnly = false;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController serviceUuidCtrl = TextEditingController();
  double rssi = -100;

  // Favourite devices
  List<String> favoriteDevices = [];        // all favourites the app knows about
  Set<String> favFilterSelected = {};       // subset chosen to filter against

  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefsAndLoad();

    // Live-save text
    nameCtrl.addListener(() {
      debugPrint(_ts("[TEXT] Name changed -> ${nameCtrl.text}"));
      _saveString(_kNameText, nameCtrl.text);
    });
    serviceUuidCtrl.addListener(() {
      debugPrint(_ts("[TEXT] Service UUID changed -> ${serviceUuidCtrl.text}"));
      _saveString(_kServiceUuidText, serviceUuidCtrl.text);
    });
  }

  static String _ts(String msg) {
    final t = DateTime.now().toIso8601String();
    return "[$t] $msg";
  }

  Future<void> _initPrefsAndLoad() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      byNameEnabled        = _prefs!.getBool(_kByNameEnabled) ?? false;
      byRssiEnabled        = _prefs!.getBool(_kByRssiEnabled) ?? false;
      byServiceUuidEnabled = _prefs!.getBool(_kByServiceUuidEnabled) ?? false;
      favoritesOnly        = _prefs!.getBool(_kFavoritesOnly) ?? false;

      nameCtrl.text        = _prefs!.getString(_kNameText) ?? '';
      serviceUuidCtrl.text = _prefs!.getString(_kServiceUuidText) ?? '';
      rssi                 = (_prefs!.getDouble(_kRssiValue) ?? -100.0).clamp(-120.0, 0.0);

      // Load favourites + selection
      favoriteDevices      = List<String>.from(_prefs!.getStringList(_kFavDevicesList) ?? const []);
      final enabledList    = _prefs!.getStringList(_kFavEnabledSet) ?? const [];
      favFilterSelected    = enabledList.toSet();
    });

    debugPrint(_ts("[INIT] Loaded prefs -> "
        "byName=$byNameEnabled, byRssi=$byRssiEnabled, byServiceUuid=$byServiceUuidEnabled, "
        "favoritesOnly=$favoritesOnly, name='${nameCtrl.text}', uuid='${serviceUuidCtrl.text}', rssi=$rssi, "
        "favDevices=$favoriteDevices, favSelected=$favFilterSelected"));
  }

  // ------- Save helpers -------
  Future<void> _saveBool(String key, bool value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setBool(key, value);
    debugPrint(_ts("[SAVE] $key -> $value"));
  }

  Future<void> _saveString(String key, String value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(key, value);
    debugPrint(_ts("[SAVE] $key -> '$value'"));
  }

  Future<void> _saveDouble(String key, double value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setDouble(key, value);
    debugPrint(_ts("[SAVE] $key -> $value"));
  }

  Future<void> _saveStringList(String key, List<String> value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setStringList(key, value);
    debugPrint(_ts("[SAVE] $key -> $value"));
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    serviceUuidCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    // Persist current state (most things already persisted live)
    _saveBool(_kByNameEnabled, byNameEnabled);
    _saveBool(_kByRssiEnabled, byRssiEnabled);
    _saveBool(_kByServiceUuidEnabled, byServiceUuidEnabled);
    _saveBool(_kFavoritesOnly, favoritesOnly);
    _saveString(_kNameText, nameCtrl.text.trim());
    _saveString(_kServiceUuidText, serviceUuidCtrl.text.trim());
    _saveDouble(_kRssiValue, rssi);
    _saveStringList(_kFavEnabledSet, favFilterSelected.toList());

    final result = {
      'byNameEnabled': byNameEnabled,
      'name': nameCtrl.text.trim(),
      'byRssiEnabled': byRssiEnabled,
      'rssi': rssi.round(),
      'byServiceUuidEnabled': byServiceUuidEnabled,
      'serviceUuid': serviceUuidCtrl.text.trim(),
      'favoritesOnly': favoritesOnly,
      'favoriteDevicesSelected': favFilterSelected.toList(),
    };
    debugPrint(_ts("[APPLY] Filters applied -> $result"));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied & saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const headerColor = Color(0xFF203A43);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerColor,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Filter Parameters',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          // BY NAME
          SettingTile(
            title: 'BY NAME',
            switchValue: byNameEnabled,
            onSwitchChanged: (v) {
              debugPrint(_ts("[SWITCH] BY NAME -> $v"));
              setState(() => byNameEnabled = v);
              _saveBool(_kByNameEnabled, v);
            },
            child: TextField(
              controller: nameCtrl,
              enabled: byNameEnabled,
              decoration: const InputDecoration(
                hintText: 'Example - AEROFLEX',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),

          // BY RSSI
          SettingTile(
            title: 'BY RSSI',
            switchValue: byRssiEnabled,
            onSwitchChanged: (v) {
              debugPrint(_ts("[SWITCH] BY RSSI -> $v"));
              setState(() => byRssiEnabled = v);
              _saveBool(_kByRssiEnabled, v);
            },
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text('${rssi.round()} dBm',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Slider(
                    value: rssi,
                    min: -120,
                    max: 0,
                    divisions: 120,
                    label: '${rssi.round()} dBm',
                    thumbColor: Colors.black,
                    onChanged: byRssiEnabled
                        ? (v) {
                      setState(() => rssi = v);
                      debugPrint(_ts("[SLIDER] RSSI live -> ${v.round()}"));
                    }
                        : null,
                    onChangeEnd: (v) {
                      _saveDouble(_kRssiValue, v);
                      debugPrint(_ts("[SLIDER] RSSI saved -> ${v.round()}"));
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // BY SERVICE UUID
          SettingTile(
            title: 'BY SERVICE UUID',
            switchValue: byServiceUuidEnabled,
            onSwitchChanged: (v) {
              debugPrint(_ts("[SWITCH] BY SERVICE UUID -> $v"));
              setState(() => byServiceUuidEnabled = v);
              _saveBool(_kByServiceUuidEnabled, v);
            },
            child: TextField(
              controller: serviceUuidCtrl,
              enabled: byServiceUuidEnabled,
              decoration: const InputDecoration(
                hintText: 'E.G. 0000180D-0000-1000-8000-00805F9B34FB',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),

          // FAVORITES ONLY
          SettingTile(
            title: 'FAVORITES ONLY',
            switchValue: favoritesOnly,
            onSwitchChanged: (v) async {
              debugPrint(_ts("[SWITCH] FAVORITES ONLY -> $v"));
              setState(() => favoritesOnly = v);
              await _saveBool(_kFavoritesOnly, v);
            },
            // Child appears ONLY when favoritesOnly is true (per your requirement)
            child: favoritesOnly
                ? _FavoriteDevicesList(
              devices: favoriteDevices,
              selected: favFilterSelected,
              onToggle: (device, isSelected) {
                setState(() {
                  if (isSelected) {
                    favFilterSelected.add(device);
                  } else {
                    favFilterSelected.remove(device);
                  }
                });
                _saveStringList(_kFavEnabledSet, favFilterSelected.toList());
                debugPrint(_ts("[FAVORITE] '$device' -> $isSelected, selected=$favFilterSelected"));
              },
            )
                : null,
          ),

          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            child: const Text('APPLY FILTER'),
          ),
        ),
      ),
    );
  }
}

/// Shows favourite devices as a vertical list of toggles.
/// If `devices` is empty, shows a helpful placeholder.
class _FavoriteDevicesList extends StatelessWidget {
  const _FavoriteDevicesList({
    required this.devices,
    required this.selected,
    required this.onToggle,
  });

  final List<String> devices;
  final Set<String> selected;
  final void Function(String device, bool isSelected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "No favourite devices saved.\n"
              "Seed the list in SharedPreferences under 'favoriteDevicesList'.",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        ...devices.map((d) {
          final on = selected.contains(d);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _FavoriteDeviceTile(
              name: d,
              value: on,
              onChanged: (v) => onToggle(d, v),
            ),
          );
        }),
      ],
    );
  }
}

/// Single favourite device row with trailing switch (no grey borders)
class _FavoriteDeviceTile extends StatelessWidget {
  const _FavoriteDeviceTile({
    required this.name,
    required this.value,
    required this.onChanged,
  });

  final String name;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF203A43),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.black26,
          ),
        ],
      ),
    );
  }
}

/// A tile that ALWAYS shows its body (child) underneath the title,
/// and merely enables/disables interaction & dims it when the switch is OFF.
/// (Except for Favourites—its child appears only when ON, per requirement.)
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.title,
    required this.switchValue,
    required this.onSwitchChanged,
    this.child,
  });

  final String title;
  final bool switchValue;
  final ValueChanged<bool> onSwitchChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // For general tiles: keep child visible but dim when OFF.
    // For Favourites tile, caller passes null child when OFF.
    final body = child == null
        ? const SizedBox.shrink()
        : Opacity(
      opacity: switchValue ? 1.0 : 0.45,
      child: IgnorePointer(ignoring: !switchValue, child: child),
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
              ),
              Switch(
                value: switchValue,
                onChanged: onSwitchChanged,
                activeColor: Colors.white,                 // thumb when active
                activeTrackColor: const Color(0xFF203A43), // active track
                inactiveThumbColor: Colors.white,          // thumb when inactive
                inactiveTrackColor: Colors.black26,        // track when inactive
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 10),
            body,
          ],
        ],
      ),
    );
  }
}
