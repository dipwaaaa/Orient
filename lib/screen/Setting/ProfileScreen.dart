import 'dart:io';
import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/notification_service.dart';
import 'package:untitled/model/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../widget/delete_acc_dialog.dart';
import '../login_signup_screen.dart';
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _obscurePassword = true;
  bool _notificationsEnabled = true;
  String? _originalName;
  String? _originalEmail;
  String? _profileImageUrl;
  bool _isGoogleUser = false;
  bool _hasPassword = false;

  // Notification Service
  late NotificationService _notificationService;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _loadUserData();
    _loadUnreadNotificationsCount();
  }

  Future<void> _loadUserData() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      try {
        _isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');
        _hasPassword = user.providerData.any((info) => info.providerId == 'password');

        final userDoc = await widget.authService.firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          final name = data?['username'] ?? '';
          final profileImg = data?['profileImageUrl'];
          final notifications = data?['notificationsEnabled'] ?? true;

          setState(() {
            _nameController.text = name;
            _originalName = name;
            _notificationsEnabled = notifications;

            if (profileImg != null && profileImg.isNotEmpty) {
              _profileImageUrl = profileImg;
            } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
              _profileImageUrl = user.photoURL;
            } else {
              _profileImageUrl = null;
            }
          });
        } else {
          setState(() {
            _nameController.text = user.displayName ?? '';
            _originalName = user.displayName ?? '';
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

  Future<void> _loadUnreadNotificationsCount() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      try {
        final count = await _notificationService.getUnreadCount(user.uid);
        setState(() {
          _unreadNotificationsCount = count;
        });
        debugPrint('Unread notifications: $count');
      } catch (e) {
        debugPrint('Error loading unread notifications count: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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

      debugPrint('\n📤 Uploading profile image:');
      debugPrint('   File: ${image.name}');
      debugPrint('   User: ${user.uid}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(user.uid)
          .child(fileName);

      debugPrint('   Upload path: profile_images/${user.uid}/$fileName');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      await storageRef.putFile(File(image.path), metadata);
      final downloadUrl = await storageRef.getDownloadURL();

      debugPrint('✅ Profile image uploaded successfully');
      debugPrint('   Download URL: ${downloadUrl.substring(0, 50)}...\n');

      await widget.authService.firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
      debugPrint('❌ Error uploading profile image: $e\n');
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

      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      final newPassword = _passwordController.text;

      final nameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
      if (!nameRegex.hasMatch(newName)) {
        throw Exception('Name must be 3-20 characters and contain only letters, numbers, and underscores');
      }

      if (newName != _originalName) {
        final nameQuery = await widget.authService.firestore
            .collection('users')
            .where('username', isEqualTo: newName)
            .limit(1)
            .get();

        if (nameQuery.docs.isNotEmpty) {
          if (nameQuery.docs.first.id != user.uid) {
            throw Exception('Name is already taken');
          }
        }

        await user.updateDisplayName(newName);

        await widget.authService.firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'username': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _updateNameInChats(user.uid, newName);

        setState(() {
          _originalName = newName;
        });
      }

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

      await widget.authService.firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'notificationsEnabled': _notificationsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

  /// Show delete account confirmation dialog
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return DeleteAccountDialog(
          authService: widget.authService,
          hasPassword: _hasPassword,
          userEmail: _emailController.text,
          onDeleteSuccess: _handleDeleteSuccess,
        );
      },
    );
  }

  /// Handle successful account deletion
  Future<void> _handleDeleteSuccess() async {
    if (!mounted) return;

    // Clear all navigation stack and go to login
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    }
  }

  /// Build delete account button
  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _showDeleteAccountDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          'Delete Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _updateNameInChats(String userId, String newName) async {
    try {
      final chatsQuery = await widget.authService.firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.update({
          'participantDetails.$userId.username': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating name in chats: $e');
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
            _isEditMode ? 'Cancel' : 'Back',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: false,
          actions: [
            if (!_isEditMode)
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications, color: Colors.black, size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationScreenPage(
                            userId: widget.authService.currentUser?.uid ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                  if (_unreadNotificationsCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _unreadNotificationsCount > 99
                              ? '99+'
                              : '$_unreadNotificationsCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            SizedBox(width: 8),
            if (!_isEditMode)
              IconButton(
                icon: Icon(Icons.edit, color: Colors.black, size: 20),
                onPressed: () {
                  setState(() => _isEditMode = true);
                },
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 65),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Avatar
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      child: GestureDetector(
                        onTap: _isEditMode ? _pickAndUploadImage : null,
                        child: Container(
                          width: 130,
                          height: 130,
                          child: Stack(
                            children: [
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
                              if (_isEditMode)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Profile Form Fields
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 37),
                      child: Column(
                        children: [
                          // Name Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Name',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 9),
                              Container(
                                height: 48,
                                decoration: ShapeDecoration(
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(width: 1.5, color: Colors.black),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: _nameController,
                                  enabled: _isEditMode,
                                  decoration: InputDecoration(
                                    hintText: 'Type here',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF1D1D1D).withValues(alpha: .5),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: InputBorder.none,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter name';
                                    }
                                    if (value.trim().length < 3 || value.trim().length > 20) {
                                      return 'Name must be 3-20 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Email Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 9),
                              Container(
                                height: 48,
                                decoration: ShapeDecoration(
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(width: 1.5, color: Colors.black),
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
                                      color: const Color(0xFF1D1D1D).withValues(alpha: 0.5),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            ],
                          ),

                          SizedBox(height: 24),

                          // Password Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 9),
                              Container(
                                height: 48,
                                decoration: ShapeDecoration(
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(width: 1.5, color: Colors.black),
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
                                        ? 'Leave empty to keep current'
                                        : 'Set a password',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF1D1D1D).withValues(alpha: .5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: InputBorder.none,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey,
                                        size: 18,
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
                                      fontSize: 14,
                                      fontWeight: _hasPassword
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 32),

                          // Notification Toggle (visible when not editing)
                          if (!_isEditMode)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Notification',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Switch(
                                  value: _notificationsEnabled,
                                  onChanged: (value) {
                                    setState(() {
                                      _notificationsEnabled = value;
                                    });
                                    _updateNotificationPreference();
                                  },
                                  activeColor: Colors.white,
                                  activeTrackColor: Colors.black,
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: Colors.black87,
                                ),
                              ],
                            ),

                          SizedBox(height: 24),

                          // Delete Account Button (visible when not editing)
                          if (!_isEditMode)
                            _buildDeleteAccountButton(),

                          // Edit Mode Buttons
                          if (_isEditMode)
                            Column(
                              children: [
                                SizedBox(height: 24),
                                // Save Changes Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _updateProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFFFC107),
                                      disabledBackgroundColor: Colors.grey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                        : Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                // Cancel Button
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
                                      side: BorderSide(color: Colors.black, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
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

                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateNotificationPreference() async {
    try {
      final user = widget.authService.currentUser;
      if (user != null) {
        await widget.authService.firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'notificationsEnabled': _notificationsEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (_notificationsEnabled) {
          await _notificationService.sendNotification(
            userId: user.uid,
            title: 'Notifications Enabled',
            message: 'You will now receive notifications',
            type: 'system',
          );
        }

        debugPrint('✅ Notification preference updated: $_notificationsEnabled');
      }
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
    }
  }
}

// ============================================
// Notification Screen Page
// ============================================

class NotificationScreenPage extends StatefulWidget {
  final String userId;

  const NotificationScreenPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<NotificationScreenPage> createState() => _NotificationScreenPageState();
}

class _NotificationScreenPageState extends State<NotificationScreenPage> {
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _notificationService.markAllAsRead(widget.userId);
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
            'Notifications',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<List<NotificationModel>>(
          stream: _notificationService.getUserNotifications(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data!;

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(notification);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    Color typeColor = _getTypeColor(notification.type);
    IconData typeIcon = _getTypeIcon(notification.type);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _handleNotificationTap(notification);
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        typeIcon,
                        color: typeColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () async {
                        await _notificationService
                            .deleteNotification(notification.notificationId);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'chat':
        return Color(0xFF4CAF50);
      case 'event':
        return Color(0xFF2196F3);
      case 'task':
        return Color(0xFFFFC107);
      case 'vendor':
        return Color(0xFFFF9800);
      case 'system':
        return Color(0xFF9C27B0);
      default:
        return Color(0xFF757575);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat;
      case 'event':
        return Icons.event;
      case 'task':
        return Icons.assignment;
      case 'vendor':
        return Icons.business;
      case 'system':
        return Icons.notifications;
      default:
        return Icons.notifications;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    debugPrint('Tapped notification: ${notification.type}');
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}