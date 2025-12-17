import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../widget/animated_gradient_background.dart';
import '../../../utilty/app_responsive.dart';
import 'create_payment_screen.dart';
import 'payment_detail_screen.dart';

class BudgetDetailScreen extends StatefulWidget {
  final String eventId;
  final String budgetId;

  const BudgetDetailScreen({
    super.key,
    required this.eventId,
    required this.budgetId,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final BudgetService _budgetService = BudgetService();

  int _selectedTabIndex = 0;
  bool _isEditMode = false;
  BudgetModel? _budget;
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _selectedCategory = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    final budget = await _budgetService.getBudget(widget.budgetId);
    if (budget != null && mounted) {
      setState(() {
        _budget = budget;
        _nameController.text = budget.itemName;
        _budgetController.text = budget.totalCost.toStringAsFixed(0);
        _noteController.text = budget.note ?? '';
        _selectedCategory = budget.category;
        _selectedDate = budget.createdAt;
        _dateController.text = DateFormat('dd/MM/yyyy').format(budget.createdAt);
        _isLoading = false;
      });
    }
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

  Future<void> _saveChanges() async {
    if (_budget == null) return;

    setState(() {
      _isLoading = true;
    });

    final budget = double.tryParse(
      _budgetController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    ) ??
        _budget!.totalCost;

    final result = await _budgetService.updateBudget(
      budgetId: widget.budgetId,
      itemName: _nameController.text.trim(),
      category: _selectedCategory,
      totalCost: budget,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      dueDate: _selectedDate,
    );

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditMode = false;
        });
        await _loadBudget();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

    if (_isLoading || _budget == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
          ),
        ),
      );
    }

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
                    vertical: AppResponsive.spacingMedium(),
                  ),
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
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: AppResponsive.responsiveIconSize(24),
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabButton('Cost', 0),
                          SizedBox(width: AppResponsive.spacingSmall()),
                          _buildTabButton('Payments', 1),
                        ],
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ),

              Image.asset(
                'assets/image/bored.png',
                height: AppResponsive.getHeight(20),
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
                        topLeft: Radius.circular(AppResponsive.borderRadiusLarge()),
                        topRight: Radius.circular(AppResponsive.borderRadiusLarge()),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppResponsive.responsivePadding() * 1.5,
                      AppResponsive.responsivePadding() * 1.5,
                      AppResponsive.responsivePadding() * 1.5,
                      AppResponsive.responsivePadding(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _budget!.itemName,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: AppResponsive.headerFontSize(),
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w700,
                                    height: 0.88,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: AppResponsive.spacingSmall()),
                                Text(
                                  'Rp${NumberFormat('#,###', 'id_ID').format(_budget!.totalCost)} Total Cost',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: AppResponsive.smallFontSize(),
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                    height: 1.69,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedTabIndex == 0)
                              GestureDetector(
                                onTap: () {
                                  if (_isEditMode) {
                                    _saveChanges();
                                  } else {
                                    setState(() {
                                      _isEditMode = !_isEditMode;
                                    });
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
                                    size: AppResponsive.responsiveIconSize(18),
                                    color: Colors.black,
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: _showAddPaymentDialog,
                                child: Container(
                                  width: 31,
                                  height: 31,
                                  decoration: const ShapeDecoration(
                                    color: Color(0xFFFFE100),
                                    shape: OvalBorder(),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: AppResponsive.responsiveIconSize(18),
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: AppResponsive.spacingExtraLarge()),

                        _selectedTabIndex == 0
                            ? _buildCostDetails()
                            : _buildPaymentsTab(),
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

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
          _isEditMode = false;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.responsivePadding() * 1.2,
          vertical: AppResponsive.spacingSmall(),
        ),
        decoration: ShapeDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Colors.black),
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFBD09) : Colors.black,
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
            height: 1.57,
          ),
        ),
      ),
    );
  }

  Widget _buildCostDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          'Budget Name',
          _nameController,
          enabled: _isEditMode,
        ),
        SizedBox(height: AppResponsive.spacingMedium()),

        _buildFormField(
          'Date',
          _dateController,
          enabled: _isEditMode,
          isDateField: true,
          onTapDate: _isEditMode ? _selectDate : null,
        ),
        SizedBox(height: AppResponsive.spacingMedium()),

        _buildFormField(
          'Budget',
          _budgetController,
          enabled: _isEditMode,
          prefix: 'Rp',
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: AppResponsive.spacingMedium()),

        _buildFormField(
          'Paid',
          TextEditingController(
            text: NumberFormat('#,###', 'id_ID').format(_budget!.paidAmount),
          ),
          enabled: false,
          prefix: 'Rp',
        ),
        SizedBox(height: AppResponsive.spacingMedium()),

        _buildFormField(
          'Unpaid',
          TextEditingController(
            text: NumberFormat('#,###', 'id_ID').format(_budget!.unpaidAmount),
          ),
          enabled: false,
          prefix: 'Rp',
        ),
        SizedBox(height: AppResponsive.spacingMedium()),

        _buildFormField(
          'Note',
          _noteController,
          enabled: _isEditMode,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    if (_budget == null || _budget!.payments.isEmpty) {
      return _buildEmptyPaymentsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._budget!.payments.asMap().entries.map((entry) {
          final payment = entry.value;
          final index = entry.key;
          return _buildPaymentItem(payment, index);
        }),
      ],
    );
  }

  Widget _buildEmptyPaymentsState() {
    return Column(
      children: [
        SizedBox(height: AppResponsive.getHeight(5)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 125,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: AppResponsive.responsiveIconSize(50),
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: AppResponsive.spacingMedium()),
              Text(
                'There are no payments',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.30),
                  fontSize: AppResponsive.smallFontSize(),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppResponsive.getHeight(5)),
      ],
    );
  }

  Widget _buildPaymentItem(PaymentRecord payment, int index) {
    double cumulativePaid = 0;
    for (int i = 0; i <= index; i++) {
      cumulativePaid += _budget!.payments[i].amount;
    }
    final cumulativeUnpaid = _budget!.totalCost - cumulativePaid;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailScreen(
              budgetId: widget.budgetId,
              payment: payment,
              paymentIndex: index,
            ),
          ),
        ).then((result) {
          if (result == true) {
            _loadBudget();
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1.50),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.spacingSmall()),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment ${index + 1}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: AppResponsive.bodyFontSize(),
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                        height: 0.86,
                      ),
                    ),
                    Text(
                      'Rp${NumberFormat('#,###', 'id_ID').format(payment.amount)}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: AppResponsive.bodyFontSize(),
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                        height: 0.86,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.spacingSmall()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid: Rp${NumberFormat('#,###', 'id_ID').format(cumulativePaid)}',
                style: TextStyle(
                  color: const Color(0xFFA1A1A1),
                  fontSize: AppResponsive.extraSmallFontSize(),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  height: 1.20,
                ),
              ),
              Text(
                'Unpaid: Rp${NumberFormat('#,###', 'id_ID').format(cumulativeUnpaid)}',
                style: TextStyle(
                  color: const Color(0xFFA1A1A1),
                  fontSize: AppResponsive.extraSmallFontSize(),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  height: 1.20,
                ),
              ),
            ],
          ),
          if (index < _budget!.payments.length - 1) SizedBox(height: AppResponsive.spacingMedium()),
        ],
      ),
    );
  }

  Widget _buildFormField(
      String label,
      TextEditingController controller, {
        bool enabled = false,
        TextInputType? keyboardType,
        VoidCallback? onTapDate,
        bool isDateField = false,
        String? prefix,
        int maxLines = 1,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          height: 48,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 2,
                color: Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
            ),
          ),
          child: isDateField
              ? GestureDetector(
            onTap: enabled ? onTapDate : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.spacingMedium(),
                vertical: AppResponsive.spacingMedium(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.text,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: AppResponsive.bodyFontSize(),
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
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
          )
              : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.spacingMedium(),
              vertical: AppResponsive.spacingSmall(),
            ),
            child: Row(
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.bodyFontSize(),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: AppResponsive.spacingSmall()),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.bodyFontSize(),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
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

  void _showAddPaymentDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePaymentScreen(
          budgetId: widget.budgetId,
          budgetName: _budget!.itemName,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadBudget();
      }
    });
  }
}
