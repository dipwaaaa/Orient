import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new budget
  Future<Map<String, dynamic>> createBudget({
    required String eventId,
    required String itemName,
    required String category,
    required double totalCost,
    String? note,
  }) async {
    try {
      final budgetId = _firestore.collection('budgets').doc().id;
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
        payments: [],
        lastUpdated: now,
        createdAt: now,
      );

      await _firestore.collection('budgets').doc(budgetId).set(budget.toMap());

      return {
        'success': true,
        'message': 'Budget created successfully',
        'budgetId': budgetId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create budget: $e',
      };
    }
  }

  // Get all budgets for an event
  Stream<List<BudgetModel>> getBudgetsByEvent(String eventId) {
    return _firestore
        .collection('budgets')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BudgetModel.fromMap(doc.data());
      }).toList();
    });
  }

  // Get single budget
  Future<BudgetModel?> getBudget(String budgetId) async {
    try {
      final doc = await _firestore.collection('budgets').doc(budgetId).get();
      if (doc.exists) {
        return BudgetModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting budget: $e');
      return null;
    }
  }

  // Update budget
  Future<Map<String, dynamic>> updateBudget({
    required String budgetId,
    String? itemName,
    String? category,
    double? totalCost,
    String? note,
    DateTime? dueDate,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      };

      if (itemName != null) updates['itemName'] = itemName;
      if (category != null) updates['category'] = category;
      if (note != null) updates['note'] = note;
      if (dueDate != null) updates['createdAt'] = Timestamp.fromDate(dueDate);

      if (totalCost != null) {
        // Get current budget to recalculate unpaid amount
        final budget = await getBudget(budgetId);
        if (budget != null) {
          final newUnpaid = totalCost - budget.paidAmount;
          updates['totalCost'] = totalCost;
          updates['unpaidAmount'] = newUnpaid;
        }
      }

      await _firestore.collection('budgets').doc(budgetId).update(updates);

      return {
        'success': true,
        'message': 'Budget updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update budget: $e',
      };
    }
  }

  // Add payment to budget
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
      final newUnpaidAmount = budget.totalCost - newPaidAmount;

      await _firestore.collection('budgets').doc(budgetId).update({
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
      return {
        'success': false,
        'error': 'Failed to add payment: $e',
      };
    }
  }

  // Update payment
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

      // Find and update the payment
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

      // Recalculate amounts
      final newPaidAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
      final newUnpaidAmount = budget.totalCost - newPaidAmount;

      await _firestore.collection('budgets').doc(budgetId).update({
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
      return {
        'success': false,
        'error': 'Failed to update payment: $e',
      };
    }
  }

  // Delete payment
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

      final payments = budget.payments.where((p) => p.paymentId != paymentId).toList();

      // Recalculate amounts
      final newPaidAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
      final newUnpaidAmount = budget.totalCost - newPaidAmount;

      await _firestore.collection('budgets').doc(budgetId).update({
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
      return {
        'success': false,
        'error': 'Failed to delete payment: $e',
      };
    }
  }

  // Delete budget
  Future<Map<String, dynamic>> deleteBudget(String budgetId) async {
    try {
      await _firestore.collection('budgets').doc(budgetId).delete();

      return {
        'success': true,
        'message': 'Budget deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to delete budget: $e',
      };
    }
  }

  // Get budget summary for an event
  Future<Map<String, double>> getBudgetSummary(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('budgets')
          .where('eventId', isEqualTo: eventId)
          .get();

      double totalBudget = 0;
      double totalPaid = 0;
      double totalUnpaid = 0;

      for (var doc in snapshot.docs) {
        final budget = BudgetModel.fromMap(doc.data());
        totalBudget += budget.totalCost;
        totalPaid += budget.paidAmount;
        totalUnpaid += budget.unpaidAmount;
      }

      return {
        'totalBudget': totalBudget,
        'totalPaid': totalPaid,
        'totalUnpaid': totalUnpaid,
        'remainingBalance': totalBudget - totalPaid,
      };
    } catch (e) {
      print('Error getting budget summary: $e');
      return {
        'totalBudget': 0,
        'totalPaid': 0,
        'totalUnpaid': 0,
        'remainingBalance': 0,
      };
    }
  }
}