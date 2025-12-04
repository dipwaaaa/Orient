import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'screen/login_signup_screen.dart';
import 'screen/landing_page/welcome_screen.dart';
import 'screen/onboarding/onboarding_chatbot_screen.dart';
import 'screen/home/home_screen.dart';
import 'service/auth_service.dart';
import 'provider/auth_provider.dart' as auth_notifier;
import 'widget/Animated_Gradient_Background.dart';
import 'utilty/app_responsive.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ Provider 1: AuthService (no dependencies)
        // Singleton instance untuk akses Firebase authentication
        // Available di semua widgets via: context.read<AuthService>()
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),

        // ✅ Provider 2: AuthStateProvider (depends on AuthService)
        // State management untuk logout dengan global access
        // Available di semua widgets via: Provider.of<AuthStateProvider>(context)
        // ⚠️ NOTE: Menggunakan auth_notifier.AuthStateProvider untuk avoid conflict
        //          dengan Firebase's built-in AuthProvider
        ChangeNotifierProvider(
          create: (context) => auth_notifier.AuthStateProvider(
            // Get AuthService instance yang sudah dibuat di atas
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
      ],
      // Root MaterialApp - wrapped dengan Provider untuk global access
      child: MaterialApp(
        title: 'Orient',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        // SplashScreen: Entry point setelah app launch
        home: const SplashScreen(),
      ),
    );
  }
}

// ============================================================
// SPLASH SCREEN - App Launch & Auth Check
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // Auth service untuk check login status
  final AuthService _authService = AuthService();

  // Animation controller untuk fade in logo
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup fade animation untuk logo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start animation
    _animationController.forward();

    // Check auth status dan navigate setelah 5 detik
    _checkAuthAndNavigate();
  }

  /// Check user auth status dan navigate ke screen yang sesuai
  /// Flow:
  /// 1. User logged in + onboarding incomplete → OnboardingChatbot
  /// 2. User logged in + onboarding complete + new user → WelcomeScreen
  /// 3. User logged in + onboarding complete + returning user → HomeScreen
  /// 4. User not logged in → LoginScreen
  Future<void> _checkAuthAndNavigate() async {
    // Minimal splash screen duration: 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;

    try {
      // Check apakah user sudah login
      final user = _authService.currentUser;

      if (user != null) {
        // User sudah login, check onboarding status
        final hasCompletedOnboarding = await _authService.hasCompletedOnboarding();

        if (!hasCompletedOnboarding) {
          // ❌ Belum complete onboarding → OnboardingChatbot
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingChatbotScreen(),
              ),
            );
          }
        } else {
          // ✅ Sudah onboarding, check welcome screen status
          final shouldShowWelcome = await _authService.shouldShowWelcomeScreen();

          if (mounted) {
            if (shouldShowWelcome) {
              // 🆕 User baru → WelcomeScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WelcomeScreen(),
                ),
              );
            } else {
              // 👤 User returning → HomeScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            }
          }
        }
      } else {
        // ❌ User belum login → LoginScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking auth: $e');
      // Fallback: redirect ke LoginScreen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize responsive values (untuk consistency di semua screen)
    AppResponsive.init(context);

    return Scaffold(
      body: AnimatedGradientBackground(
        duration: const Duration(seconds: 3),
        radius: 2.22,
        colors: const [
          Color(0xFFFF6A00), // Orange
          Color(0xFFFFE100), // Yellow
        ],
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Image.asset(
              'assets/image/Orient.png',
              width: 225,
              height: 79,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AUTH WRAPPER - Alternative Auth Flow Management
// (Optional: Jika ingin StreamBuilder untuk real-time auth updates)
// ============================================================
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
      // Real-time listen to Firebase auth state changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // Error state
        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error.toString());
        }

        // User logged in
        if (snapshot.hasData && snapshot.data != null) {
          // Check onboarding status
          return FutureBuilder<bool>(
            future: _authService.hasCompletedOnboarding(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              if (onboardingSnapshot.hasError) {
                return _buildErrorScreen(onboardingSnapshot.error.toString());
              }

              // Belum onboarding
              if (onboardingSnapshot.data == false) {
                return const OnboardingChatbotScreen();
              }

              // Check welcome screen
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

        // User not logged in
        return LoginScreen();
      },
    );
  }

  /// Loading screen widget
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

  /// Error screen widget
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
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 60,
                ),
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
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF6A00),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
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