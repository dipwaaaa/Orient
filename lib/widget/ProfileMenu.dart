import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import '../screen/login_signup_screen.dart';

class ProfileMenu {
  static void show(
      BuildContext context,
      AuthService authService,
      String username,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFDEF3FF),
                    backgroundImage: authService.currentUser?.photoURL != null
                        ? NetworkImage(authService.currentUser!.photoURL!)
                        : AssetImage('assets/image/AvatarKimmy.png')
                    as ImageProvider,
                  ),
                  SizedBox(height: 16),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    authService.currentUser?.email ?? '',
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
              leading: Icon(Icons.person, color: Color(0xFFFF6A00)),
              title: Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile settings coming soon!')),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                    ),
                  ),
                );

                // Sign out
                await _handleSignOut(context, authService);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Future<void> _handleSignOut(BuildContext context, AuthService authService) async {
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