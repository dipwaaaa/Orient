import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/screen/Setting/profile_screen.dart';
import '/service/auth_service.dart';
import '/service/notification_service.dart';
import '../screen/notification_screen.dart';
import '../utilty/app_responsive.dart';
import '../provider/auth_provider.dart';

class Profilemenu extends StatefulWidget {
  final AuthService authService;
  final String username;
  final bool showNotificationIcon;
  final VoidCallback? onNotificationTap;
  final BuildContext parentContext;

  const Profilemenu({
    super.key,
    required this.authService,
    required this.username,
    this.showNotificationIcon = true,
    this.onNotificationTap,
    required this.parentContext,
  });

  @override
  State<Profilemenu> createState() => _ProfilemenuState();
}

class _ProfilemenuState extends State<Profilemenu> {
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    debugPrint('🔔 Profilemenu initialized');
  }

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
          if (widget.showNotificationIcon) ...[
            _buildNotificationIcon(),
            SizedBox(width: AppResponsive.spacingSmall()),
          ],
          _buildAvatarButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    final user = widget.authService.currentUser;

    if (user == null) {
      return _buildNotificationIconWithBadge(0);
    }

    return StreamBuilder<int>(
      stream: _notificationService.getUnreadCountStream(user.uid),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;

        if (snapshot.hasError) {
          debugPrint(' Badge stream error: ${snapshot.error}');
        }

        return _buildNotificationIconWithBadge(unreadCount);
      },
    );
  }

  Widget _buildNotificationIconWithBadge(int unreadCount) {
    return Container(
      width: AppResponsive.avatarRadius(),
      height: AppResponsive.avatarRadius(),
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final user = widget.authService.currentUser;
                if (user != null) {
                  debugPrint('Navigating to notification screen for user: ${user.uid}');
                  Navigator.push(
                    widget.parentContext,
                    MaterialPageRoute(
                      builder: (context) => NotificationScreen(userId: user.uid),
                    ),
                  ).then((_) {
                    debugPrint('Returned from NotificationScreen, rebuilding');
                    setState(() {});
                  });
                }
                widget.onNotificationTap?.call();
              },
              customBorder: CircleBorder(),
              child: Icon(
                Icons.notifications,
                color: Colors.white,
                size: AppResponsive.notificationIconSize(),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6A00),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ProfileMenu.show(context, widget.authService, widget.username);
      },
      child: Container(
        width: AppResponsive.avatarRadius(),
        height: AppResponsive.avatarRadius(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDEF3FF),
        ),
        child: ClipOval(
          child: widget.authService.currentUser?.photoURL != null
              ? Image.network(
            widget.authService.currentUser!.photoURL!,
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

class AvatarWidgetCompact extends StatelessWidget {
  final AuthService authService;
  final String username;

  const AvatarWidgetCompact({
    super.key,
    required this.authService,
    required this.username,
  });

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

class HeaderWithAvatar extends StatelessWidget {
  final String username;
  final String greeting;
  final String subtitle;
  final AuthService authService;
  final VoidCallback? onNotificationTap;

  const HeaderWithAvatar({
    super.key,
    required this.username,
    required this.greeting,
    required this.subtitle,
    required this.authService,
    this.onNotificationTap,
  });

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
            parentContext: context,
          ),
        ],
      ),
    );
  }
}

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
        final _ = await _notificationService.getUnreadCount(user.uid);
        setState(() {
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