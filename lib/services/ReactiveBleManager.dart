import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:reactive_ble_platform_interface/src/model/connection_state_update.dart';
import 'package:reactive_ble_platform_interface/src/model/discovered_device.dart';
import 'package:reactive_ble_platform_interface/src/model/discovered_service.dart';
import 'package:reactive_ble_platform_interface/src/model/uuid.dart';
import 'package:wireless/services/ConnectionManager.dart';

class ReactiveBleManager implements ConnectionManager{
  ReactiveBleManager(this._ble);

  final FlutterReactiveBle _ble;


  final _scanSubscriptions = <StreamSubscription>[];
  final _connSubscriptions = <String, StreamSubscription<ConnectionStateUpdate>>{};

  // expose BLE status
  Stream<BleStatus> get statusStream => _ble.statusStream;

  Future<BleStatus> get currentStatus async {
    // `statusStream` is a stream, so we grab the latest value
    return await _ble.statusStream.first;
  }

  /// Who is connected right now (null if none)
  final ValueNotifier<DiscoveredDevice?> current = ValueNotifier<DiscoveredDevice?>(null);

  // Call these from your DeviceScreen when state changes:
  void markConnected(DiscoveredDevice d) => current.value = d;
  void clearConnected() => current.value = null;

  @override
  Stream<ConnectionStateUpdate> connect(String deviceID, {Duration? timeout}) {
    // Cancel any previous underlying connection subscription
    _connSubscriptions[deviceID]?.cancel();

    // Turn the single-subscription stream into broadcast for consumers
    final controller = StreamController<ConnectionStateUpdate>.broadcast();

    final sub = _ble
        .connectToDevice(
      id: deviceID,
      connectionTimeout: timeout ?? const Duration(seconds: 15),
    )
        .listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: false,
    );

    _connSubscriptions[deviceID] = sub;
    return controller.stream; // broadcast → UI can safely listen
  }

  @override
  Future<void> disconnect(String deviceID) async{
    await _connSubscriptions[deviceID]?.cancel();
    _connSubscriptions.remove(deviceID);
  }

  @override
  Future<List<DiscoveredService>> discoverServices(String deviceID) async{
    return _ble.discoverServices(deviceID);
  }

  @override
  Future<List<int>> readCharacteristic({
    required String deviceID,
    required Uuid serviceID,
    required Uuid characteristicID}) async {

    final qc = QualifiedCharacteristic(
      deviceId: deviceID,
      serviceId: serviceID,
      characteristicId: characteristicID,
    );
    return _ble.readCharacteristic(qc);

  }



  @override
  Stream<DiscoveredDevice> scan({List<Uuid> withServices = const []}) {
   // Cancel prior scans

    for(final s in _scanSubscriptions){
      s.cancel();
    }
    _scanSubscriptions.clear();

    final controller = StreamController<DiscoveredDevice>.broadcast();
    final sub = _ble.scanForDevices(withServices: withServices).listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: true,
    );
    _scanSubscriptions.add(sub);
    return controller.stream;
  }

  @override
  Stream<List<int>> subscribeCharacteristic({
    required String deviceID,
    required Uuid serviceID,
    required Uuid characteristicID,
  }) {
    final qc = QualifiedCharacteristic(
      deviceId: deviceID,
      serviceId: serviceID,
      characteristicId: characteristicID,
    );
    return _ble.subscribeToCharacteristic(qc);
  }

  @override
  Future<void> writeCharacteristic({
    required String deviceID,
    required Uuid serviceID,
    required Uuid characteristicID,
    required List<int> value,
    bool withoutResponse = false})
  async
  {
    final qc = QualifiedCharacteristic(
      deviceId: deviceID,
      serviceId: serviceID,
      characteristicId: characteristicID,
    );
    if (withoutResponse) {
      await _ble.writeCharacteristicWithoutResponse(qc, value: value);
    } else {
      await _ble.writeCharacteristicWithResponse(qc, value: value);
    }

  }


}