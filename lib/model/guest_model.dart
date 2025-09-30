import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String createdBy;
  final DateTime createdAt;
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
    required this.createdBy,
    required this.createdAt,
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
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
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
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      eventInvitations: (map['eventInvitations'] as List?)
          ?.map((e) => EventInvitation.fromMap(e))
          .toList() ?? [],
    );
  }
}