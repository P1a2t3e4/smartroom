import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartroom/firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/conflict_reporting_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/ra_ratings_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/group_creation.dart';
import 'screens/roommate_agreement_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/duty_roster.dart';
import 'screens/ra_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String?> getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data()?['userType']?.toString();
      }
    }
    return null;
  }

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
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => LoginScreen(
                onLoginSuccess: ({required String userType}) {
                  Navigator.pushReplacementNamed(
                    context,
                    userType == 'RA' ? '/raDashboard' : '/dashboard',
                  );
                },
              ),
            );
          case '/dashboard':
            return MaterialPageRoute(builder: (context) => const DashboardScreen());
          case '/raDashboard':
            return MaterialPageRoute(builder: (context) => const RADashboard());
          case '/conflict':
            return MaterialPageRoute(builder: (context) => const ConflictReportingScreen());
          case '/notifications':
            return MaterialPageRoute(builder: (context) => const NotificationsScreen());
          case '/ra_ratings':
            return MaterialPageRoute(builder: (context) => const RaRatingScreen());
          case '/signUp':
            return MaterialPageRoute(builder: (context) => const SignUpScreen());
          case '/createGroup':
            return MaterialPageRoute(builder: (context) => const GroupCreationScreen());
          case '/rm_agreement':
            return MaterialPageRoute(builder: (context) => const RoommateAgreementForm());
          case '/tasks':
            return MaterialPageRoute(builder: (context) => const TasksPage());
          case '/duty_roster':
            return MaterialPageRoute(builder: (context) => const DutyRosterPage());

          default:
            return MaterialPageRoute(
              builder: (context) => LoginScreen(
                onLoginSuccess: ({required String userType}) {
                  Navigator.pushReplacementNamed(
                    context,
                    userType == 'RA' ? '/raDashboard' : '/dashboard',
                  );
                },
              ),
            );
        }
      },
    );
  }
}