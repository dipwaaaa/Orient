import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Utility
  String _generateRandomUsername() {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    final random = Random();

    String username = 'user_';
    for (int i = 0; i < 8; i++) {
      if (i % 2 == 0) {
        username += letters[random.nextInt(letters.length)];
      } else {
        username += numbers[random.nextInt(numbers.length)];
      }
    }
    return username;
  }

  // Validasi password: minimal 8 karakter dengan huruf, angka, dan simbol
  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[!@#\$%&*\-_+=]'));
    return hasLetter && hasNumber && hasSymbol;
  }

  // Cek apakah username sudah dipakai user lain dengan error handling yang lebih baik
  Future<bool> _isUsernameTaken(String username) async {
    try {
      final querySnapshot = await firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  // Cari email berdasarkan username
  Future<String?> _getEmailFromUsername(String username) async {
    try {
      final querySnapshot = await firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['email'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting email from username: $e');
      return null;
    }
  }

  // Validasi apakah input adalah email atau username
  bool _isEmail(String input) {
    return input.contains('@') && input.contains('.');
  }

  Future<void> _createUserDocument(User user, {bool isNewUser = false, String? customUsername}) async {
    try {
      final ref = firestore.collection('users').doc(user.uid);
      final snap = await ref.get();

      if (!snap.exists) {
        String finalUsername = customUsername ?? user.displayName ?? _generateRandomUsername();

        await ref.set({
          'uid': user.uid,
          'email': user.email,
          'username': finalUsername,
          'isNewUser': isNewUser,
          'hasCompletedOnboarding': false,
          'createdAt': FieldValue.serverTimestamp(),
          'profileImageUrl': user.photoURL,
          'friends': [],
        });
        debugPrint('User document created successfully');
      }
    } catch (e) {
      debugPrint('Error creating user document: $e');
    }
  }

  Future<bool> hasCompletedOnboarding() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final snap = await firestore.collection('users').doc(user.uid).get();
      if (!snap.exists) return false;

      final data = snap.data();
      return data?['hasCompletedOnboarding'] ?? false;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false;
    }
  }

  // ===== Email/Username/Password Login =====
  Future<Map<String, dynamic>> signInWithEmailOrUsername(
      String emailOrUsername, String password) async {
    try {
      String emailToUse;

      if (_isEmail(emailOrUsername)) {
        emailToUse = emailOrUsername;
      } else {
        final email = await _getEmailFromUsername(emailOrUsername);
        if (email == null) {
          return {'success': false, 'error': 'Username not found'};
        }
        emailToUse = email;
      }

      final result = await _auth.signInWithEmailAndPassword(
          email: emailToUse, password: password);

      if (result.user != null) {
        await _createUserDocument(result.user!, isNewUser: false);

        final shouldShowWelcome = await shouldShowWelcomeScreen();

        return {
          'success': true,
          'userCredential': result,
          'isNewUser': shouldShowWelcome
        };
      }
      return {'success': false, 'error': 'Authentication failed'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _handleAuthError(e)};
    } catch (e) {
      return {'success': false, 'error': 'Login failed: $e'};
    }
  }

  Future<Map<String, dynamic>> signInWithEmailAndPassword(
      String email, String password) async {
    return signInWithEmailOrUsername(email, password);
  }

  // ===== Email/Password Register =====
  Future<Map<String, dynamic>> registerWithEmailAndPassword(
      String email, String password, String username) async {
    try {
      if (username.trim().isEmpty) {
        return {'success': false, 'error': 'Username cannot be empty'};
      }

      final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
      if (!usernameRegex.hasMatch(username.trim())) {
        return {
          'success': false,
          'error': 'Username must be 3-20 characters and contain only letters, numbers, and underscores'
        };
      }

      if (!_isValidPassword(password)) {
        return {
          'success': false,
          'error': 'Password must be at least 8 characters and contain letters, numbers, and symbols'
        };
      }

      debugPrint('Starting registration process...');

      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      if (result.user == null) {
        return {'success': false, 'error': 'Registration failed'};
      }

      debugPrint('User created in Auth: ${result.user!.uid}');

      try {
        await result.user!.updateDisplayName(username.trim());
        debugPrint('Display name updated');
      } catch (e) {
        debugPrint('Failed to update display name: $e');
      }

      await Future.delayed(Duration(seconds: 2));
      try {
        await result.user!.reload();
        final token = await result.user!.getIdToken(true);
        debugPrint('Fresh token obtained: ${token != null}');
      } catch (e) {
        debugPrint('Token refresh failed: $e');
      }

      try {
        bool usernameTaken = await _isUsernameTaken(username.trim());
        if (usernameTaken) {
          final altUsername = '${username.trim()}_${Random().nextInt(9999)}';
          debugPrint('Username was taken, using: $altUsername');
          await _createUserDocumentSafe(result.user!, altUsername);
        } else {
          await _createUserDocumentSafe(result.user!, username.trim());
        }
      } catch (e) {
        debugPrint('Username check/creation failed: $e');
        await _createUserDocumentSafe(result.user!, _generateRandomUsername());
      }

      return {'success': true, 'userCredential': result, 'isNewUser': true};

    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      return {'success': false, 'error': _handleAuthError(e)};
    } catch (e) {
      debugPrint('Unexpected registration error: $e');
      return {'success': false, 'error': 'Registration failed: $e'};
    }
  }

  Future<void> _createUserDocumentSafe(User user, String username) async {
    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Attempting to create user document (attempt $attempt)...');

        if (_auth.currentUser == null) {
          throw Exception('User not authenticated');
        }

        try {
          await user.getIdToken(true).timeout(Duration(seconds: 10));
        } catch (e) {
          debugPrint('Token refresh timeout: $e');
        }

        final ref = firestore.collection('users').doc(user.uid);

        await firestore.runTransaction((transaction) async {
          transaction.set(ref, {
            'uid': user.uid,
            'email': user.email,
            'username': username,
            'isNewUser': true,
            'hasCompletedOnboarding': false,
            'createdAt': FieldValue.serverTimestamp(),
            'profileImageUrl': user.photoURL,
            'friends': [],
          });
        }).timeout(Duration(seconds: 15));

        debugPrint('User document created successfully with transaction');
        return;

      } catch (e) {
        debugPrint('Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          debugPrint('Max retries reached, user document may not be created');
          return;
        }

        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }
  }

  Future<bool> retryProfileSetup() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      if (doc.exists) return true;

      await _createUserDocumentSafe(user, user.displayName ?? _generateRandomUsername());
      return true;
    } catch (e) {
      debugPrint('Retry profile setup failed: $e');
      return false;
    }
  }

  // ===== Google Sign-In =====
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      debugPrint("Starting Google Sign-In...");

      await GoogleSignIn.instance.initialize(
        serverClientId: '249442742487-mnc33cfun8jfdivk4p4rj102nmjuc8l0.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();

      if (account == null) {
        debugPrint("User cancelled sign in");
        return {'success': false, 'error': 'User cancelled sign in'};
      }

      debugPrint("Google account obtained: ${account.email}");

      final googleAuth = account.authentication;

      debugPrint("ID Token available: ${googleAuth.idToken != null}");

      if (googleAuth.idToken == null) {
        debugPrint("Failed to get ID Token");
        return {'success': false, 'error': 'Failed to get ID Token'};
      }

      String? accessToken;
      try {
        final authClient = account.authorizationClient;
        final clientAuth = await authClient.authorizationForScopes(['email', 'profile']);
        accessToken = clientAuth?.accessToken;
        debugPrint("Access Token available: ${accessToken != null}");
      } catch (e) {
        debugPrint("Could not get access token: $e");
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: accessToken,
      );

      debugPrint("Signing in to Firebase...");

      final result = await _auth.signInWithCredential(credential);

      debugPrint("Firebase sign-in successful: ${result.user?.email}");

      final isNew = result.additionalUserInfo?.isNewUser ?? false;

      String username = result.user?.displayName ?? _generateRandomUsername();

      try {
        bool usernameTaken = await _isUsernameTaken(username);
        if (usernameTaken) {
          username = '${username}_${Random().nextInt(9999)}';
        }
      } catch (e) {
        username = '${username}_${Random().nextInt(9999)}';
      }

      await _createUserDocument(result.user!, isNewUser: isNew, customUsername: username);

      return {'success': true, 'userCredential': result, 'isNewUser': isNew};
    } catch (e, stackTrace) {
      debugPrint("Error: $e");
      debugPrint("Stack trace: $stackTrace");
      return {'success': false, 'error': 'Google sign in failed: $e'};
    }
  }

  // ===== Helper Methods untuk Username =====
  Future<bool> isUsernameAvailable(String username) async {
    if (username.trim().isEmpty) return false;
    try {
      return !(await _isUsernameTaken(username.trim()));
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> generateUsernameSuggestions(String baseUsername) async {
    List<String> suggestions = [];
    final cleanBase = baseUsername.trim().toLowerCase();

    for (int i = 1; suggestions.length < 5; i++) {
      String suggestion = '${cleanBase}${i}';
      if (await isUsernameAvailable(suggestion)) {
        suggestions.add(suggestion);
      }

      if (suggestions.length < 5) {
        String suggestion2 = '${cleanBase}_${Random().nextInt(999)}';
        if (await isUsernameAvailable(suggestion2)) {
          suggestions.add(suggestion2);
        }
      }
    }

    return suggestions;
  }

  // ===== Misc =====
  Future<bool> shouldShowWelcomeScreen() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final snap = await firestore.collection('users').doc(user.uid).get();
      if (!snap.exists) {
        return true;
      }

      final data = snap.data();
      final isNew = data?['isNewUser'] ?? false;

      if (isNew) {
        try {
          await firestore
              .collection('users')
              .doc(user.uid)
              .update({'isNewUser': false});
        } catch (e) {
          debugPrint('Failed to update isNewUser flag: $e');
        }
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking welcome screen status: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint("Error signing out from Google: $e");
    }
    await _auth.signOut();
    debugPrint("User signed out successfully");
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'Account already exists for that email.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'invalid-credential':
        return 'The credential is invalid or expired.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}