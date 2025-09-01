import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:wireless/services/ConnectionManager.dart'; // your abstraction
import '../model/FavouriteModel.dart';
import '../services/SharedPreferences.dart';
import '../utils/ServiceCard.dart';

enum BondState { unknown, none, bonding, bonded, notAvailable }

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.device, required this.ble});
  final DiscoveredDevice device;
  final ConnectionManager ble;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  static const _bondChannel = MethodChannel('ble/bond'); // Android only

  ConnectionStateUpdate? _lastState;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  List<DiscoveredService> _services = [];
  bool _busy = false;

  BondState _bond = BondState.unknown;

  @override
  void initState() {
    super.initState();
    _connect();
    _loadBondState(); // query once on entry
    _loadIsSaved();
  }

  Future<void> _loadBondState() async {
    if (!Platform.isAndroid) {
      setState(() => _bond = BondState.notAvailable);
      return;
    }
    try {
      final int code = await _bondChannel.invokeMethod<int>('getBondState', {
        'deviceId': widget.device.id,
      }) ??
          -1;
      setState(() => _bond = _mapAndroidBond(code));
    } catch (_) {
      setState(() => _bond = BondState.unknown);
    }
  }

  BondState _mapAndroidBond(int code) {
    // Android constants:
    // BOND_NONE = 10, BOND_BONDING = 11, BOND_BONDED = 12
    switch (code) {
      case 10:
        return BondState.none;
      case 11:
        return BondState.bonding;
      case 12:
        return BondState.bonded;
      default:
        return BondState.unknown;
    }
  }

  Future<void> _pair() async {
    if (!Platform.isAndroid) return;
    try {
      setState(() => _bond = BondState.bonding);
      final bool ok = await _bondChannel.invokeMethod<bool>('createBond', {
        'deviceId': widget.device.id,
      }) ??
          false;
      setState(() => _bond = ok ? BondState.bonded : BondState.none);
    } catch (_) {
      setState(() => _bond = BondState.none);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pairing failed')),
        );
      }
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    _connSub?.cancel();

    _connSub = widget.ble.connect(widget.device.id).listen((s) async {
      // track last state as you already do
      setState(() => _lastState = s);

      // when connected
      if (s.connectionState == DeviceConnectionState.connected) {
        // ✅ expose globally so ScanScreen can show the "Connected device" bar
        if (widget.ble.current.value?.id != widget.device.id) {
          widget.ble.markConnected(widget.device);
        }

        // your existing discovery work
        final services = await widget.ble.discoverServices(widget.device.id);
        if (!mounted) return;
        setState(() => _services = services);
        _loadBondState(); // refresh bond after connect
      }

      // when a disconnect update arrives
      if (s.connectionState == DeviceConnectionState.disconnected) {
        if (widget.ble.current.value?.id == widget.device.id) {
          widget.ble.clearConnected(); // ✅ remove from header
        }
        if (mounted) setState(() => _busy = false);
      }
    }, onError: (e) {
      if (widget.ble.current.value?.id == widget.device.id) {
        widget.ble.clearConnected(); // ✅ also clear on error
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
      setState(() => _busy = false);
    }, onDone: () {
      // stream finished (disconnect); make sure UI clears
      if (widget.ble.current.value?.id == widget.device.id) {
        widget.ble.clearConnected(); // ✅
      }
      setState(() => _busy = false);
    });
  }


  Future<void> _disconnect() async {
    await widget.ble.disconnect(widget.device.id);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
  // In DeviceScreen State:
  bool _isSaved = false;
  bool _busyFav = false;



  Future<void> _loadIsSaved() async {
    final saved = Prefs.I.isFavourite(widget.device.id); // id+name stored via your Prefs
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSaved() async {
    if (_busyFav) return;
    setState(() => _busyFav = true);

    final displayName = (widget.device.name.isEmpty) ? widget.device.id : widget.device.name;

    if (_isSaved) {
      await Prefs.I.removeFavourite(widget.device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $displayName from favourites')),
        );
      }
    } else {
      await Prefs.I.addFavourite(FavouriteDevice(id: widget.device.id, name: displayName));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $displayName')),
        );
      }
    }

    if (mounted) setState(() {
      _isSaved = !_isSaved;
      _busyFav = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    final st = _lastState?.connectionState;
    final name = widget.device.name.isEmpty ? widget.device.id : widget.device.name;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF203A43),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: _isSaved ? 'Remove from favourites' : 'Save to favourites',
            onPressed: _busyFav ? null : _toggleSaved,
            icon: Icon(
              _isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: st == DeviceConnectionState.connected ? _disconnect : _connect,
            icon: Icon(st == DeviceConnectionState.connected ? Icons.link_off : Icons.link),
            tooltip: st == DeviceConnectionState.connected ? 'Disconnect' : 'Connect',
          ),
        ],
      ),

      body: _buildBody(st),
    );
  }

  Widget _buildBody(DeviceConnectionState? st) {
    final statusColor = {
      DeviceConnectionState.connecting: Colors.amber,
      DeviceConnectionState.connected: Colors.green,
      DeviceConnectionState.disconnected: Colors.red,
      DeviceConnectionState.disconnecting: Colors.orange,
    }[st ?? DeviceConnectionState.disconnected]!;

    final bondLabel = () {
      switch (_bond) {
        case BondState.notAvailable:
          return 'N/A';
        case BondState.none:
          return 'Not bonded';
        case BondState.bonding:
          return 'Bonding…';
        case BondState.bonded:
          return 'Bonded';
        case BondState.unknown:
        default:
          return 'Unknown';
      }
    }();

    final bondColor = {
      BondState.bonded: Colors.green,
      BondState.bonding: Colors.amber,
      BondState.none: Colors.red,
      BondState.notAvailable: Colors.blueGrey,
      BondState.unknown: Colors.grey,
    }[_bond]!;

    // Elegant header card
    final header = Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Connection + bond chips
            Row(
              children: [
                _StatusChip(
                  label: st?.name ?? 'Unknown',
                  color: statusColor,
                  icon: Icons.bluetooth_connected,
                ),
                // const SizedBox(width: 8),
                // _StatusChip(
                //   label: 'Pair: $bondLabel',
                //   color: bondColor,
                //   icon: Icons.verified_user,
                // ),
                const Spacer(),
                if (st == DeviceConnectionState.connected)
                  FilledButton.icon(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Color(0xFF203A43),),
                    ),
                    onPressed: _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _connect,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Color(0xFF203A43),),
                    ),
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Device meta
            Row(
              children: [
                const Icon(Icons.qr_code, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.device.id,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.signal_cellular_alt, size: 18),
                const SizedBox(width: 6),
                Text('${_guessRssi()} dBm', style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: st == DeviceConnectionState.connected ? () async {
                    final svcs = await widget.ble.discoverServices(widget.device.id);
                    if (!mounted) return;
                    setState(() => _services = svcs);
                  } : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Discover Services'),
                ),
                const SizedBox(width: 8),
                if (Platform.isAndroid)
                  OutlinedButton.icon(
                    onPressed: (_bond == BondState.none || _bond == BondState.unknown)
                        ? _pair
                        : null,
                    icon: const Icon(Icons.lock),
                    label: const Text('Pair'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    // Body states
    if (st == null || st == DeviceConnectionState.connecting) {
      return Column(
        children: [
          header,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (st == DeviceConnectionState.disconnected ||
        st == DeviceConnectionState.disconnecting) {
      return Column(
        children: [
          header,
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
            ),
          ),
        ],
      );
    }

    // Connected
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Services (${_services.length})',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        ..._services.map(
              (s) => ServiceCard(deviceId: widget.device.id, service: s, ble: widget.ble),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  int _guessRssi() {
    // DiscoveredDevice.rssi is only from scan time; keep it as a hint.
    return widget.device.rssi;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}
