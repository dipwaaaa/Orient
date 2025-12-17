import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/budget_model.dart' as budget_models;
import '../../../service/budget_service.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/Animated_Gradient_Background.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String budgetId;
  final budget_models.PaymentRecord payment;
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

    try {
      final amount = double.tryParse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      ) ?? 0;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

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
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.responsivePadding(),
                    vertical: AppResponsive.spacingSmall(),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: AppResponsive.responsiveSize(0.122),
                          height: AppResponsive.responsiveSize(0.122),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: AppResponsive.responsiveIconSize(24),
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
                height: AppResponsive.responsiveHeight(20),
                fit: BoxFit.contain,
              ),
              SizedBox(height: AppResponsive.spacingMedium()),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppResponsive.borderRadiusLarge() * 2),
                        topRight: Radius.circular(AppResponsive.borderRadiusLarge() * 2),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppResponsive.responsivePadding() * 2.2,
                      AppResponsive.responsivePadding() * 2.6,
                      AppResponsive.responsivePadding() * 2.2,
                      AppResponsive.spacingMedium(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Payment ${widget.paymentIndex + 1}',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: AppResponsive.responsiveFont(25),
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w700,
                                  height: 0.88,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: AppResponsive.spacingSmall()),
                            GestureDetector(
                              onTap: () {
                                if (_isEditMode) {
                                  _savePayment();
                                } else {
                                  setState(() => _isEditMode = true);
                                }
                              },
                              child: Container(
                                width: AppResponsive.responsiveSize(0.089),
                                height: AppResponsive.responsiveSize(0.089),
                                decoration: const ShapeDecoration(
                                  color: Color(0xFFFFE100),
                                  shape: OvalBorder(),
                                ),
                                child: Icon(
                                  _isEditMode ? Icons.check : Icons.edit,
                                  size: AppResponsive.responsiveIconSize(18),
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppResponsive.spacingLarge() * 2),
                        _buildFormField(
                          'Payment Name',
                          TextEditingController(text: 'Payment ${widget.paymentIndex + 1}'),
                          enabled: _isEditMode,
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildFormField(
                          'Amount',
                          _amountController,
                          enabled: _isEditMode,
                          prefix: 'Rp',
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildDateField(),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildFormField(
                          'Note',
                          _noteController,
                          enabled: _isEditMode,
                          maxLines: 2,
                        ),
                        SizedBox(height: AppResponsive.spacingLarge() * 2),
                        Text(
                          'Status',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: AppResponsive.responsiveFont(14),
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _isEditMode
                            ? Wrap(
                          spacing: AppResponsive.spacingMedium(),
                          runSpacing: AppResponsive.spacingMedium(),
                          children: ['Paid', 'Pending'].map((status) {
                            return _buildStatusButton(status);
                          }).toList(),
                        )
                            : Container(
                          height: AppResponsive.responsiveHeight(6.5),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                width: 2,
                                color: const Color(0xFFFFE100),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppResponsive.borderRadiusMedium(),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppResponsive.spacingSmall(),
                              vertical: AppResponsive.spacingSmall() * 0.5,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _selectedStatus,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: AppResponsive.responsiveFont(14),
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacingLarge()),
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
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          height: maxLines == 1 ? AppResponsive.responsiveHeight(6.5) : null,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 2,
                color: const Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadiusMedium(),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.spacingSmall(),
              vertical: AppResponsive.spacingSmall() * 0.5,
            ),
            child: Row(
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.responsiveFont(14),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: AppResponsive.spacingSmall() * 0.4),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    minLines: 1,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.responsiveFont(14),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Type here',
                      hintStyle: TextStyle(
                        color: const Color(0xFF1D1D1D),
                        fontSize: AppResponsive.responsiveFont(13),
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
        Text(
          'Date',
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        GestureDetector(
          onTap: _isEditMode ? _selectDate : null,
          child: Container(
            height: AppResponsive.responsiveHeight(6.5),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 2,
                  color: const Color(0xFFFFE100),
                ),
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadiusMedium(),
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.spacingSmall(),
                vertical: AppResponsive.spacingSmall() * 0.5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateController.text,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: AppResponsive.responsiveFont(14),
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today,
                    size: AppResponsive.responsiveIconSize(16),
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
        height: AppResponsive.responsiveHeight(5.5),
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.responsivePadding() * 1.5,
          vertical: AppResponsive.spacingSmall() * 0.6,
        ),
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
              fontSize: AppResponsive.responsiveFont(14),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}