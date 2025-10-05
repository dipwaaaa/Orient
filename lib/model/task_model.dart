import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String taskId;
  final String eventId;
  final String name;
  final String category;
  final DateTime dueDate;
  final String status;
  final String? note;
  final double? budget; // TAMBAHKAN INI
  final List<String>? imageUrls;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.taskId,
    required this.eventId,
    required this.name,
    required this.category,
    required this.dueDate,
    required this.status,
    this.note,
    this.budget, // TAMBAHKAN INI
    this.imageUrls,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'eventId': eventId,
      'name': name,
      'category': category,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'note': note,
      'budget': budget, // TAMBAHKAN INI
      'imageUrls': imageUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      taskId: map['taskId'] ?? '',
      eventId: map['eventId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      note: map['note'],
      budget: map['budget']?.toDouble(), // TAMBAHKAN INI
      imageUrls: map['imageUrls'] != null ? List<String>.from(map['imageUrls']) : null,
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}