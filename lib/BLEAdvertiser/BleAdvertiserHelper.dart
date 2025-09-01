import 'dart:typed_data';
import 'package:flutter/services.dart';

class BleAdvertiser {
  static const _ch = MethodChannel('ble_peripheral');

  /// Start advertising
  static Future<bool> startAdv({
    String localName = 'My Phone',
    String? serviceUuid,
    int manufacturerId = 0x004C, // Apple ID example
    Uint8List? manufacturerData,
    int txPower = 2, // 0=ultra-low, 1=low, 2=medium, 3=high
    bool connectable = true,
    bool includeDeviceName = true,
  }) async {
    final args = {
      'localName': localName,
      'serviceUuid': serviceUuid,
      'manufacturerId': manufacturerId,
      'manufacturerData': manufacturerData ?? Uint8List(0),
      'txPower': txPower,
      'connectable': connectable,
      'includeDeviceName': includeDeviceName,
    };
    final ok = await _ch.invokeMethod<bool>('start', args);
    return ok ?? false;
  }

  /// Stop advertising
  static Future<void> stopAdv() async {
    await _ch.invokeMethod('stop');
  }

  /// Check support
  static Future<bool> isSupported() async {
    return await _ch.invokeMethod<bool>('isAdvertisingSupported') ?? false;
  }
}
