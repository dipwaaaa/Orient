import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';
import 'create_payment_screen.dart';
import 'payment_detail_screen.dart';

class BudgetDetailScreen extends StatefulWidget {
  final String budgetId;

  const BudgetDetailScreen({
    super.key,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabButton('Cost', 0),
                          const SizedBox(width: 7),
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
                        // Title section di dalam card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _budget!.itemName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 25,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w700,
                                    height: 0.88,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Rp${NumberFormat('#,###', 'id_ID').format(_budget!.totalCost)} Total Cost',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
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
                                    size: 18,
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
                                  child: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Content berdasarkan tab
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
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
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
            fontSize: 14,
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
        const SizedBox(height: 12),

        _buildFormField(
          'Date',
          _dateController,
          enabled: _isEditMode,
          isDateField: true,
          onTapDate: _isEditMode ? _selectDate : null,
        ),
        const SizedBox(height: 12),

        _buildFormField(
          'Budget',
          _budgetController,
          enabled: _isEditMode,
          prefix: 'Rp',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        _buildFormField(
          'Paid',
          TextEditingController(
            text: NumberFormat('#,###', 'id_ID').format(_budget!.paidAmount),
          ),
          enabled: false,
          prefix: 'Rp',
        ),
        const SizedBox(height: 12),

        _buildFormField(
          'Unpaid',
          TextEditingController(
            text: NumberFormat('#,###', 'id_ID').format(_budget!.unpaidAmount),
          ),
          enabled: false,
          prefix: 'Rp',
        ),
        const SizedBox(height: 12),

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
        }).toList(),
      ],
    );
  }

  Widget _buildEmptyPaymentsState() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 125,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'There are no payments',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.30),
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 50),
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
              const SizedBox(width: 5),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment ${index + 1}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                        height: 0.86,
                      ),
                    ),
                    Text(
                      'Rp${NumberFormat('#,###', 'id_ID').format(payment.amount)}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid: Rp${NumberFormat('#,###', 'id_ID').format(cumulativePaid)}',
                style: const TextStyle(
                  color: Color(0xFFA1A1A1),
                  fontSize: 10,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  height: 1.20,
                ),
              ),
              Text(
                'Unpaid: Rp${NumberFormat('#,###', 'id_ID').format(cumulativeUnpaid)}',
                style: const TextStyle(
                  color: Color(0xFFA1A1A1),
                  fontSize: 10,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  height: 1.20,
                ),
              ),
            ],
          ),
          if (index < _budget!.payments.length - 1) const SizedBox(height: 12),
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
          style: const TextStyle(
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Container(
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
          child: isDateField
              ? GestureDetector(
            onTap: enabled ? onTapDate : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.text,
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
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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