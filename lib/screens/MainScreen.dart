import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wireless/BLEAdvertiser/AdvertiserScreen.dart';
import 'package:wireless/iBeacon/screen/IBeaconScanScreen.dart';
import 'package:wireless/screens/AboutDevice.dart';
import 'package:wireless/screens/GattServer.dart';
import 'package:wireless/screens/ScanScreen.dart';
import 'package:wireless/screens/SettingsScreen.dart';

import 'ComingSoonScreen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int _index = 0;



  // Put your tab pages here. First is the scanner.
  late final List<Widget> _pages = const [
    ScanScreen(),
    IBeaconScannerScreen(), // your existing scanner sc reen
    AdvertisementComingSoonPage(),
    GattServerScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // initService();
  }

  //
  // Future<void> initService() async{
  //   if(mounted) {
  //     final prefs = await SharedPreferences.getInstance();
  //
  //     prefs?.setInt("scanDuration", 10);
  //     print("Duration of scan is ${prefs.getInt("scanDuration")}");
  //   }
  //
  //
  //
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional: a top app bar that changes per tab (simple version)
      // appBar: AppBar(
      //   title: Text(
      //     _index == 0
      //         ? 'Ble Scan'
      //         : _index == 1
      //         ? 'iBeacon Sca'
      //         : 'About',
      //   ),
      // ),
      //

      // Keep state alive when switching tabs
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),

      // Material 3 NavigationBar (or use BottomNavigationBar if you prefer)
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching_outlined),
            selectedIcon: Icon(Icons.bluetooth_searching),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.ant_circle_fill),
            selectedIcon: Icon(CupertinoIcons.ant_circle),
            label: 'iBeacon',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.dot_radiowaves_left_right),
            selectedIcon: Icon(CupertinoIcons.dot_radiowaves_right),
            label: 'Advertiser',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.square_stack_3d_up),
            selectedIcon: Icon(CupertinoIcons.square_stack_3d_up_fill),
            label: 'Gatt Server',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.settings_solid),
            selectedIcon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
