import 'dart:io';
import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../widget/Animated_Gradient_Background.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;

  const ProfileScreen({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _obscurePassword = true;
  String? _originalUsername;
  String? _originalEmail;
  String? _profileImageUrl;
  bool _isGoogleUser = false;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      try {
        // Check if user signed in with Google
        _isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');

        // Check if user has password (for email/password auth)
        _hasPassword = user.providerData.any((info) => info.providerId == 'password');

        // Load username and profile image from Firestore
        final userDoc = await widget.authService.firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          final username = data?['username'] ?? '';
          final profileImg = data?['profileImageUrl'];

          setState(() {
            _usernameController.text = username;
            _originalUsername = username;

            // Priority: 1) Firestore profileImageUrl, 2) Google photoURL, 3) null (will show default)
            if (profileImg != null && profileImg.isNotEmpty) {
              _profileImageUrl = profileImg;
            } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
              _profileImageUrl = user.photoURL;
            } else {
              _profileImageUrl = null; // Will show default Kimmy avatar
            }
          });
        } else {
          setState(() {
            _usernameController.text = user.displayName ?? '';
            _originalUsername = user.displayName ?? '';

            // Use Google photoURL if available, otherwise null
            _profileImageUrl = (user.photoURL != null && user.photoURL!.isNotEmpty)
                ? user.photoURL
                : null;
          });
        }

        setState(() {
          _emailController.text = user.email ?? '';
          _originalEmail = user.email ?? '';
        });
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final user = widget.authService.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await widget.authService.firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth profile
      await user.updatePhotoURL(downloadUrl);

      setState(() {
        _profileImageUrl = downloadUrl;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = widget.authService.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final newUsername = _usernameController.text.trim();
      final newEmail = _emailController.text.trim();
      final newPassword = _passwordController.text;

      // Validate username format
      final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
      if (!usernameRegex.hasMatch(newUsername)) {
        throw Exception('Username must be 3-20 characters and contain only letters, numbers, and underscores');
      }

      // Update username if changed
      if (newUsername != _originalUsername) {
        final usernameQuery = await widget.authService.firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .limit(1)
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          if (usernameQuery.docs.first.id != user.uid) {
            throw Exception('Username is already taken');
          }
        }

        await user.updateDisplayName(newUsername);

        await widget.authService.firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'username': newUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update username in all chats
        await _updateUsernameInChats(user.uid, newUsername);

        setState(() {
          _originalUsername = newUsername;
        });
      }

      // Update email if changed
      if (newEmail != _originalEmail) {
        try {
          await user.verifyBeforeUpdateEmail(newEmail);

          await widget.authService.firestore
              .collection('users')
              .doc(user.uid)
              .update({
            'email': newEmail,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _originalEmail = newEmail;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification email sent! Please verify to complete email update.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (e.toString().contains('requires-recent-login')) {
            throw FirebaseAuthException(
              code: 'requires-recent-login',
              message: 'Please sign out and sign in again to update email',
            );
          }
          rethrow;
        }
      }

      // Update or set password
      if (newPassword.isNotEmpty) {
        if (newPassword.length < 8) {
          throw Exception('Password must be at least 8 characters');
        }

        final hasLetter = newPassword.contains(RegExp(r'[a-zA-Z]'));
        final hasNumber = newPassword.contains(RegExp(r'[0-9]'));
        final hasSymbol = newPassword.contains(RegExp(r'[!@#\$%&*\-_+=]'));

        if (!hasLetter || !hasNumber || !hasSymbol) {
          throw Exception('Password must contain letters, numbers, and symbols');
        }

        await user.updatePassword(newPassword);
        _passwordController.clear();

        setState(() {
          _hasPassword = true;
        });
      }

      await user.reload();

      setState(() => _isEditMode = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await _loadUserData();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_handleAuthError(e)),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _updateUsernameInChats(String userId, String newUsername) async {
    try {
      final chatsQuery = await widget.authService.firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.update({
          'participantDetails.$userId.username': newUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating username in chats: $e');
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'Please sign out and sign in again to make this change';
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Email is already in use';
      case 'invalid-email':
        return 'Invalid email address';
      default:
        return e.message ?? 'An error occurred';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Profile',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            if (!_isEditMode)
              IconButton(
                icon: Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  setState(() => _isEditMode = true);
                },
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _isEditMode ? _pickAndUploadImage : null,
                    child: Container(
                      width: 130,
                      height: 130,
                      child: Stack(
                        children: [
                          // Main circle with image
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFDEF3FF),
                              image: _profileImageUrl != null
                                  ? DecorationImage(
                                image: NetworkImage(_profileImageUrl!),
                                fit: BoxFit.cover,
                              )
                                  : DecorationImage(
                                image: AssetImage('assets/image/AvatarKimmy.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Edit button (bottom right)
                          if (_isEditMode)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 40),

                  // Username Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 37),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 9),
                        Container(
                          height: 48,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(width: 2, color: Colors.black),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: TextFormField(
                            controller: _usernameController,
                            enabled: _isEditMode,
                            decoration: InputDecoration(
                              hintText: 'Type here',
                              hintStyle: TextStyle(
                                color: const Color(0xFF1D1D1D).withOpacity(0.6),
                                fontSize: 13,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter username';
                              }
                              if (value.trim().length < 3 || value.trim().length > 20) {
                                return 'Username must be 3-20 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '3-20 characters, letters, numbers, and underscores only',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Email Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 37),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 9),
                        Container(
                          height: 48,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(width: 2, color: Colors.black),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            enabled: _isEditMode,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Type here',
                              hintStyle: TextStyle(
                                color: const Color(0xFF1D1D1D).withOpacity(0.6),
                                fontSize: 13,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter email';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Email changes require verification',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Password Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 37),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 9),
                        Container(
                          height: 48,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(width: 2, color: Colors.black),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isEditMode
                              ? TextFormField(
                            controller: _passwordController,
                            enabled: _isEditMode,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: _hasPassword
                                  ? 'Leave empty to keep current password'
                                  : 'Set a password for your account',
                              hintStyle: TextStyle(
                                color: const Color(0xFF1D1D1D).withOpacity(0.6),
                                fontSize: 11,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                final hasLetter = value.contains(RegExp(r'[a-zA-Z]'));
                                final hasNumber = value.contains(RegExp(r'[0-9]'));
                                final hasSymbol = value.contains(RegExp(r'[!@#\$%&*\-_+=]'));

                                if (!hasLetter || !hasNumber || !hasSymbol) {
                                  return 'Must contain letters, numbers, and symbols';
                                }
                              }
                              return null;
                            },
                          )
                              : TextFormField(
                            enabled: false,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: _hasPassword ? '••••••••' : 'No password set',
                              hintStyle: TextStyle(
                                color: _hasPassword
                                    ? Colors.black
                                    : Colors.orange,
                                fontSize: 13,
                                fontFamily: 'SF Pro',
                                fontWeight: _hasPassword
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _hasPassword
                              ? 'Leave empty if you don\'t want to change it.\nIf changing: 8+ chars with letters, numbers, and symbols'
                              : _isGoogleUser
                              ? 'You signed in with Google. Add a password for additional security.'
                              : 'Password is required',
                          style: TextStyle(
                            color: _hasPassword || !_isGoogleUser
                                ? Colors.grey[600]
                                : Colors.orange,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // Update/Cancel Buttons
                  if (_isEditMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 37),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFF6A00),
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2.5,
                                ),
                              )
                                  : Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                setState(() {
                                  _isEditMode = false;
                                  _passwordController.clear();
                                });
                                _loadUserData();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.black, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}