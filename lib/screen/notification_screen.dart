import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/utilty/app_responsive.dart';
import '../model/notification_model.dart';
import '../service/notification_service.dart';
import '../widget/animated_gradient_background.dart';

class NotificationScreen extends StatefulWidget {
  final String userId;

  const NotificationScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late NotificationService _notificationService;
  bool _markingAsRead = false;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();

    debugPrint(' NotificationScreen initialized for user: ${widget.userId}');


    _verifyNotifications();
  }


  Future<void> _verifyNotifications() async {
    await _notificationService.verifyNotificationsExist(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

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
              fontSize: AppResponsive.responsiveFont(24),
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: _buildNotificationsList(),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getUserNotifications(widget.userId),
      builder: (context, snapshot) {
        debugPrint('🔄 Stream state: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint(' Loading notifications...');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                ),
                SizedBox(height: AppResponsive.responsiveHeight(1.5)),
                Text(
                  'Loading notifications...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: AppResponsive.responsiveFont(14),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Stream error: ${snapshot.error}');
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppResponsive.responsiveFont(16),
                    color: Colors.red[400],
                  ),
                  SizedBox(height: AppResponsive.responsiveHeight(1.5)),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(
                      fontSize: AppResponsive.responsiveFont(16),
                      color: Colors.red[400],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppResponsive.responsiveHeight(0.8)),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontSize: AppResponsive.responsiveFont(11),
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppResponsive.responsiveHeight(2)),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint(' No notifications found');
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: AppResponsive.responsiveFont(20),
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: AppResponsive.responsiveHeight(1.5)),
                  Text(
                    'No Notifications',
                    style: TextStyle(
                      fontSize: AppResponsive.responsiveFont(18),
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppResponsive.responsiveHeight(0.8)),
                  Text(
                    'When something happens, you\'ll see it here',
                    style: TextStyle(
                      fontSize: AppResponsive.responsiveFont(14),
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppResponsive.responsiveHeight(2)),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      _verifyNotifications();
                    },
                    child: Text('Refresh'),
                  ),
                ],
              ),
            ),
          );
        }

        final notifications = snapshot.data!;
        debugPrint(' Loaded ${notifications.length} notifications');

        return ListView.builder(
          padding: EdgeInsets.all(AppResponsive.responsivePadding()),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification, index);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, int index) {
    Color typeColor = _getTypeColor(notification.type);
    IconData typeIcon = _getTypeIcon(notification.type);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.responsiveHeight(1.2)),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.responsiveFont(5.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(notification.isRead ? 0.04 : 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppResponsive.responsiveFont(5.5)),
          onTap: () async {
            debugPrint(' Notification tapped: ${notification.title}');

            // Mark as read
            if (!notification.isRead) {
              try {
                await _notificationService.markAsRead(notification.notificationId);
                debugPrint(' Marked as read: ${notification.notificationId}');
              } catch (e) {
                debugPrint(' Error marking as read: $e');
              }
            }

            _handleNotificationTap(notification);
          },
          child: Padding(
            padding: EdgeInsets.all(AppResponsive.responsiveFont(3.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: AppResponsive.responsiveSize(0.12),
                      height: AppResponsive.responsiveSize(0.12),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppResponsive.responsiveFont(5.5)),
                      ),
                      child: Icon(
                        typeIcon,
                        color: typeColor,
                        size: AppResponsive.responsiveFont(6),
                      ),
                    ),
                    SizedBox(width: AppResponsive.responsiveFont(2.5)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: AppResponsive.responsiveFont(16),
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                              color: notification.isRead ? Colors.grey[600] : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppResponsive.responsiveHeight(0.4)),
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontSize: AppResponsive.responsiveFont(13),
                              color: notification.isRead ? Colors.grey[500] : Colors.grey[600],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppResponsive.responsiveHeight(0.4)),
                          if (!notification.isRead)
                            _getNotificationBadge(notification, typeColor),
                        ],
                      ),
                    ),
                    SizedBox(width: AppResponsive.responsiveFont(2)),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey, size: AppResponsive.responsiveFont(5)),
                      onPressed: () async {
                        debugPrint('️ Deleting notification: ${notification.notificationId}');
                        try {
                          await _notificationService.deleteNotification(
                            notification.notificationId,
                          );
                          debugPrint(' Notification deleted successfully');
                        } catch (e) {
                          debugPrint(' Error deleting notification: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting notification'),
                                backgroundColor: Colors.red[600],
                              ),
                            );
                          }
                        }
                      },
                      padding: EdgeInsets.zero,
                      iconSize: AppResponsive.responsiveFont(5),
                    ),
                  ],
                ),
                SizedBox(height: AppResponsive.responsiveHeight(0.8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: AppResponsive.responsiveFont(11),
                        color: notification.isRead ? Colors.grey[400] : Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${notification.notificationId.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: AppResponsive.responsiveFont(8.5),
                        color: notification.isRead ? Colors.grey[300] : Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getNotificationBadge(NotificationModel notification, Color typeColor) {
    final title = notification.title.toLowerCase();
    final message = notification.message.toLowerCase();

    // Collaborator Invite - Pink badge dengan icon person_add
    if (title.contains('collaborator') && title.contains('invite')) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.responsiveFont(2.5),
          vertical: AppResponsive.responsiveFont(1),
        ),
        decoration: BoxDecoration(
          color: Color(0xFFE91E63).withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppResponsive.responsiveFont(3.5)),
          border: Border.all(
            color: Color(0xFFE91E63),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add,
              size: AppResponsive.responsiveFont(7),
              color: Color(0xFFE91E63),
            ),
            SizedBox(width: AppResponsive.responsiveFont(0.5)),
            Text(
              'INVITE',
              style: TextStyle(
                fontSize: AppResponsive.responsiveFont(9),
                color: Color(0xFFE91E63),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Event Missing - Red badge dengan icon warning
    if (title.contains('missing') || message.contains('has passed')) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.responsiveFont(2.5),
          vertical: AppResponsive.responsiveFont(1),
        ),
        decoration: BoxDecoration(
          color: Color(0xFFF44336).withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppResponsive.responsiveFont(3.5)),
          border: Border.all(
            color: Color(0xFFF44336),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              size: AppResponsive.responsiveFont(7),
              color: Color(0xFFF44336),
            ),
            SizedBox(width: AppResponsive.responsiveFont(0.5)),
            Text(
              'MISSING',
              style: TextStyle(
                fontSize: AppResponsive.responsiveFont(9),
                color: Color(0xFFF44336),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Default badge
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.responsiveFont(2),
        vertical: AppResponsive.responsiveFont(0.8),
      ),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppResponsive.responsiveFont(3.5)),
      ),
      child: Text(
        notification.type.toUpperCase(),
        style: TextStyle(
          fontSize: AppResponsive.responsiveFont(9),
          color: typeColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
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
    switch (type.toLowerCase()) {
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
    debugPrint(' Handling tap for type: ${notification.type}');

    final title = notification.title.toLowerCase();
    final message = notification.message.toLowerCase();

    // Handle Collaborator Invite
    if (title.contains('collaborator') && title.contains('invite')) {
      debugPrint('   → Collaborator invite for event: ${notification.relatedId}');
      return;
    }

    // Handle Event Missing
    if (title.contains('missing') || message.contains('has passed')) {
      debugPrint('   → Missing event: ${notification.relatedId}');
      return;
    }

    // Handle other types
    switch (notification.type.toLowerCase()) {
      case 'chat':
        debugPrint('   → Would navigate to chat: ${notification.relatedId}');
        break;
      case 'event':
        debugPrint('   → Would navigate to event: ${notification.relatedId}');
        break;
      case 'task':
        debugPrint('   → Would navigate to task: ${notification.relatedId}');
        break;
      case 'vendor':
        debugPrint('   → Would navigate to vendor: ${notification.relatedId}');
        break;
      default:
        debugPrint('   → Unknown type, no navigation');
        break;
    }
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