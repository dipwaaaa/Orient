import 'package:flutter/material.dart';
import 'package:untitled/screen/Setting/ProfileScreen.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/notification_service.dart';
import '../screen/login_signup_screen.dart';
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
  late NotificationService _notificationService;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _loadProfileImage();
    _loadUnreadNotificationsCount();
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

  Future<void> _loadUnreadNotificationsCount() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      try {
        final count = await _notificationService.getUnreadCount(user.uid);
        setState(() {
          _unreadNotificationsCount = count;
        });
        debugPrint('Unread notifications in menu: $count');
      } catch (e) {
        debugPrint('Error loading unread notifications count: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
                  radius: screenWidth * 0.15,
                  backgroundColor: Color(0xFFDEF3FF),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6A00),
                    ),
                  ),
                )
                    : CircleAvatar(
                  radius: screenWidth * 0.15,
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
                    fontFamily: 'SF Pro',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.authService.currentUser?.email ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'SF Pro',
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),

          // Notifications option with badge
          Stack(
            children: [
              ListTile(
                leading: Icon(Icons.notifications, color: Color(0xFFFF6A00)),
                title: Text(
                  'Notifications',
                  style: TextStyle(fontFamily: 'SF Pro'),
                ),
                onTap: () {
                  Navigator.pop(context);
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
              // Badge untuk unread notifications
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 16,
                  top: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _unreadNotificationsCount > 99
                          ? '99+'
                          : '$_unreadNotificationsCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          ListTile(
            leading: Icon(Icons.settings, color: Color(0xFFFF6A00)),
            title: Text(
              'Profile Settings',
              style: TextStyle(fontFamily: 'SF Pro'),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(authService: widget.authService),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'SF Pro'),
            ),
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

// Import NotificationScreenPage dari ProfileScreen
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
    return Scaffold(
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
      body: StreamBuilder(
        stream: _notificationService.getUserNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
              ),
            );
          }

          if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
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

          final notifications = snapshot.data as List;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationCard(notifications[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notification) {
    final title = notification.title ?? 'Notification';
    final message = notification.message ?? '';
    final type = notification.type ?? 'system';
    final notificationId = notification.notificationId ?? '';

    Color typeColor = _getTypeColor(type);
    IconData typeIcon = _getTypeIcon(type);

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
                          title,
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
                          message,
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
                      await _notificationService.deleteNotification(notificationId);
                    },
                  ),
                ],
              ),
            ],
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
}