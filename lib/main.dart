import 'package:ai_crop_disease_detection/firebase_options.dart';
import 'package:ai_crop_disease_detection/Services/auth_services.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/admin_screen.dart';
import 'package:ai_crop_disease_detection/View/agriculture_expert_screen.dart';
import 'package:ai_crop_disease_detection/View/farmer_screen.dart';
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

  // Stay logged in, so a farmer can open the app and check a leaf offline.
  final role = await AuthServices().savedSessionRole();

  runApp(MyApp(onboardingSeen: onboardingSeen, role: role));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.onboardingSeen = true, this.role});

  final bool onboardingSeen;

  /// Role of the user still signed in on this phone, if any.
  final String? role;

  Widget get _firstScreen {
    switch (role?.toLowerCase()) {
      case "farmer":
        return const FarmerScreen();
      case "expert":
        return const AgricultureExpertScreen();
      case "admin":
        return const AdminScreen();
    }
    return onboardingSeen ? const LoginScreen() : const OnboardingScreen();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _firstScreen,
    );
  }
}
