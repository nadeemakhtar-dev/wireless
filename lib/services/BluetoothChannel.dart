import 'package:flutter/services.dart';

class BluetoothChannel{

  static const _ch = MethodChannel('com.nadeemakhtar.wireless/control');

  static Future<bool> isAvailable() async => await _ch.invokeMethod<bool>('isEnabled') ?? false;



  static Future<bool> isEnabled() async => await _ch.invokeMethod<bool>('isEnabled') ?? false;


  static Future<bool> requestEnable() async => await _ch.invokeMethod<bool>('requestEnable') ?? false;

  static Future<void> openSettings() async => await _ch.invokeMethod('openSettings');
}