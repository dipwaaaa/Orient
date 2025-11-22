import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String budgetId;
  final PaymentRecord payment;
  final int paymentIndex;

  const PaymentDetailScreen({
    super.key,
    required this.budgetId,
    required this.payment,
    required this.paymentIndex,
  });

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final BudgetService _budgetService = BudgetService();

  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _noteController;
  String _selectedStatus = 'Paid';
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: NumberFormat('#,###', 'id_ID').format(widget.payment.amount),
    );
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(widget.payment.date),
    );
    _noteController = TextEditingController(text: widget.payment.note ?? '');
    _selectedStatus = 'Paid';
    _selectedDate = widget.payment.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFE100),
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _savePayment() async {
    if (_amountController.text.trim().isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      ) ?? 0;

      // Use updatePaymentAtIndex to update at specific index
      final result = await _budgetService.updatePaymentAtIndex(
        budgetId: widget.budgetId,
        paymentIndex: widget.paymentIndex,
        amount: amount,
        date: _selectedDate!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Error updating payment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedGradientBackground(),
          ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ),
              Image.asset(
                'assets/image/bored.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 15),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(45, 43, 45, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment ${widget.paymentIndex + 1}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 25,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w700,
                                height: 0.88,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_isEditMode) {
                                  _savePayment();
                                } else {
                                  setState(() => _isEditMode = true);
                                }
                              },
                              child: Container(
                                width: 31,
                                height: 31,
                                decoration: const ShapeDecoration(
                                  color: Color(0xFFFFE100),
                                  shape: OvalBorder(),
                                ),
                                child: Icon(
                                  _isEditMode ? Icons.check : Icons.edit,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Payment Name - editable when in edit mode
                        _buildFormField(
                          'Payment Name',
                          TextEditingController(text: 'Payment ${widget.paymentIndex + 1}'),
                          enabled: _isEditMode,
                        ),
                        const SizedBox(height: 12),
                        // Amount
                        _buildFormField(
                          'Amount',
                          _amountController,
                          enabled: _isEditMode,
                          prefix: 'Rp',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        // Date
                        _buildDateField(),
                        const SizedBox(height: 12),
                        // Note
                        _buildFormField(
                          'Note',
                          _noteController,
                          enabled: _isEditMode,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 28),
                        // Status Section
                        Text(
                          'Status',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _isEditMode
                            ? Row(
                          children: [
                            Expanded(
                              child: _buildStatusButton('Paid'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatusButton('Pending'),
                            ),
                          ],
                        )
                            : Container(
                          height: 48,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 2,
                                color: Color(0xFFFFE100),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _selectedStatus,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
      String label,
      TextEditingController controller, {
        bool enabled = false,
        String? prefix,
        TextInputType? keyboardType,
        int maxLines = 1,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: maxLines == 1 ? 48 : null,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 2,
                color: Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Type here',
                      hintStyle: TextStyle(
                        color: Color(0xFF1D1D1D),
                        fontSize: 13,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: _isEditMode ? _selectDate : null,
          child: Container(
            height: 48,
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 2,
                  color: Color(0xFFFFE100),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateController.text,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(String status) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFFFFE100) : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 2,
              color: isSelected ? const Color(0xFFFFE100) : Colors.black,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Center(
          child: Text(
            status,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.black,
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}