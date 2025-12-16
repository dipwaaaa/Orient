import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../model/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============= BUDGET CREATION & MANAGEMENT =============

  /// ✅ Create new budget - FIXED to save in events/{eventId}/budgets/
  Future<Map<String, dynamic>> createBudget({
    required String eventId,
    required String itemName,
    required String category,
    required double totalCost,
    String? note,
  }) async {
    try {
      // ✅ FIXED: Generate ID from dummy collection
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
        linkedVendors: [], // NEW - empty initially
        payments: [],
        lastUpdated: now,
        createdAt: now,
      );

      // ✅ FIXED: Save to events/{eventId}/budgets/{budgetId}
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

  /// ✅ Get all budgets for an event - FIXED path
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

  /// Get single budget
  Future<BudgetModel?> getBudget(String budgetId) async {
    try {
      // This requires eventId - need to refactor
      // For now, search in all events
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

  /// Update budget - FIXED path
  Future<Map<String, dynamic>> updateBudget({
    required String budgetId,
    String? itemName,
    String? category,
    double? totalCost,
    String? note,
    DateTime? dueDate,
  }) async {
    try {
      // Get budget first to find eventId
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

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  // ============= VENDOR LINKING OPERATIONS =============

  /// Add vendor to budget (create link di Firestore)
  /// Ini dipanggil dari VendorService setelah vendor update
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

      // Check duplicate
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

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Remove vendor from budget
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

      // Find vendor contribution
      final vendorToRemove = budget.linkedVendors
          .firstWhere((v) => v.vendorId == vendorId);
      final updatedLinkedVendors = budget.linkedVendors
          .where((v) => v.vendorId != vendorId)
          .toList();

      // Recalculate unpaid amount
      final newTotalCost = budget.totalCost +
          updatedLinkedVendors.fold(
              0, (sum, v) => (sum as double) + v.contribution);
      final newUnpaidAmount = newTotalCost - budget.paidAmount;

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Update vendor contribution amount di budget
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

      // Find dan update vendor contribution
      final updatedLinkedVendors = budget.linkedVendors.map((v) {
        if (v.vendorId == vendorId) {
          return v.copyWith(contribution: newContribution);
        }
        return v;
      }).toList();

      // Recalculate unpaid amount
      final newTotalCost = budget.totalCost +
          updatedLinkedVendors.fold(
              0, (sum, v) => (sum as double) + v.contribution);
      final newUnpaidAmount = newTotalCost - budget.paidAmount;

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Get all linked vendors untuk budget
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

  // ============= PAYMENT MANAGEMENT =============

  /// Add payment to budget
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

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Update payment
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
      payments.fold<double>(0, (sum, p) => sum + p.amount);
      final newUnpaidAmount =
          budget.calculateTotalWithVendors() - newPaidAmount;

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Update a payment at a specific index in the payments array
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

      final newPaidAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
      final newUnpaidAmount = budget.calculateTotalWithVendors() - newPaidAmount;

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Delete payment at specific index
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

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  /// Delete payment
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
      payments.fold<double>(0, (sum, p) => sum + p.amount);
      final newUnpaidAmount =
          budget.calculateTotalWithVendors() - newPaidAmount;

      // ✅ FIXED: Update path is events/{eventId}/budgets/{budgetId}
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

  // ============= BUDGET SUMMARY & DELETION =============

  /// Delete budget
  Future<Map<String, dynamic>> deleteBudget({
    required String eventId,
    required String budgetId,
  }) async {
    try {
      // ✅ FIXED: Delete path is events/{eventId}/budgets/{budgetId}
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

  /// Get budget summary untuk event (Future - one-time load)
  /// Includes linked vendors dalam calculation
  Future<Map<String, double>> getBudgetSummary(String eventId) async {
    try {
      // ✅ FIXED: Query from events/{eventId}/budgets/
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

  /// ✅ NEW: Get budget summary as STREAM (Real-time updates!)
  /// Emits new data whenever any budget changes
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

  /// Get budget breakdown untuk display
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