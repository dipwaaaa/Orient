import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/notification_model.dart';
import '../service/notification_service.dart';
import '../widget/Animated_Gradient_Background.dart';

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

    debugPrint('🔔 NotificationScreen initialized for user: ${widget.userId}');

    // Mark all as read when entering screen
    _markAllAsReadOnEntry();

    // Verify notifications exist (for debugging)
    _verifyNotifications();
  }

  // Mark all as read when screen opens
  Future<void> _markAllAsReadOnEntry() async {
    if (_markingAsRead) return;

    setState(() => _markingAsRead = true);

    try {
      await _notificationService.markAllAsRead(widget.userId);
      debugPrint('✅ All notifications marked as read on screen entry');
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
    } finally {
      if (mounted) {
        setState(() => _markingAsRead = false);
      }
    }
  }

  // Verify notifications exist in Firestore
  Future<void> _verifyNotifications() async {
    await _notificationService.verifyNotificationsExist(widget.userId);
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
        body: _buildNotificationsList(),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getUserNotifications(widget.userId),
      builder: (context, snapshot) {
        debugPrint('🔄 Stream state: ${snapshot.connectionState}');

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Loading notifications...');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading notifications...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          debugPrint('❌ Stream error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                SizedBox(height: 16),
                Text(
                  'Error loading notifications',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        // No data state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint('📭 No notifications found');
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
                SizedBox(height: 8),
                Text(
                  'When something happens, you\'ll see it here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _verifyNotifications();
                  },
                  child: Text('Refresh'),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data!;
        debugPrint('✅ Loaded ${notifications.length} notifications');

        return ListView.builder(
          padding: EdgeInsets.all(16),
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
            debugPrint('📌 Notification tapped: ${notification.title}');
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
                    // Icon
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
                    // Content
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
                          SizedBox(height: 4),
                          // Type badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: typeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Delete button
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () async {
                        debugPrint('🗑️ Deleting notification: ${notification.notificationId}');
                        try {
                          await _notificationService.deleteNotification(
                            notification.notificationId,
                          );
                          debugPrint('✅ Notification deleted successfully');
                        } catch (e) {
                          debugPrint('❌ Error deleting notification: $e');
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
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    // Debug info
                    Text(
                      'ID: ${notification.notificationId.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                      ),
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'chat':
        return Color(0xFF4CAF50); // Green
      case 'event':
        return Color(0xFF2196F3); // Blue
      case 'task':
        return Color(0xFFFFC107); // Amber
      case 'vendor':
        return Color(0xFFFF9800); // Orange
      case 'system':
        return Color(0xFF9C27B0); // Purple
      default:
        return Color(0xFF757575); // Grey
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
    debugPrint('📍 Handling tap for type: ${notification.type}');
    // Navigate ke related resource based on type
    switch (notification.type) {
      case 'chat':
        debugPrint('   → Would navigate to chat: ${notification.relatedId}');
        // Navigator.push(...);
        break;
      case 'event':
        debugPrint('   → Would navigate to event: ${notification.relatedId}');
        // Navigator.push(...);
        break;
      case 'task':
        debugPrint('   → Would navigate to task: ${notification.relatedId}');
        // Navigator.push(...);
        break;
      case 'vendor':
        debugPrint('   → Would navigate to vendor: ${notification.relatedId}');
        // Navigator.push(...);
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