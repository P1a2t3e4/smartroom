import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase core package
import 'package:smartroom/firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/conflict_reporting_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/ra_ratings_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/join_group.dart';
import 'screens/group_creation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures widgets are initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Room',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/feedback': (context) => const FeedbackScreen(),
        '/conflict': (context) => const ConflictReportingScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/ra_ratings': (context) => const RaRatingScreen(),
        '/signUp': (context) => const SignUpScreen(),
        '/createGroup': (context) => const GroupCreationScreen(),
        '/joinGroup': (context) => const JoinGroupScreen(),
      },
    );
  }
}
