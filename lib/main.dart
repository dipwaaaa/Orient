import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screen/login_signup_screen.dart';
import 'screen/landing_page/WelcomeScreen.dart';
import 'screen/onboarding/onboarding_chatbot_screen.dart'; // TAMBAH IMPORT INI
import 'screen/home/HomeScreen.dart';
import 'service/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'Orient',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error.toString());
        }

        // Jika sudah login
        if (snapshot.hasData && snapshot.data != null) {
          // CEK ONBOARDING STATUS DULU
          return FutureBuilder<bool>(
            future: _authService.hasCompletedOnboarding(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              if (onboardingSnapshot.hasError) {
                return _buildErrorScreen(onboardingSnapshot.error.toString());
              }

              // Jika belum complete onboarding, tampilkan chatbot
              if (onboardingSnapshot.data == false) {
                return const OnboardingChatbotScreen();
              }

              // Jika sudah onboarding, cek welcome screen
              return FutureBuilder<bool>(
                future: _authService.shouldShowWelcomeScreen(),
                builder: (context, welcomeSnapshot) {
                  if (welcomeSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingScreen();
                  }
                  if (welcomeSnapshot.hasError) {
                    return _buildErrorScreen(welcomeSnapshot.error.toString());
                  }
                  return welcomeSnapshot.data == true
                      ? const WelcomeScreen()
                      : const HomeScreen();
                },
              );
            },
          );
        }

        // Belum login
        return LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.00, 1.00),
            radius: 2.22,
            colors: [Color(0xFFFF6A00), Color(0xFFFFE100)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.00, 1.00),
            radius: 2.22,
            colors: [Color(0xFFFF6A00), Color(0xFFFFE100)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 60),
                const SizedBox(height: 20),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Retry by rebuilding
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF6A00),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}