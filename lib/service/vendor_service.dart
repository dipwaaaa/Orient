// File: service/vendor_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../model/vendor_model.dart';
import '../model/budget_model.dart';
import 'budget_service.dart';

class VendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BudgetService _budgetService = BudgetService();

  // ============= VENDOR CREATION & MANAGEMENT =============

  /// Create new vendor
  Future<Map<String, dynamic>> createVendor({
    required String eventId,
    required String vendorName,
    required String category,
    required double totalCost,
    String? phoneNumber,
    String? email,
    String? website,
    String? address,
    String? note,
    String? listName,
    required String createdBy,
  }) async {
    try {
      final vendorId = _firestore.collection('vendors').doc().id;
      final now = DateTime.now();

      final vendor = VendorModel(
        vendorId: vendorId,
        eventId: eventId,
        vendorName: vendorName,
        category: category,
        phoneNumber: phoneNumber,
        email: email,
        website: website,
        address: address,
        totalCost: totalCost,
        paidAmount: 0,
        pendingAmount: totalCost,
        agreementStatus: 'pending',
        addToBudget: false,
        note: note,
        payments: [],
        listName: listName,
        createdBy: createdBy,
        createdAt: now,
        lastUpdated: now,
      );

      // Save vendor di subcollection event
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .doc(vendorId)
          .set(vendor.toMap());

      return {
        'success': true,
        'message': 'Vendor created successfully',
        'vendorId': vendorId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create vendor: $e',
      };
    }
  }

  /// Get all vendors for an event
  Stream<List<VendorModel>> getVendorsByEvent(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('vendors')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['vendorId'] = doc.id;
        return VendorModel.fromMap(data);
      }).toList();
    });
  }

  /// Get single vendor
  Future<VendorModel?> getVendor({
    required String eventId,
    required String vendorId,
  }) async {
    try {
      final doc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .doc(vendorId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['vendorId'] = doc.id;
        return VendorModel.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting vendor: $e');
      return null;
    }
  }

  /// Update vendor details
  Future<Map<String, dynamic>> updateVendor({
    required String eventId,
    required String vendorId,
    String? vendorName,
    String? category,
    String? phoneNumber,
    String? email,
    String? website,
    String? address,
    String? note,
    double? totalCost,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      };

      if (vendorName != null) updates['vendorName'] = vendorName;
      if (category != null) updates['category'] = category;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (email != null) updates['email'] = email;
      if (website != null) updates['website'] = website;
      if (address != null) updates['address'] = address;
      if (note != null) updates['note'] = note;

      // Jika totalCost berubah, update pending amount juga
      if (totalCost != null) {
        final vendor = await getVendor(
          eventId: eventId,
          vendorId: vendorId,
        );
        if (vendor != null) {
          final newPendingAmount = totalCost - vendor.paidAmount;
          updates['totalCost'] = totalCost;
          updates['pendingAmount'] = newPendingAmount;
        }
      }

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .doc(vendorId)
          .update(updates);

      return {
        'success': true,
        'message': 'Vendor updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update vendor: $e',
      };
    }
  }

  // ============= VENDOR-BUDGET LINKING =============

  /// Toggle vendor add to budget flag
  /// Ketika checkbox "Add to Budget" diaktifkan/dinonaktifkan
  Future<Map<String, dynamic>> toggleAddToBudget({
    required String eventId,
    required String vendorId,
    required String budgetId,
    required bool addToBudget,
  }) async {
    try {
      final vendor = await getVendor(
        eventId: eventId,
        vendorId: vendorId,
      );

      if (vendor == null) {
        return {
          'success': false,
          'error': 'Vendor not found',
        };
      }

      if (addToBudget) {
        // Add vendor to budget
        final result = await _budgetService.addLinkedVendor(
          budgetId: budgetId,
          vendorId: vendorId,
          vendorName: vendor.vendorName,
          vendorCategory: vendor.category,
          contribution: vendor.totalCost,
        );

        if (result['success'] != true) {
          return result;
        }

        // Update vendor flag
        await _firestore
            .collection('events')
            .doc(eventId)
            .collection('vendors')
            .doc(vendorId)
            .update({
          'addToBudget': true,
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
        });

        return {
          'success': true,
          'message': 'Vendor added to budget',
        };
      } else {
        // Remove vendor from budget
        final result = await _budgetService.removeLinkedVendor(
          budgetId: budgetId,
          vendorId: vendorId,
        );

        if (result['success'] != true) {
          return result;
        }

        // Update vendor flag
        await _firestore
            .collection('events')
            .doc(eventId)
            .collection('vendors')
            .doc(vendorId)
            .update({
          'addToBudget': false,
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
        });

        return {
          'success': true,
          'message': 'Vendor removed from budget',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to toggle vendor budget status: $e',
      };
    }
  }

  /// Update vendor contribution to budget
  /// Called when vendor cost changes while linked to budget
  Future<Map<String, dynamic>> updateVendorContribution({
    required String eventId,
    required String vendorId,
    required String budgetId,
    required double newTotalCost,
  }) async {
    try {
      final vendor = await getVendor(
        eventId: eventId,
        vendorId: vendorId,
      );

      // ✅ FIX: Check null first!
      if (vendor == null) {
        return {
          'success': false,
          'error': 'Vendor not found',
        };
      }

      // ✅ FIX: Now safe to check addToBudget (vendor guaranteed non-null)
      final isLinked = vendor.addToBudget ?? false;
      if (!isLinked) {
        return {
          'success': false,
          'error': 'Vendor is not linked to budget',
        };
      }

      // Update vendor cost
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .doc(vendorId)
          .update({
        'totalCost': newTotalCost,
        'pendingAmount': newTotalCost - vendor.paidAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      // Update vendor contribution in budget
      final result = await _budgetService.updateVendorContribution(
        budgetId: budgetId,
        vendorId: vendorId,
        newContribution: newTotalCost,
      );

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update vendor contribution: $e',
      };
    }
  }

  // ============= VENDOR PAYMENT MANAGEMENT =============

  /// Add payment to vendor
  Future<Map<String, dynamic>> addVendorPayment({
    required String eventId,
    required String vendorId,
    required double amount,
    DateTime? paymentDate,
    String? note,
  }) async {
    try {
      final vendor = await getVendor(
        eventId: eventId,
        vendorId: vendorId,
      );

      // ✅ FIX: Check null first!
      if (vendor == null) {
        return {
          'success': false,
          'error': 'Vendor not found',
        };
      }

      // ✅ FIX: Now safe to use vendor (guaranteed non-null)
      final paymentId =
          _firestore.collection('events').doc(eventId).collection('vendors').doc().id;
      final now = paymentDate ?? DateTime.now();

      final payment = PaymentRecord(
        paymentId: paymentId,
        amount: amount,
        date: now,
        note: note,
      );

      final updatedPayments = [...vendor.payments, payment];
      final newPaidAmount =
      updatedPayments.fold<double>(0, (sum, p) => sum + p.amount);
      final newPendingAmount = vendor.totalCost - newPaidAmount;

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .doc(vendorId)
          .update({
        'payments': updatedPayments.map((p) => p.toMap()).toList(),
        'paidAmount': newPaidAmount,
        'pendingAmount': newPendingAmount,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Payment recorded successfully',
        'paymentId': paymentId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to add payment: $e',
      };
    }
  }

  /// Delete vendor
  Future<Map<String, dynamic>> deleteVendor({
    required String eventId,
    required String vendorId,
  }) async {
    try {
      final vendor = await getVendor(
        eventId: eventId,
        vendorId: vendorId,
      );

      // ✅ FIX: Check null first!
      if (vendor == null) {
        return {
          'success': false,
          'error': 'Vendor not found',
        };
      }

      // ✅ FIX: Now safe to check addToBudget (vendor guaranteed non-null)
      final isLinked = vendor.addToBudget ?? false;
      if (isLinked) {
        debugPrint('Vendor is linked to budget. Consider removing link first.');
      }

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .doc(vendorId)
          .delete();

      return {
        'success': true,
        'message': 'Vendor deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to delete vendor: $e',
      };
    }
  }

  // ============= VENDOR SUMMARY & QUERIES =============

  /// Get vendor summary for event
  Future<Map<String, dynamic>> getVendorSummary(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .get();

      double totalVendorCost = 0;
      double totalPaidToVendors = 0;
      int vendorCount = 0;
      int linkedVendorCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['vendorId'] = doc.id;
        final vendor = VendorModel.fromMap(data);

        totalVendorCost += vendor.totalCost;
        totalPaidToVendors += vendor.paidAmount;
        vendorCount++;

        // ✅ Use null coalescing operator (??) for safe condition check
        if (vendor.addToBudget ?? false) {
          linkedVendorCount++;
        }
      }

      return {
        'totalVendorCost': totalVendorCost,
        'totalPaidToVendors': totalPaidToVendors,
        'totalPendingFromVendors': totalVendorCost - totalPaidToVendors,
        'vendorCount': vendorCount,
        'linkedVendorCount': linkedVendorCount,
      };
    } catch (e) {
      debugPrint('Error getting vendor summary: $e');
      return {
        'totalVendorCost': 0,
        'totalPaidToVendors': 0,
        'totalPendingFromVendors': 0,
        'vendorCount': 0,
        'linkedVendorCount': 0,
      };
    }
  }

  /// Get vendors linked to budget
  Future<List<VendorModel>> getLinkedVendorsByBudget({
    required String eventId,
    required String budgetId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('vendors')
          .where('addToBudget', isEqualTo: true)
          .get();

      List<VendorModel> linkedVendors = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['vendorId'] = doc.id;
        linkedVendors.add(VendorModel.fromMap(data));
      }

      return linkedVendors;
    } catch (e) {
      debugPrint('Error getting linked vendors: $e');
      return [];
    }
  }
}