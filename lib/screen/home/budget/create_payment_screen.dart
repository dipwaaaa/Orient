import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/animated_gradient_background.dart';

class CreatePaymentScreen extends StatefulWidget {
  final String budgetId;
  final String budgetName;

  const CreatePaymentScreen({
    super.key,
    required this.budgetId,
    required this.budgetName,
  });

  @override
  State<CreatePaymentScreen> createState() => _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends State<CreatePaymentScreen> {
  final BudgetService _budgetService = BudgetService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedStatus = 'Paid';
  bool _isLoading = false;
  BudgetModel? _budget;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    final budget = await _budgetService.getBudget(widget.budgetId);
    if (budget != null && mounted) {
      setState(() => _budget = budget);
    }
  }

  Future<void> _createPayment() async {
    if (_amountController.text.trim().isEmpty) {
      _showSnackBar('Please enter payment amount', Colors.red);
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select payment date', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      ) ?? 0;

      if (amount <= 0) {
        _showSnackBar('Please enter a valid amount', Colors.red);
        return;
      }

      if (_budget != null && amount > _budget!.unpaidAmount) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Payment'),
            content: Text('Payment amount exceeds unpaid amount. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFE100),
                ),
                child: Text('Continue', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      final result = await _budgetService.addPayment(
        budgetId: widget.budgetId,
        amount: amount,
        date: _selectedDate!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        if (result['success']) {
          _showSnackBar('Payment created successfully', Colors.green);
          Future.delayed(Duration(seconds: 1), () {
            Navigator.pop(context, true);
          });
        } else {
          _showSnackBar(result['error'], Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar('Error creating payment', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

    return Scaffold(
      backgroundColor: Colors.white,
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
                      Expanded(
                        child: Center(
                          child: Text(
                            'Create a Payment',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: AppResponsive.responsiveFont(25),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : _createPayment,
                        child: Container(
                          width: AppResponsive.responsiveSize(0.122),
                          height: AppResponsive.responsiveSize(0.122),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: AppResponsive.responsiveIconSize(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.responsivePadding() * 2,
                      vertical: AppResponsive.spacingMedium(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormField(
                          label: 'Name',
                          controller: _nameController,
                          hintText: 'Type here',
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildDateField(),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildFormField(
                          label: 'Budget',
                          controller: TextEditingController(text: widget.budgetName),
                          hintText: 'Type here',
                          enabled: false,
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildFormField(
                          label: 'Amount',
                          controller: _amountController,
                          prefix: 'Rp ',
                          hintText: 'Type here',
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildFormField(
                          label: 'Note',
                          controller: _noteController,
                          hintText: 'Type here',
                          maxLines: 3,
                        ),
                        SizedBox(height: AppResponsive.spacingLarge()),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.responsivePadding() * 2,
                  vertical: AppResponsive.responsivePadding() * 2,
                ),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppResponsive.borderRadiusLarge() * 2),
                      topRight: Radius.circular(AppResponsive.borderRadiusLarge() * 2),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: AppResponsive.responsiveFont(14),
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: AppResponsive.spacingSmall()),
                            Wrap(
                              spacing: AppResponsive.spacingSmall(),
                              runSpacing: AppResponsive.spacingSmall(),
                              children: ['Paid', 'Pending'].map((status) {
                                final isSelected = _selectedStatus == status;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedStatus = status;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppResponsive.responsivePadding() * 1.5,
                                      vertical: AppResponsive.spacingSmall() * 0.8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFE100)
                                          : Colors.white,
                                      border: Border.all(
                                        width: 1,
                                        color: Colors.black,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: AppResponsive.responsiveFont(14),
                                        fontFamily: 'SF Pro',
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppResponsive.spacingSmall()),
                      Image.asset(
                        'assets/image/AddTaskImageCat.png',
                        height: AppResponsive.responsiveHeight(15),
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? hintText,
    int maxLines = 1,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.all(AppResponsive.responsivePadding()),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            minLines: maxLines == 1 ? 1 : 3,
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.responsiveFont(13),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                fontSize: AppResponsive.responsiveFont(13),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
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
            color: Colors.black,
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.all(AppResponsive.responsivePadding()),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.black
                          : const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                      fontSize: AppResponsive.responsiveFont(13),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: AppResponsive.responsiveIconSize(18),
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}