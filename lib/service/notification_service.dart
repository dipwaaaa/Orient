import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../model/notification_model.dart'; // Sesuaikan path dengan struktur project kamu

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send notification ke user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'chat', 'event', 'task', 'vendor', etc
    String? relatedId,
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

      debugPrint('✅ Notification sent to $userId: $title');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      rethrow;
    }
  }

  // Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Get all notifications for user (with pagination)
  Stream<List<NotificationModel>> getUserNotifications(
      String userId, {
        int limit = 20,
      }) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
      });
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
      debugPrint('✅ All notifications marked as read for $userId');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  // Delete all notifications for user
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
      debugPrint('Error deleting all notifications: $e');
      rethrow;
    }
  }

  // Example: Send notification ke multiple users
  Future<void> sendBroadcastNotification({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      for (String userId in userIds) {
        await sendNotification(
          userId: userId,
          title: title,
          message: message,
          type: type,
          relatedId: relatedId,
        );
      }
      debugPrint('✅ Broadcast notification sent to ${userIds.length} users');
    } catch (e) {
      debugPrint('Error sending broadcast notification: $e');
      rethrow;
    }
  }
}