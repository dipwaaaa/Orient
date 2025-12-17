import 'package:cloud_firestore/cloud_firestore.dart';

class LinkedVendor {
  final String vendorId;
  final String vendorName;
  final String category;
  final double contribution;
  final DateTime linkedAt;

  LinkedVendor({
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.contribution,
    required this.linkedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'category': category,
      'contribution': contribution,
      'linkedAt': Timestamp.fromDate(linkedAt),
    };
  }

  factory LinkedVendor.fromMap(Map<String, dynamic> map) {
    return LinkedVendor(
      vendorId: map['vendorId'] ?? '',
      vendorName: map['vendorName'] ?? '',
      category: map['category'] ?? '',
      contribution: (map['contribution'] ?? 0).toDouble(),
      linkedAt: (map['linkedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  LinkedVendor copyWith({
    String? vendorId,
    String? vendorName,
    String? category,
    double? contribution,
    DateTime? linkedAt,
  }) {
    return LinkedVendor(
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      category: category ?? this.category,
      contribution: contribution ?? this.contribution,
      linkedAt: linkedAt ?? this.linkedAt,
    );
  }
}

class BudgetModel {
  final String budgetId;
  final String eventId;
  final String itemName;
  final String category;
  final double totalCost; // Base item cost
  final double paidAmount;
  final double unpaidAmount;
  final String? note;
  final List<LinkedVendor> linkedVendors; // NEW: Vendors linked to this budget
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
    required this.linkedVendors,
    required this.payments,
    required this.lastUpdated,
    required this.createdAt,
  });

  // Calculate total including linked vendors
  double calculateTotalWithVendors() {
    double vendorTotal = linkedVendors.fold(
      0,
          (sum, vendor) => sum + vendor.contribution,
    );
    return totalCost + vendorTotal;
  }

  // Get unpaid amount recalculated
  double getUnpaidAmount() {
    return calculateTotalWithVendors() - paidAmount;
  }

  // Check if budget is fully paid
  bool isPaid() {
    return getUnpaidAmount() <= 0;
  }

  // Get number of linked vendors
  int getLinkedVendorCount() {
    return linkedVendors.length;
  }

  // Get total vendor contribution
  double getTotalVendorContribution() {
    return linkedVendors.fold(0, (sum, vendor) => sum + vendor.contribution);
  }

  // Get breakdown of costs
  Map<String, double> getCostBreakdown() {
    return {
      'baseItem': totalCost,
      'vendors': getTotalVendorContribution(),
      'total': calculateTotalWithVendors(),
    };
  }

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
      'linkedVendors': linkedVendors.map((v) => v.toMap()).toList(), // NEW
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
      linkedVendors: (map['linkedVendors'] as List<dynamic>?)
          ?.map((v) => LinkedVendor.fromMap(v as Map<String, dynamic>))
          .toList() ??
          [], // NEW - default empty list
      payments: (map['payments'] as List<dynamic>?)
          ?.map((p) => PaymentRecord.fromMap(p as Map<String, dynamic>))
          .toList() ??
          [],
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  BudgetModel copyWith({
    String? budgetId,
    String? eventId,
    String? itemName,
    String? category,
    double? totalCost,
    double? paidAmount,
    double? unpaidAmount,
    String? note,
    List<LinkedVendor>? linkedVendors,
    List<PaymentRecord>? payments,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      budgetId: budgetId ?? this.budgetId,
      eventId: eventId ?? this.eventId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      totalCost: totalCost ?? this.totalCost,
      paidAmount: paidAmount ?? this.paidAmount,
      unpaidAmount: unpaidAmount ?? this.unpaidAmount,
      note: note ?? this.note,
      linkedVendors: linkedVendors ?? this.linkedVendors,
      payments: payments ?? this.payments,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

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
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'],
    );
  }
}