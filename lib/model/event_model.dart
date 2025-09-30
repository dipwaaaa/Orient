import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final String eventType;
  final String description;
  final String ownerId;
  final List<String> collaborators;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.eventType,
    required this.description,
    required this.ownerId,
    required this.collaborators,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventType': eventType,
      'description': description,
      'ownerId': ownerId,
      'collaborators': collaborators,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      eventId: map['eventId'] ?? '',
      eventName: map['eventName'] ?? '',
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      eventType: map['eventType'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      collaborators: List<String>.from(map['collaborators'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}