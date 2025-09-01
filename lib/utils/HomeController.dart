// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HomeController extends ChangeNotifier {
  bool isAdvertising = false;
  bool isBleOn = false;
  final List<String> devices = [];

  String get deviceName => switch (defaultTargetPlatform) {
    TargetPlatform.android => "BleDroid",
    TargetPlatform.iOS => "BleIOS",
    TargetPlatform.macOS => "BleMac",
    TargetPlatform.windows => "BleWin",
    _ => "TestDevice",
  };

  final manufacturerData = ManufacturerData(
    manufacturerId: 0x012D,
    data: Uint8List.fromList([
      0x03,
      0x00,
      0x64,
      0x00,
      0x45,
      0x31,
      0x22,
      0xAB,
      0x00,
      0x21,
      0x60,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00
    ]),
  );

  // Battery Service
  final String serviceBattery = "0000180F-0000-1000-8000-00805F9B34FB";
  final String characteristicBatteryLevel = "00002A19-0000-1000-8000-00805F9B34FB";
  // Test service
  final String serviceTest = "0000180D-0000-1000-8000-00805F9B34FB";
  final String characteristicTest = "00002A18-0000-1000-8000-00805F9B34FB";

  HomeController() {
    _initialize();
    _setupCallbacks();
  }

  void _initialize() async {
    try {
      await BlePeripheral.initialize();
    } catch (e) {
      debugPrint("InitializationError: $e");
    }
  }

  void _setupCallbacks() {
    // BLE state changes
    BlePeripheral.setBleStateChangeCallback((bool on) {
      isBleOn = on;
      notifyListeners();
    });

    // Advertising status
    BlePeripheral.setAdvertisingStatusUpdateCallback(
          (bool advertising, String? error) {
        isAdvertising = advertising;
        debugPrint("AdvertingStarted: $advertising, Error: $error");
        notifyListeners();
      },
    );

    // Subscriptions to characteristics
    BlePeripheral.setCharacteristicSubscriptionChangeCallback((
        String deviceId,
        String characteristicId,
        bool isSubscribed,
        String? name,
        ) {
      debugPrint(
        "onCharacteristicSubscriptionChange: $deviceId : $characteristicId $isSubscribed Name: $name",
      );

      final deviceLabel = "${name ?? deviceId} subscribed to $characteristicId";

      if (isSubscribed) {
        if (!devices.contains(deviceLabel)) {
          devices.add(deviceLabel);
          debugPrint("$deviceLabel adding");
        } else {
          debugPrint("$deviceLabel already exists");
        }
      } else {
        devices.removeWhere((e) => e == deviceLabel);
      }
      notifyListeners();
    });

    // Read requests
    BlePeripheral.setReadRequestCallback(
          (deviceId, characteristicId, offset, value) {
        debugPrint("ReadRequest: $deviceId $characteristicId : $offset : $value");
        return ReadRequestResult(value: utf8.encode("Hello World"));
      },
    );

    // Write requests
    BlePeripheral.setWriteRequestCallback(
          (deviceId, characteristicId, offset, value) {
        debugPrint("WriteRequest: $deviceId $characteristicId : $offset : $value");
        // return WriteRequestResult(status: 144);
        return null;
      },
    );

    // Android only: bond state
    BlePeripheral.setBondStateChangeCallback((deviceId, bondState) {
      debugPrint("OnBondState: $deviceId $bondState");
    });
  }

  // ---- Public API (call from your UI) ----

  Future<void> startAdvertising() async {
    debugPrint("Starting Advertising");
    await BlePeripheral.startAdvertising(
      services: [serviceBattery, serviceTest],
      localName: deviceName,
      manufacturerData: manufacturerData,
      addManufacturerDataInScanResponse: true,
    );
  }

  Future<void> addServices() async {
    try {
      final notificationControlDescriptor = BleDescriptor(
        uuid: "00002908-0000-1000-8000-00805F9B34FB",
        value: Uint8List.fromList([0, 1]),
        permissions: [
          AttributePermissions.readable.index,
          AttributePermissions.writeable.index,
        ],
      );

      await BlePeripheral.addService(
        BleService(
          uuid: serviceBattery,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: characteristicBatteryLevel,
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
              ],
              value: null,
              permissions: [AttributePermissions.readable.index],
            ),
          ],
        ),
      );

      await BlePeripheral.addService(
        BleService(
          uuid: serviceTest,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: characteristicTest,
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
                CharacteristicProperties.write.index,
              ],
              descriptors: [notificationControlDescriptor],
              value: null,
              permissions: [
                AttributePermissions.readable.index,
                AttributePermissions.writeable.index,
              ],
            ),
          ],
        ),
      );

      debugPrint("Services added");
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> getAllServices() async {
    final services = await BlePeripheral.getServices();
    debugPrint(services.toString());
  }

  Future<void> removeServices() async {
    await BlePeripheral.clearServices();
    debugPrint("Services removed");
  }

  /// Update characteristic value for all subscribed devices
  Future<void> updateCharacteristic() async {
    try {
      await BlePeripheral.updateCharacteristic(
        characteristicId: characteristicTest,
        value: utf8.encode("Test Data"),
      );
    } catch (e) {
      debugPrint("UpdateCharacteristicError: $e");
    }
  }
}
