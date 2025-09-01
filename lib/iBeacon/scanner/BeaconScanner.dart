import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class IBeacon {
  final String uuid;
  final int major;
  final int minor;
  final int txPower;
  final String id;
  final String name;
  final int rssi;
  IBeacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPower,
    required this.id,
    required this.name,
    required this.rssi,
  });
}

class UniversalIBeaconScanner {
  final _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _sub;

  Stream<IBeacon> scan({ScanMode mode = ScanMode.lowLatency}) async* {
    final controller = StreamController<IBeacon>();
    _sub = _ble
        .scanForDevices(withServices: const [], scanMode: mode)
        .listen((d) {
      final beacon = _parseIBeacon(d.manufacturerData);
      if (beacon != null) {
        controller.add(IBeacon(
          uuid: beacon.uuid,
          major: beacon.major,
          minor: beacon.minor,
          txPower: beacon.txPower,
          id: d.id,
          name: d.name,
          rssi: d.rssi,
        ));
      }
    }, onError: controller.addError, onDone: controller.close);

    try {
      yield* controller.stream;
    } finally {
      await _sub?.cancel();
    }
  }

  void stop() => _sub?.cancel();

  // iBeacon layout: 4C 00 02 15 [16B UUID] [2B major] [2B minor] [1B tx]
  _Parsed? _parseIBeacon(Uint8List data) {
    if (data.length < 25) return null;
    if (data[0] != 0x4C || data[1] != 0x00) return null;   // Apple company ID
    if (data[2] != 0x02 || data[3] != 0x15) return null;   // iBeacon header

    final uuid = _bytesToUuid(data.sublist(4, 20));
    final major = (data[20] << 8) | data[21];
    final minor = (data[22] << 8) | data[23];

    int tx = data[24];
    if (tx > 127) tx -= 256; // signed int8

    return _Parsed(uuid, major, minor, tx);
  }

  String _bytesToUuid(List<int> b) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    final s = b.map(h).join();
    return '${s.substring(0,8)}-'
        '${s.substring(8,12)}-'
        '${s.substring(12,16)}-'
        '${s.substring(16,20)}-'
        '${s.substring(20)}';
  }
}

class _Parsed {
  final String uuid; final int major; final int minor; final int txPower;
  _Parsed(this.uuid, this.major, this.minor, this.txPower);
}
