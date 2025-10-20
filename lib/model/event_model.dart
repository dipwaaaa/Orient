import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final String eventType;
  final String eventLocation;
  final String description;
  final String ownerId;
  final List<String> collaborators;
  final String eventStatus; // pending, ongoing, completed, cancelled
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.eventType,
    required this.eventLocation,
    required this.description,
    required this.ownerId,
    required this.collaborators,
    this.eventStatus = 'Pending', // Default value
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventType': eventType,
      'eventLocation': eventLocation,
      'description': description,
      'ownerId': ownerId,
      'collaborators': collaborators,
      'eventStatus': eventStatus,
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
      eventLocation: map['eventLocation'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      collaborators: List<String>.from(map['collaborators'] ?? []),
      eventStatus: map['eventStatus'] ?? 'Pending',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Helper method to create a new event with default values
  factory EventModel.create({
    required String eventName,
    required DateTime eventDate,
    required String eventType,
    required String eventLocation,
    required String description,
    required String ownerId,
    List<String>? collaborators,
  }) {
    final now = DateTime.now();
    return EventModel(
      eventId: '', // Will be set by Firestore
      eventName: eventName,
      eventDate: eventDate,
      eventType: eventType,
      eventLocation: eventLocation,
      description: description,
      ownerId: ownerId,
      collaborators: collaborators ?? [],
      eventStatus: 'Pending', // Always starts as Pending
      createdAt: now,
      updatedAt: now,
    );
  }

  // Helper method to copy with changes
  EventModel copyWith({
    String? eventId,
    String? eventName,
    DateTime? eventDate,
    String? eventType,
    String? eventLocation,
    String? description,
    String? ownerId,
    List<String>? collaborators,
    String? eventStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      eventType: eventType ?? this.eventType,
      eventLocation: eventLocation ?? this.eventLocation,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      collaborators: collaborators ?? this.collaborators,
      eventStatus: eventStatus ?? this.eventStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}