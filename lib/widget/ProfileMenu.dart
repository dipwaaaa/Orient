import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import '../screen/login_signup_screen.dart';
import '../screen/Setting/SettingScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileMenu {
  static void show(
      BuildContext context,
      AuthService authService,
      String username,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileMenuContent(
        authService: authService,
        username: username,
      ),
    );
  }

  static Future<void> _handleSignOut(
      BuildContext context, AuthService authService) async {
    try {
      // Sign out dari Firebase
      await authService.signOut();

      // Tunggu sebentar untuk memastikan sign out selesai
      await Future.delayed(Duration(milliseconds: 300));

      // Tutup loading dialog jika masih terbuka
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Navigate ke login screen dan hapus semua route
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Sign out error: $e');

      // Tutup loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Tampilkan error
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

class _ProfileMenuContent extends StatefulWidget {
  final AuthService authService;
  final String username;

  const _ProfileMenuContent({
    required this.authService,
    required this.username,
  });

  @override
  State<_ProfileMenuContent> createState() => _ProfileMenuContentState();
}

class _ProfileMenuContentState extends State<_ProfileMenuContent> {
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final user = widget.authService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load profile image from Firestore
      final userDoc = await widget.authService.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final profileImg = data?['profileImageUrl'];

        setState(() {
          // Priority: 1) Firestore profileImageUrl, 2) Google photoURL, 3) null (default Kimmy)
          if (profileImg != null && profileImg.isNotEmpty) {
            _profileImageUrl = profileImg;
          } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
            _profileImageUrl = user.photoURL;
          } else {
            _profileImageUrl = null; // Will show default Kimmy avatar
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          // Use Google photoURL if available, otherwise null
          _profileImageUrl = (user.photoURL != null && user.photoURL!.isNotEmpty)
              ? user.photoURL
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
      setState(() {
        _profileImageUrl = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                _isLoading
                    ? CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFDEF3FF),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6A00),
                    ),
                  ),
                )
                    : CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFDEF3FF),
                  backgroundImage: _profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : AssetImage('assets/image/AvatarKimmy.png')
                  as ImageProvider,
                ),
                SizedBox(height: 16),
                Text(
                  widget.username,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.authService.currentUser?.email ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.settings, color: Color(0xFFFF6A00)),
            title: Text('Profile Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingScreen(authService: widget.authService),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Sign Out'),
            onTap: () async {
              // Tutup bottom sheet
              Navigator.pop(context);

              // Tampilkan loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFE100),
                    ),
                  ),
                ),
              );

              // Sign out
              await ProfileMenu._handleSignOut(context, widget.authService);
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}