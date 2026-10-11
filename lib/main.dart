import 'package:ai_crop_disease_detection/firebase_options.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/login_screen.dart';
import 'package:ai_crop_disease_detection/View/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Show the "how it works" guide only on the first launch.
  bool onboardingSeen = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(OnboardingScreen.seenKey) ?? false;
  } catch (_) {
    // If preferences can't be read, showing the guide again is harmless.
  }

  runApp(MyApp(onboardingSeen: onboardingSeen));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.onboardingSeen = true});

  final bool onboardingSeen;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: onboardingSeen ? const LoginScreen() : const OnboardingScreen(),
    );
  }
}
