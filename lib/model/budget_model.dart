import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecord {
  final String paymentId;
  final double amount;
  final DateTime date;
  final String? note;

  PaymentRecord({
    required this.paymentId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      paymentId: map['paymentId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
    );
  }
}

class BudgetModel {
  final String budgetId;
  final String eventId;
  final String itemName;
  final String category;
  final double totalCost;
  final double paidAmount;
  final double unpaidAmount;
  final String? note;
  final List<String>? imageUrls;
  final List<PaymentRecord> payments;
  final DateTime lastUpdated;
  final DateTime createdAt;

  BudgetModel({
    required this.budgetId,
    required this.eventId,
    required this.itemName,
    required this.category,
    required this.totalCost,
    required this.paidAmount,
    required this.unpaidAmount,
    this.note,
    this.imageUrls,
    required this.payments,
    required this.lastUpdated,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'eventId': eventId,
      'itemName': itemName,
      'category': category,
      'totalCost': totalCost,
      'paidAmount': paidAmount,
      'unpaidAmount': unpaidAmount,
      'note': note,
      'imageUrls': imageUrls,
      'payments': payments.map((p) => p.toMap()).toList(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      budgetId: map['budgetId'] ?? '',
      eventId: map['eventId'] ?? '',
      itemName: map['itemName'] ?? '',
      category: map['category'] ?? '',
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      unpaidAmount: (map['unpaidAmount'] ?? 0).toDouble(),
      note: map['note'],
      imageUrls: map['imageUrls'] != null ? List<String>.from(map['imageUrls']) : null,
      payments: (map['payments'] as List?)
          ?.map((p) => PaymentRecord.fromMap(p))
          .toList() ??
          [],
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}