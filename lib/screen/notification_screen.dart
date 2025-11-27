import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/notification_model.dart';
import '../service/notification_service.dart';
import '../widget/Animated_Gradient_Background.dart'; // Sesuaikan import path

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

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    // Mark all as read ketika membuka screen
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
            // Handle notification tap (navigate ke related resource)
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
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Delete button
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
                // Timestamp
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
    // Navigate ke related resource based on type
    switch (notification.type) {
      case 'chat':
      // Navigate ke chat screen dengan chatId
      // Navigator.push(...);
        break;
      case 'event':
      // Navigate ke event detail screen dengan eventId
        break;
      case 'task':
      // Navigate ke task detail screen
        break;
      case 'vendor':
      // Navigate ke vendor screen
        break;
      default:
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