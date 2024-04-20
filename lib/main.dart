import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:project_ecg/home.dart';

void main() {

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home:AnimatedSplashScreen(
        backgroundColor: Colors.white,
        splash: Image(image:AssetImage('assets/images/rate.png'),width: 300,height: 300,),
        nextScreen: Home(),
        splashTransition: SplashTransition.fadeTransition,
      )
    );
  }
}
