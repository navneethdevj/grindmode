import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GrindModeApp());
}

class GrindModeApp extends StatelessWidget {
  const GrindModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GrindThemeRoot(
      initialTheme: GrindTheme.defaultBlue,
      child: Builder(
        builder: (context) {
          final c = AppColors.of(context);
          return MaterialApp(
            title: 'GrindMode',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: c.bg,
              fontFamily: 'Nunito',
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}