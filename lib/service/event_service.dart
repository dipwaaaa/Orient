import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        'eventStatus': 'Pending',
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

  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    try {
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in tasksSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${tasksSnapshot.docs.length} tasks');

      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in budgetsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${budgetsSnapshot.docs.length} budgets');

      final vendorsSnapshot = await _firestore
          .collection('vendors')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in vendorsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${vendorsSnapshot.docs.length} vendors');

      final guestsSnapshot = await _firestore
          .collection('guests')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (var doc in guestsSnapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('Deleted ${guestsSnapshot.docs.length} guests');

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

  Stream<List<Map<String, dynamic>>> getUserEvents(String userId) {
    return _firestore
        .collection('events')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      events.sort((a, b) {
        final statusA = a['eventStatus'] ?? 'Pending';
        final statusB = b['eventStatus'] ?? 'Pending';
        final dateA = (a['eventDate'] as Timestamp).toDate();
        final dateB = (b['eventDate'] as Timestamp).toDate();

        if (statusA == 'Completed' && statusB != 'Completed') return 1;
        if (statusA != 'Completed' && statusB == 'Completed') return -1;
        if (statusA != 'Completed' && statusB != 'Completed') {
          return dateA.compareTo(dateB);
        }
        return 0;
      });

      return events;
    });
  }

  Stream<List<Map<String, dynamic>>> getCollaboratorEvents(String userId) {
    return _firestore
        .collection('events')
        .where('collaborators', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      events.sort((a, b) {
        final statusA = a['eventStatus'] ?? 'Pending';
        final statusB = b['eventStatus'] ?? 'Pending';
        final dateA = (a['eventDate'] as Timestamp).toDate();
        final dateB = (b['eventDate'] as Timestamp).toDate();

        if (statusA == 'Completed' && statusB != 'Completed') return 1;
        if (statusA != 'Completed' && statusB == 'Completed') return -1;
        if (statusA != 'Completed' && statusB != 'Completed') {
          return dateA.compareTo(dateB);
        }
        return 0;
      });

      return events;
    });
  }

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

  Future<Map<String, dynamic>> addCollaborator(

      String eventId,
      String userId,
      String collaboratorUsername,
      ) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'success': false,
          'error': 'Event not found',
        };
      }

      final eventName = eventDoc['eventName'] ?? 'Unknown Event';

      await _firestore.collection('events').doc(eventId).update({
        'collaborators': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.now(),
      });

      await _sendCollaboratorInviteNotification(
        userId: userId,
        eventName: eventName,
        eventId: eventId,
        inviterUsername: collaboratorUsername,
      );


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

  Future<void> checkMissingPastEvents(String userId) async {
    try {
      debugPrint('Checking for missing past events for user: $userId');

      final now = DateTime.now();
      final pastThreshold = Timestamp.fromDate(now);

      final ownerSnapshot = await _firestore
          .collection('events')
          .where('ownerId', isEqualTo: userId)
          .where('eventDate', isLessThan: pastThreshold)
          .get();

      for (var doc in ownerSnapshot.docs) {
        final eventData = doc.data();
        final eventStatus = eventData['eventStatus'] ?? 'Pending';
        final eventName = eventData['eventName'] ?? 'Unknown Event';

        if (eventStatus != 'Completed') {
          await _sendMissingEventNotification(
            userId: userId,
            eventName: eventName,
            eventId: doc.id,
            isOwner: true,
          );
          debugPrint('Missing event notification sent: $eventName (Owner)');
        }
      }

      final collaboratorSnapshot = await _firestore
          .collection('events')
          .where('collaborators', arrayContains: userId)
          .where('eventDate', isLessThan: pastThreshold)
          .get();

      for (var doc in collaboratorSnapshot.docs) {
        final eventData = doc.data();
        final eventStatus = eventData['eventStatus'] ?? 'Pending';
        final eventName = eventData['eventName'] ?? 'Unknown Event';

        if (eventStatus != 'Completed') {
          await _sendMissingEventNotification(
            userId: userId,
            eventName: eventName,
            eventId: doc.id,
            isOwner: false,
          );
          debugPrint('Missing event notification sent: $eventName (Collaborator)');
        }
      }
    } catch (e) {
      debugPrint('Error checking missing past events: $e');
    }
  }

  Future<void> _sendMissingEventNotification({
    required String userId,
    required String eventName,
    required String eventId,
    required bool isOwner,
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;

      await _firestore.collection('notifications').doc(notificationId).set({
        'notificationId': notificationId,
        'userId': userId,
        'title': 'Event Missing',
        'message': '"$eventName" has passed without being marked as completed',
        'type': 'event',
        'relatedId': eventId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Missing event notification created: $eventName for $userId');
    } catch (e) {
      debugPrint('Error sending missing event notification: $e');
    }
  }

  Future<void> _sendCollaboratorInviteNotification({
    required String userId,
    required String eventName,
    required String eventId,
    required String inviterUsername,
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;

      await _firestore.collection('notifications').doc(notificationId).set({
        'notificationId': notificationId,
        'userId': userId,
        'title': 'Collaborator Invite',
        'message': '$inviterUsername invited you as collaborator to "$eventName"',
        'type': 'event',
        'relatedId': eventId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Collaborator invite notification sent to $userId');
    } catch (e) {
      debugPrint('Error sending collaborator invite notification: $e');
    }
  }

  String formatTimeRemaining(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.isNegative) {
      return ' Event has ended';
    }

    if (difference.inDays > 0) {
      return ' In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return ' In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return ' In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return ' Starting now!';
    }
  }

  bool isPastEvent(DateTime eventDate) {
    return eventDate.isBefore(DateTime.now());
  }

  bool isEventCompleted(String eventStatus) {
    return eventStatus == 'Completed';
  }
}