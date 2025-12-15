import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/service/auth_service.dart';


class GoogleUserPasswordFix {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check apakah user punya password provider
  static bool hasPasswordProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'password');
  }

  /// Check apakah user punya Google provider
  static bool hasGoogleProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  /// Link email/password provider untuk Google users
  static Future<bool> linkEmailPasswordProvider({
    required User user,
    required String password,
  }) async {
    try {
      // Jika sudah ada password provider, tidak perlu link lagi
      if (hasPasswordProvider(user)) {
        debugPrint(' User sudah punya password provider');
        return true;
      }

      // Hanya untuk Google users
      if (!hasGoogleProvider(user)) {
        debugPrint('⚠ User bukan Google user');
        return false;
      }

      debugPrint('🔗 Linking email/password provider untuk Google user...');

      // Create credential untuk email/password yang baru
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // Link credential ke user account
      await user.linkWithCredential(credential);

      debugPrint(' Email/password provider linked successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(' Error linking provider: ${e.code} - ${e.message}');

      if (e.code == 'provider-already-linked') {
        debugPrint('ℹ Provider already linked');
        return true;
      }

      if (e.code == 'credential-already-in-use') {
        debugPrint(' Credential sudah digunakan akun lain');
        return false;
      }

      return false;
    } catch (e) {
      debugPrint(' Unexpected error: $e');
      return false;
    }
  }

  /// Update password dengan proper provider linking
  static Future<Map<String, dynamic>> updatePasswordForGoogleUser({
    required User user,
    required String newPassword,
  }) async {
    try {
      debugPrint(' Updating password for Google user...');

      // Step 1: Check kalau password valid
      if (newPassword.length < 8) {
        return {
          'success': false,
          'error': 'Password must be at least 8 characters'
        };
      }

      final hasLetter = newPassword.contains(RegExp(r'[a-zA-Z]'));
      final hasNumber = newPassword.contains(RegExp(r'[0-9]'));
      final hasSymbol = newPassword.contains(RegExp(r'[!@#\$%&*\-_+=]'));

      if (!hasLetter || !hasNumber || !hasSymbol) {
        return {
          'success': false,
          'error': 'Password must contain letters, numbers, and symbols'
        };
      }

      // Step 2: Jika belum ada password provider, link dulu
      if (!hasPasswordProvider(user)) {
        debugPrint(' Linking email/password provider...');

        final linked = await linkEmailPasswordProvider(
          user: user,
          password: newPassword,
        );

        if (!linked) {
          return {
            'success': false,
            'error': 'Failed to link password provider'
          };
        }

        debugPrint(' Password provider linked');
        await user.reload();

        return {
          'success': true,
          'message': 'Password set successfully! You can now login dengan email/password.'
        };
      } else {
        // Step 3: Kalau sudah ada password provider, langsung update
        debugPrint(' Updating existing password...');
        await user.updatePassword(newPassword);

        debugPrint(' Password updated successfully');
        return {
          'success': true,
          'message': 'Password updated successfully!'
        };
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(' Firebase error: ${e.code} - ${e.message}');

      if (e.code == 'requires-recent-login') {
        return {
          'success': false,
          'error': 'Please sign out and sign in again to change password'
        };
      }

      if (e.code == 'weak-password') {
        return {
          'success': false,
          'error': 'Password is too weak. Use letters, numbers, and symbols.'
        };
      }

      return {
        'success': false,
        'error': 'Error: ${e.message}'
      };
    } catch (e) {
      debugPrint(' Unexpected error: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred'
      };
    }
  }
}

