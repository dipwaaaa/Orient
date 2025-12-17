import 'package:cloud_firestore/cloud_firestore.dart';
import 'budget_model.dart';

class VendorModel {
  final String vendorId;
  final String eventId;
  final String vendorName;
  final String category;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final String? address;
  final double totalCost;
  final double paidAmount;
  final double pendingAmount;
  final String agreementStatus; // accepted/pending/rejected
  final bool? addToBudget;
  final String? linkedBudgetId;
  final String? note;
  final List<PaymentRecord> payments;
  final String? listName;
  final String createdBy;
  final DateTime createdAt;
  final DateTime lastUpdated;

  VendorModel({
    required this.vendorId,
    required this.eventId,
    required this.vendorName,
    required this.category,
    this.phoneNumber,
    this.email,
    this.website,
    this.address,
    required this.totalCost,
    required this.paidAmount,
    required this.pendingAmount,
    required this.agreementStatus,
    required this.addToBudget,
    this.linkedBudgetId,
    this.note,
    required this.payments,
    this.listName,
    required this.createdBy,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'eventId': eventId,
      'vendorName': vendorName,
      'category': category,
      'phoneNumber': phoneNumber,
      'email': email,
      'website': website,
      'address': address,
      'totalCost': totalCost,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'agreementStatus': agreementStatus,
      'addToBudget': addToBudget,
      'linkedBudgetId': linkedBudgetId,
      'note': note,
      'payments': payments.map((p) => p.toMap()).toList(),
      'listName': listName,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory VendorModel.fromMap(Map<String, dynamic> map) {
    return VendorModel(
      vendorId: map['vendorId'] ?? '',
      eventId: map['eventId'] ?? '',
      vendorName: map['vendorName'] ?? '',
      category: map['category'] ?? '',
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      website: map['website'],
      address: map['address'],
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      pendingAmount: (map['pendingAmount'] ?? 0).toDouble(),
      agreementStatus: map['agreementStatus'] ?? 'pending',
      addToBudget: map['addToBudget'] ?? false,
      linkedBudgetId: map['linkedBudgetId'],
      note: map['note'],
      payments: (map['payments'] as List?)
          ?.map((p) => PaymentRecord.fromMap(p))
          .toList() ?? [],
      listName: map['listName'],
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }
}