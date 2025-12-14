import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new event with default status "Pending"
  Future<Map<String, dynamic>> createEvent({
    required String eventName,
    required DateTime eventDate,
    required String eventType,
    required String eventLocation,
    required String description,
    required String ownerId,
    List<String>? collaborators,
    double? budget,
  }) async {
    try {
      final now = Timestamp.now();

      // Create event document
      final eventRef = _firestore.collection('events').doc();

      final eventData = {
        'eventId': eventRef.id,
        'eventName': eventName.trim(),
        'eventDate': Timestamp.fromDate(eventDate),
        'eventType': eventType.trim(),
        'eventLocation': eventLocation.trim(),
        'description': description.trim(),
        'ownerId': ownerId,
        'collaborators': collaborators ?? [],
        'budget': budget ?? 0.0,
        'eventStatus': 'Pending', // DEFAULT STATUS
        'createdAt': now,
        'updatedAt': now,
      };

      await eventRef.set(eventData);

      debugPrint('Event created successfully: ${eventRef.id}');

      return {
        'success': true,
        'eventId': eventRef.id,
        'message': 'Event created successfully!',
      };
    } catch (e) {
      debugPrint('Error creating event: $e');
      return {
        'success': false,
        'error': 'Failed to create event: $e',
      };
    }
  }

  /// Update an existing event
  Future<Map<String, dynamic>> updateEvent({
    required String eventId,
    String? eventName,
    DateTime? eventDate,
    String? eventType,
    String? eventLocation,
    String? description,
    String? eventStatus,
    List<String>? collaborators,
    double? budget,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (eventName != null) updateData['eventName'] = eventName.trim();
      if (eventDate != null) updateData['eventDate'] = Timestamp.fromDate(eventDate);
      if (eventType != null) updateData['eventType'] = eventType.trim();
      if (eventLocation != null) updateData['eventLocation'] = eventLocation.trim();
      if (description != null) updateData['description'] = description.trim();
      if (eventStatus != null) updateData['eventStatus'] = eventStatus;
      if (collaborators != null) updateData['collaborators'] = collaborators;
      if (budget != null) updateData['budget'] = budget;

      await _firestore.collection('events').doc(eventId).update(updateData);

      debugPrint('Event updated successfully: $eventId');

      return {
        'success': true,
        'message': 'Event updated successfully!',
      };
    } catch (e) {
      debugPrint('Error updating event: $e');
      return {
        'success': false,
        'error': 'Failed to update event: $e',
      };
    }
  }

  /// Delete event and all related data (cascade delete)
  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    try {
      // Delete related tasks
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in tasksSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${tasksSnapshot.docs.length} tasks');

      // Delete related budgets
      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in budgetsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${budgetsSnapshot.docs.length} budgets');

      // Delete related vendors
      final vendorsSnapshot = await _firestore
          .collection('vendors')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in vendorsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${vendorsSnapshot.docs.length} vendors');

      // Delete related guests
      final guestsSnapshot = await _firestore
          .collection('guests')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in guestsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${guestsSnapshot.docs.length} guests');

      // Delete the event
      await _firestore.collection('events').doc(eventId).delete();

      debugPrint('Event deleted successfully: $eventId');

      return {
        'success': true,
        'message': 'Event and all related data deleted successfully!',
      };
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return {
        'success': false,
        'error': 'Failed to delete event: $e',
      };
    }
  }

  /// Get event by ID
  Future<Map<String, dynamic>?> getEvent(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting event: $e');
      return null;
    }
  }

  /// Get all events for a user (as owner)
  Stream<QuerySnapshot> getUserEvents(String userId) {
    return _firestore
        .collection('events')
        .where('ownerId', isEqualTo: userId)
        .orderBy('eventDate', descending: false)
        .snapshots();
  }

  /// Get events where user is a collaborator
  Stream<QuerySnapshot> getCollaboratorEvents(String userId) {
    return _firestore
        .collection('events')
        .where('collaborators', arrayContains: userId)
        .orderBy('eventDate', descending: false)
        .snapshots();
  }

  /// Update event status
  Future<Map<String, dynamic>> updateEventStatus(
      String eventId,
      String newStatus,
      ) async {
    final validStatuses = ['Pending', 'Ongoing', 'Completed', 'Cancelled'];

    if (!validStatuses.contains(newStatus)) {
      return {
        'success': false,
        'error': 'Invalid status. Must be one of: ${validStatuses.join(", ")}',
      };
    }

    try {
      await _firestore.collection('events').doc(eventId).update({
        'eventStatus': newStatus,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Event status updated: $eventId -> $newStatus');

      return {
        'success': true,
        'message': 'Event status updated to $newStatus',
      };
    } catch (e) {
      debugPrint('Error updating event status: $e');
      return {
        'success': false,
        'error': 'Failed to update event status: $e',
      };
    }
  }

  /// Add collaborator to event
  Future<Map<String, dynamic>> addCollaborator(
      String eventId,
      String userId,
      ) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'collaborators': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Collaborator added: $userId to event $eventId');

      return {
        'success': true,
        'message': 'Collaborator added successfully!',
      };
    } catch (e) {
      debugPrint('Error adding collaborator: $e');
      return {
        'success': false,
        'error': 'Failed to add collaborator: $e',
      };
    }
  }

  /// Remove collaborator from event
  Future<Map<String, dynamic>> removeCollaborator(
      String eventId,
      String userId,
      ) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'collaborators': FieldValue.arrayRemove([userId]),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('Collaborator removed: $userId from event $eventId');

      return {
        'success': true,
        'message': 'Collaborator removed successfully!',
      };
    } catch (e) {
      debugPrint('Error removing collaborator: $e');
      return {
        'success': false,
        'error': 'Failed to remove collaborator: $e',
      };
    }
  }

  /// Get event count by status for a user
  Future<Map<String, int>> getEventCountByStatus(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('ownerId', isEqualTo: userId)
          .get();

      final counts = {
        'Pending': 0,
        'Ongoing': 0,
        'Completed': 0,
        'Cancelled': 0,
      };

      for (var doc in snapshot.docs) {
        final status = doc.data()['eventStatus'] ?? 'Pending';
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('Error getting event count: $e');
      return {
        'Pending': 0,
        'Ongoing': 0,
        'Completed': 0,
        'Cancelled': 0,
      };
    }
  }

  /// Auto-delete past events for a user
  /// Call this periodically (e.g., when app starts, when user opens event list)
  Future<int> autoDeletePastEvents(String userId) async {
    try {
      debugPrint('🗑️ Starting auto-delete past events for user: $userId');

      final now = DateTime.now();
      final pastThreshold = Timestamp.fromDate(now);

      // Get all past events owned by this user
      final ownerSnapshot = await _firestore
          .collection('events')
          .where('ownerId', isEqualTo: userId)
          .where('eventDate', isLessThan: pastThreshold)
          .get();

      int deletedCount = 0;

      for (var doc in ownerSnapshot.docs) {
        final eventData = doc.data();
        final eventName = eventData['eventName'] ?? 'Unknown Event';
        final collaborators = List<String>.from(eventData['collaborators'] as List<dynamic>? ?? []);

        // Send notification to owner
        await _sendEventDeletedNotification(
          userId: userId,
          eventName: eventName,
          eventId: doc.id,
        );

        // Send notification to all collaborators
        for (String collaboratorId in collaborators) {
          await _sendEventDeletedNotification(
            userId: collaboratorId,
            eventName: eventName,
            eventId: doc.id,
            isCollaborator: true,
          );
        }

        // Delete the event (cascade delete)
        await deleteEvent(doc.id);
        deletedCount++;

        debugPrint('✅ Auto-deleted past event: ${doc.id} ($eventName)');
      }

      if (deletedCount > 0) {
        debugPrint('🎉 Auto-deleted $deletedCount past events');
      }

      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error auto-deleting past events: $e');
      return 0;
    }
  }

  /// Send notification when event is auto-deleted
  Future<void> _sendEventDeletedNotification({
    required String userId,
    required String eventName,
    required String eventId,
    bool isCollaborator = false,
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;

      await _firestore.collection('notifications').doc(notificationId).set({
        'notificationId': notificationId,
        'userId': userId,
        'title': 'Event Ended',
        'message': isCollaborator
            ? '✓ "$eventName" has ended and been archived.'
            : '✓ Your event "$eventName" has ended and been archived.',
        'type': 'event',
        'relatedId': eventId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'isAutoDeleted': true,
      });

      debugPrint('📧 Notification sent to $userId for deleted event: $eventName');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Get list of auto-deleted events (for notification history)
  Stream<QuerySnapshot> getAutoDeletedEventNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'event')
        .where('isAutoDeleted', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Format time remaining until event
  String formatTimeRemaining(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.isNegative) {
      return '⏰ Event has ended';
    }

    if (difference.inDays > 0) {
      return '⏰ In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '⏰ In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '⏰ In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return '⏰ Starting now!';
    }
  }
}