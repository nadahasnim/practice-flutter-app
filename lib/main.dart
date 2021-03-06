import 'package:flutter/material.dart';
import 'package:hello_world_app/screens/login_screen/login_screen.dart';
import 'package:hello_world_app/screens/splash_screen/splash_screen.dart';
import 'package:hello_world_app/utils/DeviceRegPreferences.dart';
import 'package:hello_world_app/utils/LoginPreferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './screens/main_screen/main_screen.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // create instance of loginprefs
  LoginPreferences.prefs = await SharedPreferences.getInstance();
  // create instance of deviceRegPrefs
  DeviceRegPreferences.prefs = await SharedPreferences.getInstance();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Absensi Online',
      onGenerateRoute: _routes(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }

  RouteFactory _routes() {
    return (settings) {
      final Map<String, dynamic> arguments = settings.arguments;
      Widget screen;
      switch (settings.name) {
        case SplashScreen.routeName:
          screen = SplashScreen();
          break;
        case LoginScreen.routeName:
          screen = LoginScreen(arguments['passedString']);
          break;
        case MainScreen.routeName:
          screen = MainScreen();
          break;
        default:
          return null;
      }

      return MaterialPageRoute(builder: (BuildContext context) => screen);
    };
  }
}
