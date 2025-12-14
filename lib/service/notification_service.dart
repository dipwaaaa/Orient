import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../model/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Send notification ke user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'chat', 'event', 'task', 'vendor', etc
    String? relatedId,
    bool isAutoDeleted = false,
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;
      final notification = NotificationModel(
        notificationId: notificationId,
        userId: userId,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notification.toMap());

      debugPrint('✅ Notification sent to $userId: "$title"');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      rethrow;
    }
  }

  // ✅ Get unread notifications count (Stream - Real-time)
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      int count = snapshot.docs.length;
      debugPrint('📊 Unread count for $userId: $count');
      return count;
    });
  }

  // ✅ Get unread notifications count (Future - One-time)
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      int count = snapshot.count ?? 0;
      debugPrint('📊 Unread count (future) for $userId: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // ✅ Get all notifications for user (with proper error handling)
  Stream<List<NotificationModel>> getUserNotifications(
      String userId, {
        int limit = 50,
      }) {
    try {
      debugPrint('🔄 Fetching notifications for user: $userId');

      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        List<NotificationModel> notifications = snapshot.docs
            .map((doc) {
          try {
            return NotificationModel.fromMap(doc.data());
          } catch (e) {
            debugPrint('❌ Error parsing notification: $e');
            return null;
          }
        })
            .whereType<NotificationModel>()
            .toList();

        debugPrint('📬 Loaded ${notifications.length} notifications for $userId');

        // Print first notification for debugging
        if (notifications.isNotEmpty) {
          debugPrint('   First notification: "${notifications.first.title}"');
          debugPrint('   Type: ${notifications.first.type}');
          debugPrint('   isRead: ${notifications.first.isRead}');
        }

        return notifications;
      }).handleError((error) {
        debugPrint('❌ Stream error: $error');
        return <NotificationModel>[];
      });
    } catch (e) {
      debugPrint('❌ Error in getUserNotifications: $e');
      return Stream.value([]);
    }
  }

  // ✅ Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': DateTime.now(),
      });
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  // ✅ Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      debugPrint('📌 Marking all notifications as read for $userId');

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      debugPrint('   Found ${snapshot.docs.length} unread notifications');

      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'isRead': true,
          'readAt': DateTime.now(),
        });
      }
      debugPrint('✅ All notifications marked as read for $userId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // ✅ Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      rethrow;
    }
  }

  // ✅ Delete all notifications for user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('✅ All notifications deleted for $userId');
    } catch (e) {
      debugPrint('❌ Error deleting all notifications: $e');
      rethrow;
    }
  }

  // ✅ Send notification ke multiple users (untuk auto-delete)
  Future<void> sendBroadcastNotification({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    bool isAutoDeleted = false,
  }) async {
    try {
      debugPrint('📢 Sending broadcast to ${userIds.length} users: "$title"');

      for (String userId in userIds) {
        await sendNotification(
          userId: userId,
          title: title,
          message: message,
          type: type,
          relatedId: relatedId,
          isAutoDeleted: isAutoDeleted,
        );
      }
      debugPrint('✅ Broadcast notification sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending broadcast notification: $e');
      rethrow;
    }
  }

  // ✅ NEW: Get notification details
  Future<NotificationModel?> getNotification(String notificationId) async {
    try {
      final doc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (doc.exists) {
        return NotificationModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting notification: $e');
      debugPrint('❌ Error getting notification: $e');
      return null;
    }
  }

  // ✅ NEW: Verify notifications exist in Firestore
  Future<void> verifyNotificationsExist(String userId) async {
    try {
      final allDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(10)
          .get();

      debugPrint('🔍 Verification: Found ${allDocs.docs.length} notifications for $userId');

      for (int i = 0; i < allDocs.docs.length; i++) {
        final data = allDocs.docs[i].data();
        debugPrint('   [$i] ${data['title']} (isRead: ${data['isRead']})');
      }
    } catch (e) {
      debugPrint('❌ Error verifying notifications: $e');
    }
  }
}