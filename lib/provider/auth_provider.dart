import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../screen/login_signup_screen.dart';

class AuthStateProvider extends ChangeNotifier {
  final AuthService _authService;
  bool _isLoggingOut = false;

  AuthStateProvider(this._authService);

  bool get isLoggingOut => _isLoggingOut;
  AuthService get authService => _authService;

  Future<void> logout(BuildContext context) async {
    try {
      _isLoggingOut = true;
      notifyListeners();

      // Sign out dari Firebase
      await _authService.signOut();

      // Tunggu sebentar untuk memastikan sign out selesai
      await Future.delayed(Duration(milliseconds: 300));

      if (!context.mounted) return;

      // Tutup dialog/bottom sheet jika masih terbuka
      while (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Navigate ke login screen
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
        );
      }

      _isLoggingOut = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      _isLoggingOut = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}