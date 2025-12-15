
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventInvitation {
  final String eventId;
  final String? tableName;
  final String? menu;
  final String invitationStatus; // sent/not_sent/pending/accepted/denied

  EventInvitation({
    required this.eventId,
    this.tableName,
    this.menu,
    required this.invitationStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'tableName': tableName,
      'menu': menu,
      'invitationStatus': invitationStatus,
    };
  }

  factory EventInvitation.fromMap(Map<String, dynamic> map) {
    return EventInvitation(
      eventId: map['eventId'] ?? '',
      tableName: map['tableName'],
      menu: map['menu'],
      invitationStatus: map['invitationStatus'] ?? 'not_sent',
    );
  }
}

class GuestModel {
  final String guestId;
  final String name;
  final String gender;
  final String ageStatus; // adult/child/baby
  final String group; // family/friend/vendor/speaker/etc
  final String? phoneNumber;
  final String? email;
  final String? address;
  final String? note;
  final String? status; //  Not Sent/Pending/Accepted/Rejected
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt; //  Track when guest was last updated
  final String? eventId; //  Link guest to specific event
  final List<EventInvitation> eventInvitations;

  GuestModel({
    required this.guestId,
    required this.name,
    required this.gender,
    required this.ageStatus,
    required this.group,
    this.phoneNumber,
    this.email,
    this.address,
    this.note,
    this.status = 'Pending', //  Default status
    required this.createdBy,
    required this.createdAt,
    this.updatedAt, //  Optional update timestamp
    this.eventId, //  Optional event ID
    required this.eventInvitations,
  });

  Map<String, dynamic> toMap() {
    return {
      'guestId': guestId,
      'name': name,
      'gender': gender,
      'ageStatus': ageStatus,
      'group': group,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'note': note,
      'status': status, //
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null, // ✨ NEW
      'eventId': eventId, //  Add eventId to map
      'eventInvitations': eventInvitations.map((e) => e.toMap()).toList(),
    };
  }

  factory GuestModel.fromMap(Map<String, dynamic> map) {
    return GuestModel(
      guestId: map['guestId'] ?? '',
      name: map['name'] ?? '',
      gender: map['gender'] ?? '',
      ageStatus: map['ageStatus'] ?? 'adult',
      group: map['group'] ?? '',
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      address: map['address'],
      note: map['note'],
      status: map['status'] ?? 'Pending', // Default to Pending if not set
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null, // ✨ NEW
      eventId: map['eventId'], // Get eventId from map
      eventInvitations: (map['eventInvitations'] as List?)
          ?.map((e) => EventInvitation.fromMap(e))
          .toList() ?? [],
    );
  }

  /// Helper method: Get status color
  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'not sent':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  ///  Helper method: Check if guest RSVP'd
  bool isConfirmed() {
    return status?.toLowerCase() == 'accepted';
  }

  /// Helper method: Check if guest declined
  bool isRejected() {
    return status?.toLowerCase() == 'rejected';
  }

  /// Helper method: Check if guest needs follow-up
  bool needsFollowUp() {
    return status?.toLowerCase() == 'pending' || status?.toLowerCase() == 'not sent';
  }
}