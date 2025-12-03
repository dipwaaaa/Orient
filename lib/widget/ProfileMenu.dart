import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/screen/Setting/ProfileScreen.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/notification_service.dart';
import '../screen/login_signup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utilty/app_responsive.dart';
import '../provider/auth_provider.dart';


/// Avatar Widget dengan Notification Icon
class Profilemenu extends StatelessWidget {
  final AuthService authService;
  final String username;
  final bool showNotificationIcon;
  final VoidCallback? onNotificationTap;

  const Profilemenu({
    Key? key,
    required this.authService,
    required this.username,
    this.showNotificationIcon = true,
    this.onNotificationTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.spacingSmall()),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadiusLarge(),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showNotificationIcon) ...[
            Container(
              width: AppResponsive.avatarRadius(),
              height: AppResponsive.avatarRadius(),
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onNotificationTap,
                  customBorder: CircleBorder(),
                  child: Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: AppResponsive.notificationIconSize(),
                  ),
                ),
              ),
            ),
            SizedBox(width: AppResponsive.spacingSmall()),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ProfileMenu.show(context, authService, username);
            },
            child: Container(
              width: AppResponsive.avatarRadius(),
              height: AppResponsive.avatarRadius(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDEF3FF),
              ),
              child: ClipOval(
                child: authService.currentUser?.photoURL != null
                    ? Image.network(
                  authService.currentUser!.photoURL!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/image/AvatarKimmy.png',
                      fit: BoxFit.cover,
                    );
                  },
                )
                    : Image.asset(
                  'assets/image/AvatarKimmy.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Avatar Widget (hanya avatar)
class AvatarWidgetCompact extends StatelessWidget {
  final AuthService authService;
  final String username;

  const AvatarWidgetCompact({
    Key? key,
    required this.authService,
    required this.username,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ProfileMenu.show(context, authService, username);
      },
      child: Container(
        width: AppResponsive.avatarRadius(),
        height: AppResponsive.avatarRadius(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDEF3FF),
        ),
        child: ClipOval(
          child: authService.currentUser?.photoURL != null
              ? Image.network(
            authService.currentUser!.photoURL!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/image/AvatarKimmy.png',
                fit: BoxFit.cover,
              );
            },
          )
              : Image.asset(
            'assets/image/AvatarKimmy.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// Header Widget dengan Avatar - Kombinasi greeting + avatar
class HeaderWithAvatar extends StatelessWidget {
  final String username;
  final String greeting;
  final String subtitle;
  final AuthService authService;
  final VoidCallback? onNotificationTap;

  const HeaderWithAvatar({
    Key? key,
    required this.username,
    required this.greeting,
    required this.subtitle,
    required this.authService,
    this.onNotificationTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppResponsive.responsivePadding()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.headerFontSize(),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: AppResponsive.spacingSmall()),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.subtitleFontSize(),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Profilemenu(
            authService: authService,
            username: username,
            showNotificationIcon: true,
            onNotificationTap: onNotificationTap,
          ),
        ],
      ),
    );
  }
}


class ProfileMenu {
  /// Tampilkan profile menu dari mana saja
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
      final userDoc = await widget.authService.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final profileImg = data?['profileImageUrl'];

        setState(() {
          if (profileImg != null && profileImg.isNotEmpty) {
            _profileImageUrl = profileImg;
          } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
            _profileImageUrl = user.photoURL;
          } else {
            _profileImageUrl = null;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
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
      } catch (e) {
        debugPrint('Error loading unread notifications count: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProfileHeader(),
          Divider(height: 1),
          _buildNotificationTile(),
          _buildSettingsTile(),
          _buildLogoutTile(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _isLoading
              ? CircleAvatar(
            radius: AppResponsive.screenWidth * 0.15,
            backgroundColor: Color(0xFFDEF3FF),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFFFF6A00),
              ),
            ),
          )
              : CircleAvatar(
            radius: AppResponsive.screenWidth * 0.15,
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
    );
  }

  Widget _buildNotificationTile() {
    return Stack(
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
    );
  }

  Widget _buildSettingsTile() {
    return ListTile(
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
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      leading: Icon(Icons.logout, color: Colors.red),
      title: Text(
        'Sign Out',
        style: TextStyle(fontFamily: 'SF Pro'),
      ),
      onTap: () async {
        Navigator.pop(context);

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

        if (mounted) {
          await Provider.of<AuthStateProvider>(context, listen: false)
              .logout(context);
        }
      },
    );
  }
}


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
    AppResponsive.init(context);

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