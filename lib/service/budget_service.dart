import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../model/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<Map<String, dynamic>> createBudget({
    required String eventId,
    required String itemName,
    required String category,
    required double totalCost,
    String? note,
  }) async {
    try {
      final budgetId = _firestore.collection('dummy').doc().id;
      final now = DateTime.now();

      final budget = BudgetModel(
        budgetId: budgetId,
        eventId: eventId,
        itemName: itemName,
        category: category,
        totalCost: totalCost,
        paidAmount: 0,
        unpaidAmount: totalCost,
        note: note,
        linkedVendors: [],
        payments: [],
        lastUpdated: now,
        createdAt: now,
      );


      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('budgets')
          .doc(budgetId)
          .set(budget.toMap());

      debugPrint('✅ Budget created at: events/$eventId/budgets/$budgetId');

      return {
        'success': true,
        'message': 'Budget created successfully',
        'budgetId': budgetId,
      };
    } catch (e) {
      debugPrint('❌ Error creating budget: $e');
      return {
        'success': false,
        'error': 'Failed to create budget: $e',
      };
    }
  }

  Stream<List<BudgetModel>> getBudgetsByEvent(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('budgets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('📊 Budgets found: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) {
        return BudgetModel.fromMap(doc.data());
      }).toList();
    });
  }


  Future<BudgetModel?> getBudget(String budgetId) async {
    try {
      final eventsSnapshot = await _firestore.collection('events').get();

      for (var eventDoc in eventsSnapshot.docs) {
        final budgetSnapshot = await eventDoc.reference
            .collection('budgets')
            .doc(budgetId)
            .get();

        if (budgetSnapshot.exists) {
          return BudgetModel.fromMap(budgetSnapshot.data()!);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting budget: $e');
      return null;
    }
  }


  Future<Map<String, dynamic>> updateBudget({
    required String budgetId,
    String? itemName,
    String? category,
    double? totalCost,
    String? note,
    DateTime? dueDate,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      final updates = <String, dynamic>{
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      };

      if (itemName != null) updates['itemName'] = itemName;
      if (category != null) updates['category'] = category;
      if (note != null) updates['note'] = note;
      if (dueDate != null) updates['createdAt'] = Timestamp.fromDate(dueDate);

      if (totalCost != null) {
        final newUnpaid = totalCost - budget.paidAmount;
        updates['totalCost'] = totalCost;
        updates['unpaidAmount'] = newUnpaid;
      }

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update(updates);

      return {
        'success': true,
        'message': 'Budget updated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error updating budget: $e');
      return {
        'success': false,
        'error': 'Failed to update budget: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addLinkedVendor({
    required String budgetId,
    required String vendorId,
    required String vendorName,
    required String vendorCategory,
    required double contribution,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      if (budget.linkedVendors.any((v) => v.vendorId == vendorId)) {
        return {
          'success': false,
          'error': 'Vendor sudah linked ke budget ini',
        };
      }

      final linkedVendor = LinkedVendor(
        vendorId: vendorId,
        vendorName: vendorName,
        category: vendorCategory,
        contribution: contribution,
        linkedAt: DateTime.now(),
      );

      final updatedLinkedVendors = [...budget.linkedVendors, linkedVendor];
      final newTotalCost = budget.calculateTotalWithVendors() + contribution;
      final newUnpaidAmount = newTotalCost - budget.paidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'linkedVendors': updatedLinkedVendors.map((v) => v.toMap()).toList(),
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('✅ Vendor $vendorId linked to budget $budgetId');

      return {
        'success': true,
        'message': 'Vendor added to budget',
      };
    } catch (e) {
      debugPrint('❌ Error adding vendor to budget: $e');
      return {
        'success': false,
        'error': 'Failed to add vendor to budget: $e',
      };
    }
  }

  Future<Map<String, dynamic>> removeLinkedVendor({
    required String budgetId,
    required String vendorId,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }


      final _ = budget.linkedVendors
          .firstWhere((v) => v.vendorId == vendorId);
      final updatedLinkedVendors = budget.linkedVendors
          .where((v) => v.vendorId != vendorId)
          .toList();

      final newTotalCost = budget.totalCost +
          updatedLinkedVendors.fold(
              0, (num sum, v) => (sum as double) + v.contribution);
      final newUnpaidAmount = newTotalCost - budget.paidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'linkedVendors': updatedLinkedVendors.map((v) => v.toMap()).toList(),
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('✅ Vendor $vendorId unlinked from budget $budgetId');

      return {
        'success': true,
        'message': 'Vendor removed from budget',
      };
    } catch (e) {
      debugPrint('❌ Error removing vendor from budget: $e');
      return {
        'success': false,
        'error': 'Failed to remove vendor: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateVendorContribution({
    required String budgetId,
    required String vendorId,
    required double newContribution,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      final updatedLinkedVendors = budget.linkedVendors.map((v) {
        if (v.vendorId == vendorId) {
          return v.copyWith(contribution: newContribution);
        }
        return v;
      }).toList();

      final newTotalCost = budget.totalCost +
          updatedLinkedVendors.fold(
              0, (num sum, v) => (sum as double) + v.contribution);
      final newUnpaidAmount = newTotalCost - budget.paidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'linkedVendors': updatedLinkedVendors.map((v) => v.toMap()).toList(),
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Vendor contribution updated',
      };
    } catch (e) {
      debugPrint('❌ Error updating contribution: $e');
      return {
        'success': false,
        'error': 'Failed to update contribution: $e',
      };
    }
  }

  Future<List<LinkedVendor>> getLinkedVendors(String budgetId) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return [];
      }
      return budget.linkedVendors;
    } catch (e) {
      debugPrint('Error getting linked vendors: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addPayment({
    required String budgetId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      final paymentId = '${budgetId}_${DateTime.now().millisecondsSinceEpoch}';
      final payment = PaymentRecord(
        paymentId: paymentId,
        amount: amount,
        date: date,
        note: note,
      );

      final newPaidAmount = budget.paidAmount + amount;
      final newUnpaidAmount = budget.calculateTotalWithVendors() - newPaidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'payments': FieldValue.arrayUnion([payment.toMap()]),
        'paidAmount': newPaidAmount,
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Payment added successfully',
      };
    } catch (e) {
      debugPrint('❌ Error adding payment: $e');
      return {
        'success': false,
        'error': 'Failed to add payment: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updatePayment({
    required String budgetId,
    required String paymentId,
    double? amount,
    DateTime? date,
    String? note,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      final payments = List<PaymentRecord>.from(budget.payments);
      final paymentIndex = payments.indexWhere((p) => p.paymentId == paymentId);

      if (paymentIndex == -1) {
        return {
          'success': false,
          'error': 'Payment not found',
        };
      }

      final oldPayment = payments[paymentIndex];
      final newPayment = PaymentRecord(
        paymentId: paymentId,
        amount: amount ?? oldPayment.amount,
        date: date ?? oldPayment.date,
        note: note ?? oldPayment.note,
      );

      payments[paymentIndex] = newPayment;

      final newPaidAmount =
      payments.fold<double>(0, (double sum, p) => sum + p.amount);
      final newUnpaidAmount =
          budget.calculateTotalWithVendors() - newPaidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'payments': payments.map((p) => p.toMap()).toList(),
        'paidAmount': newPaidAmount,
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Payment updated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error updating payment: $e');
      return {
        'success': false,
        'error': 'Failed to update payment: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updatePaymentAtIndex({
    required String budgetId,
    required int paymentIndex,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      if (paymentIndex < 0 || paymentIndex >= budget.payments.length) {
        return {
          'success': false,
          'error': 'Invalid payment index',
        };
      }

      final oldPayment = budget.payments[paymentIndex];
      final payments = List<PaymentRecord>.from(budget.payments);

      payments[paymentIndex] = PaymentRecord(
        paymentId: oldPayment.paymentId,
        amount: amount,
        date: date,
        note: note,
      );

      final newPaidAmount = payments.fold<double>(0, (double sum, p) => sum + p.amount);
      final newUnpaidAmount = budget.calculateTotalWithVendors() - newPaidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'payments': payments.map((p) => p.toMap()).toList(),
        'paidAmount': newPaidAmount,
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Payment updated successfully',
      };
    } catch (e) {
      debugPrint('❌ Error updating payment at index: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deletePaymentAtIndex({
    required String budgetId,
    required int paymentIndex,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      if (paymentIndex < 0 || paymentIndex >= budget.payments.length) {
        return {
          'success': false,
          'error': 'Invalid payment index',
        };
      }

      final payments = List<PaymentRecord>.from(budget.payments);
      final paymentToDelete = payments[paymentIndex];
      final amountToSubtract = paymentToDelete.amount;

      payments.removeAt(paymentIndex);

      final newPaidAmount = budget.paidAmount - amountToSubtract;
      final totalWithVendors = budget.calculateTotalWithVendors();
      final newUnpaidAmount = totalWithVendors - newPaidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'payments': payments.map((p) => p.toMap()).toList(),
        'paidAmount': newPaidAmount,
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Payment deleted successfully',
      };
    } catch (e) {
      debugPrint('❌ Error deleting payment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deletePayment({
    required String budgetId,
    required String paymentId,
  }) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {
          'success': false,
          'error': 'Budget not found',
        };
      }

      final payments =
      budget.payments.where((p) => p.paymentId != paymentId).toList();

      final newPaidAmount =
      payments.fold<double>(0, (double sum, p) => sum + p.amount);
      final newUnpaidAmount =
          budget.calculateTotalWithVendors() - newPaidAmount;

      await _firestore
          .collection('events')
          .doc(budget.eventId)
          .collection('budgets')
          .doc(budgetId)
          .update({
        'payments': payments.map((p) => p.toMap()).toList(),
        'paidAmount': newPaidAmount,
        'unpaidAmount': newUnpaidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Payment deleted successfully',
      };
    } catch (e) {
      debugPrint('❌ Error deleting payment: $e');
      return {
        'success': false,
        'error': 'Failed to delete payment: $e',
      };
    }
  }




  Future<Map<String, dynamic>> deleteBudget({
    required String eventId,
    required String budgetId,
  }) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('budgets')
          .doc(budgetId)
          .delete();

      debugPrint('✅ Budget $budgetId deleted');

      return {
        'success': true,
        'message': 'Budget deleted successfully',
      };
    } catch (e) {
      debugPrint('❌ Error deleting budget: $e');
      return {
        'success': false,
        'error': 'Failed to delete budget: $e',
      };
    }
  }

  Future<Map<String, double>> getBudgetSummary(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('budgets')
          .get();

      double totalBudgetWithVendors = 0;
      double totalPaid = 0;
      double totalUnpaid = 0;
      double totalVendorContribution = 0;

      for (var doc in snapshot.docs) {
        final budget = BudgetModel.fromMap(doc.data());
        final budgetTotal = budget.calculateTotalWithVendors();
        totalBudgetWithVendors += budgetTotal;
        totalPaid += budget.paidAmount;
        totalUnpaid += budget.getUnpaidAmount();
        totalVendorContribution += budget.getTotalVendorContribution();
      }

      return {
        'totalBudget': totalBudgetWithVendors,
        'totalPaid': totalPaid,
        'totalUnpaid': totalUnpaid,
        'remainingBalance': totalBudgetWithVendors - totalPaid,
        'totalVendorContribution': totalVendorContribution,
      };
    } catch (e) {
      debugPrint('❌ Error getting budget summary: $e');
      return {
        'totalBudget': 0,
        'totalPaid': 0,
        'totalUnpaid': 0,
        'remainingBalance': 0,
        'totalVendorContribution': 0,
      };
    }
  }

  Stream<Map<String, double>> getBudgetSummaryStream(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('budgets')
        .snapshots()
        .map((snapshot) {
      double totalBudgetWithVendors = 0;
      double totalPaid = 0;
      double totalUnpaid = 0;
      double totalVendorContribution = 0;

      for (var doc in snapshot.docs) {
        final budget = BudgetModel.fromMap(doc.data());
        final budgetTotal = budget.calculateTotalWithVendors();
        totalBudgetWithVendors += budgetTotal;
        totalPaid += budget.paidAmount;
        totalUnpaid += budget.getUnpaidAmount();
        totalVendorContribution += budget.getTotalVendorContribution();
      }

      debugPrint('📊 Budget summary stream updated:');
      debugPrint('   Total Budget: $totalBudgetWithVendors');
      debugPrint('   Total Paid: $totalPaid');
      debugPrint('   Total Unpaid: $totalUnpaid');
      debugPrint('   Remaining Balance: ${totalBudgetWithVendors - totalPaid}');

      return {
        'totalBudget': totalBudgetWithVendors,
        'totalPaid': totalPaid,
        'totalUnpaid': totalUnpaid,
        'remainingBalance': totalBudgetWithVendors - totalPaid,
        'totalVendorContribution': totalVendorContribution,
      };
    });
  }

  Future<Map<String, dynamic>> getBudgetBreakdown(String budgetId) async {
    try {
      final budget = await getBudget(budgetId);
      if (budget == null) {
        return {};
      }

      return {
        'budgetId': budgetId,
        'itemName': budget.itemName,
        'baseItemCost': budget.totalCost,
        'vendorContribution': budget.getTotalVendorContribution(),
        'totalCost': budget.calculateTotalWithVendors(),
        'paidAmount': budget.paidAmount,
        'unpaidAmount': budget.getUnpaidAmount(),
        'vendorCount': budget.getLinkedVendorCount(),
        'breakdown': budget.getCostBreakdown(),
      };
    } catch (e) {
      debugPrint('❌ Error getting budget breakdown: $e');
      return {};
    }
  }
}