import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wireless/iBeacon/screen/IBeaconScanScreen.dart';
import 'package:wireless/screens/ComingSoonScreen.dart';
import 'package:wireless/screens/FilterScreen.dart';
import 'package:wireless/screens/MainScreen.dart';
import 'package:wireless/screens/ScanScreen.dart';
import 'package:wireless/screens/SettingsScreen.dart';
import 'package:wireless/screens/SplashScreen.dart';
import 'package:wireless/screens/intro/IntroductionPage.dart';
import 'package:wireless/screens/intro/OnboardingScreen.dart';
import 'package:wireless/services/SharedPreferences.dart';
import 'package:wireless/utils/HomeController.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // Hide status + navigation bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Prefs.I.init();   // ✅ must call before using
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {



  return MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => HomeController()),
  ],
    child: MaterialApp(
        title: 'wireless',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue,
          ),
          useMaterial3: true,
        ),
        home:SplashScreen()
    )
  );
  }
}
