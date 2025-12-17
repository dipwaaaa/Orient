import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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

  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[!@#$%&*\-_+=]'));
    return hasLetter && hasNumber && hasSymbol;
  }

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

  bool _isEmail(String input) {
    return input.contains('@') && input.contains('.');
  }

  Future<void> _createUserDocument(
      User user, {
        bool isNewUser = false,
        String? customUsername,
      }) async {
    try {
      final ref = firestore.collection('users').doc(user.uid);
      final snap = await ref.get();

      if (!snap.exists) {
        String finalUsername = customUsername ?? user.displayName ?? _generateRandomUsername();
        finalUsername = finalUsername.replaceAll(' ', '');

        await ref.set({
          'uid': user.uid,
          'email': user.email,
          'username': finalUsername,
          'isNewUser': isNewUser,
          'hasCompletedOnboarding': false,
          'createdAt': FieldValue.serverTimestamp(),
          'profileImageUrl': user.photoURL,
          'notificationsEnabled': true,
          'friends': [],
        });
        debugPrint('User document created successfully');
      }
    } catch (e) {
      debugPrint('Error creating user document: $e');
    }
  }

  Future<void> _createUserDocumentSafe(User user, String username) async {
    const maxRetries = 3;
    final cleanUsername = username.replaceAll(' ', '');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Attempting to create user document (attempt $attempt)...');

        if (_auth.currentUser == null) {
          throw Exception('User not authenticated');
        }

        try {
          await user.getIdToken(true).timeout(Duration(seconds: 10));
        } catch (e) {
          debugPrint('⚠️ Token refresh timeout: $e');
        }

        final ref = firestore.collection('users').doc(user.uid);

        await firestore.runTransaction((transaction) async {
          transaction.set(ref, {
            'uid': user.uid,
            'email': user.email,
            'username': cleanUsername,
            'isNewUser': true,
            'hasCompletedOnboarding': false,
            'createdAt': FieldValue.serverTimestamp(),
            'profileImageUrl': user.photoURL,
            'notificationsEnabled': true,
            'friends': [],
          });
        }).timeout(Duration(seconds: 15));

        debugPrint('User document created successfully with transaction');
        return;
      } catch (e) {
        debugPrint('⚠ Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          debugPrint('Max retries reached');
          return;
        }

        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
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

  Future<bool> isUsernameAvailable(String username) async {
    if (username.trim().isEmpty) return false;
    try {
      final cleanUsername = username.trim().replaceAll(' ', '');
      return !(await _isUsernameTaken(cleanUsername));
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> generateUsernameSuggestions(String baseUsername) async {
    List<String> suggestions = [];
    final cleanBase = baseUsername.trim().replaceAll(' ', '').toLowerCase();

    for (int i = 1; suggestions.length < 5; i++) {
      String suggestion = '$cleanBase$i';
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

  Future<bool> retryProfileSetup() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final doc = await firestore.collection('users').doc(user.uid).get();
      if (doc.exists) return true;

      final displayName = user.displayName ?? _generateRandomUsername();
      final cleanUsername = displayName.replaceAll(' ', '');

      await _createUserDocumentSafe(user, cleanUsername);
      return true;
    } catch (e) {
      debugPrint('Retry profile setup failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> signInWithEmailOrUsername(
      String emailOrUsername,
      String password,
      ) async {
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
        email: emailToUse,
        password: password,
      );

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
      String email,
      String password,
      ) async {
    return signInWithEmailOrUsername(email, password);
  }

  Future<Map<String, dynamic>> registerWithEmailAndPassword(
      String email,
      String password,
      String username,
      ) async {
    try {
      if (username.trim().isEmpty) {
        return {'success': false, 'error': 'Username cannot be empty'};
      }

      final cleanUsername = username.trim().replaceAll(' ', '');

      if (cleanUsername.isEmpty) {
        return {'success': false, 'error': 'Username cannot be empty'};
      }

      final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
      if (!usernameRegex.hasMatch(cleanUsername)) {
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

      debugPrint('📝 Starting registration process...');

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user == null) {
        return {'success': false, 'error': 'Registration failed'};
      }

      debugPrint('User created in Auth: ${result.user!.uid}');

      try {
        await result.user!.updateDisplayName(cleanUsername);
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
        bool usernameTaken = await _isUsernameTaken(cleanUsername);
        if (usernameTaken) {
          final altUsername = '${cleanUsername}_${Random().nextInt(9999)}';
          debugPrint('Username was taken, using: $altUsername');
          await _createUserDocumentSafe(result.user!, altUsername);
        } else {
          await _createUserDocumentSafe(result.user!, cleanUsername);
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

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      debugPrint('🔵 Starting Google Sign-In...');

      await GoogleSignIn.instance.initialize(
        serverClientId: '249442742487-mnc33cfun8jfdivk4p4rj102nmjuc8l0.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();

      if (account == null) {
        debugPrint('User cancelled sign in');
        return {'success': false, 'error': 'User cancelled sign in'};
      }

      debugPrint('Google account obtained: ${account.email}');

      final googleAuth = account.authentication;

      debugPrint('ID Token available: ${googleAuth.idToken != null}');

      if (googleAuth.idToken == null) {
        debugPrint('Failed to get ID Token');
        return {'success': false, 'error': 'Failed to get ID Token'};
      }

      String? accessToken;
      try {
        final authClient = account.authorizationClient;
        final clientAuth = await authClient.authorizationForScopes(['email', 'profile']);
        accessToken = clientAuth?.accessToken;
        debugPrint('Access Token available: ${accessToken != null}');
      } catch (e) {
        debugPrint('Could not get access token: $e');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: accessToken,
      );

      debugPrint('Signing in to Firebase...');

      final result = await _auth.signInWithCredential(credential);

      debugPrint('Firebase sign-in successful: ${result.user?.email}');

      final isNew = result.additionalUserInfo?.isNewUser ?? false;

      String username = result.user?.displayName ?? _generateRandomUsername();
      username = username.replaceAll(' ', '');

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
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'success': false, 'error': 'Google sign in failed: $e'};
    }
  }


  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return {'success': false, 'error': 'No user logged in'};
      }

      debugPrint('🗑 Starting account deletion process for user: ${user.uid}');

      final hasPassword = user.providerData.any((info) => info.providerId == 'password');
      final hasGoogle = user.providerData.any((info) => info.providerId == 'google.com');

      if (!hasPassword && !hasGoogle) {
        return {'success': false, 'error': 'No authentication method found'};
      }


      debugPrint('️ Deleting user data...');
      await _deleteUserData(user.uid);


      debugPrint(' Attempting to delete Firebase Auth account...');
      try {
        await user.delete();
        debugPrint(' Firebase user account deleted successfully');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {

          debugPrint(' Recent login required');
          return {
            'success': false,
            'error': 'For security, please sign out and sign in again, then try deleting your account.',
          };
        } else {
          throw e;
        }
      }

      await signOut();

      return {
        'success': true,
        'message': 'Account deleted successfully',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': _handleDeleteAccountError(e),
      };
    } catch (e) {
      debugPrint('❌ Unexpected error during account deletion: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  Future<void> _deleteUserData(String userId) async {
    try {
      debugPrint('Deleting user data for: $userId');

      final userDocRef = firestore.collection('users').doc(userId);

      debugPrint('Removing user from collaborators in events...');
      await _removeUserFromCollaborators(userId);
      debugPrint('User removed from all collaborators lists');

      debugPrint('Deleting notifications...');
      final notificationsSnapshot = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${notificationsSnapshot.docs.length} notifications');

      debugPrint('Deleting chats...');
      final chatsSnapshot = await firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();
      for (var chatDoc in chatsSnapshot.docs) {
        await chatDoc.reference.delete();
        debugPrint('Deleted chat: ${chatDoc.id}');
      }

      debugPrint('Deleting messages...');
      final messagesSnapshot = await firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .get();
      for (var messageDoc in messagesSnapshot.docs) {
        await messageDoc.reference.delete();
      }
      debugPrint('Deleted ${messagesSnapshot.docs.length} messages');

      debugPrint('Deleting events...');
      final eventsSnapshot = await firestore
          .collection('events')
          .where('ownerId', isEqualTo: userId)
          .get();
      for (var eventDoc in eventsSnapshot.docs) {
        await _deleteEventSubcollections(eventDoc.reference);
        await eventDoc.reference.delete();
        debugPrint('Deleted event: ${eventDoc.id}');
      }

      debugPrint('Deleting profile image...');
      await _deleteProfileImage(userId);

      debugPrint('Deleting user document...');
      await userDocRef.delete();
      debugPrint('Deleted user document: $userId');

      debugPrint('All user data deleted successfully');
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      rethrow;
    }
  }

  Future<void> _removeUserFromCollaborators(String userId) async {
    try {
      final eventsSnapshot = await firestore
          .collection('events')
          .where('collaborators', arrayContains: userId)
          .get();

      debugPrint('Found ${eventsSnapshot.docs.length} events where user is collaborator');

      for (var eventDoc in eventsSnapshot.docs) {
        await eventDoc.reference.update({
          'collaborators': FieldValue.arrayRemove([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Removed from collaborators in event: ${eventDoc.id}');
      }

      if (eventsSnapshot.docs.isEmpty) {
        debugPrint('User was not a collaborator in any events');
      }
    } catch (e) {
      debugPrint('Error removing user from collaborators: $e');
    }
  }

  Future<void> _deleteEventSubcollections(DocumentReference eventRef) async {
    try {
      final subcollections = ['vendors', 'tasks', 'budgets', 'guests'];

      for (var subcollection in subcollections) {
        final snapshot = await eventRef.collection(subcollection).get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
        debugPrint('Deleted $subcollection subcollection');
      }
    } catch (e) {
      debugPrint('Error deleting event subcollections: $e');
    }
  }

  Future<void> _deleteProfileImage(String userId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(userId);

      final listResult = await storageRef.listAll();

      for (var file in listResult.items) {
        await file.delete();
        debugPrint('Deleted profile image: ${file.name}');
      }
    } catch (e) {
      debugPrint('Note: Could not delete profile images: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }
    await _auth.signOut();
    debugPrint('User signed out successfully');
  }

  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      if (email.trim().isEmpty) {
        return {'success': false, 'error': 'Please enter your email address'};
      }

      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(email.trim())) {
        return {'success': false, 'error': 'Please enter a valid email address'};
      }

      debugPrint('Sending password reset email to: $email');

      await _auth.sendPasswordResetEmail(email: email.trim());

      debugPrint('Password reset email sent successfully');

      return {
        'success': true,
        'message': 'Password reset email sent! Check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': _handlePasswordResetError(e),
      };
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return {
        'success': false,
        'error': 'Failed to send reset email. Please try again.',
      };
    }
  }

  String _handlePasswordResetError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many reset requests. Try again later.';
      case 'operation-not-allowed':
        return 'Password reset is not enabled for this account.';
      default:
        return e.message ?? 'Failed to send reset email.';
    }
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

  String _handleDeleteAccountError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Please sign out and sign in again before deleting your account.';
      case 'user-mismatch':
        return 'The credentials do not match the current user.';
      case 'invalid-credential':
        return 'Invalid password. Please check and try again.';
      case 'operation-not-allowed':
        return 'Account deletion is not enabled for this account type.';
      case 'user-token-expired':
        return 'Your session has expired. Please sign in again.';
      default:
        return e.message ?? 'Failed to delete account. Please try again.';
    }
  }
}