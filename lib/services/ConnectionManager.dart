import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

abstract class ConnectionManager{

  // ---- NEW: global "current connected device" signal ----
  ValueListenable<DiscoveredDevice?> get current;
  void markConnected(DiscoveredDevice device);
  void clearConnected();


  Stream<DiscoveredDevice> scan({List<Uuid> withServices = const []});



  //Returns a stream of [ConnectionStateUpdate] events
Stream<ConnectionStateUpdate> connect(String deviceID, {Duration? timeout});



Future<void> disconnect(String deviceID);

Future<List<DiscoveredService>> discoverServices(String deviceID);

Future<List<int>> readCharacteristic({
  required String deviceID,
  required Uuid serviceID,
  required Uuid characteristicID
});

Future<void> writeCharacteristic({
    required String deviceID,
    required Uuid serviceID,
    required Uuid characteristicID,
    required List<int> value,
  bool withoutResponse = false,
});

Stream<List<int>> subscribeCharacteristic({
    required String deviceID,
  required Uuid serviceID,
  required Uuid characteristicID,
});




}