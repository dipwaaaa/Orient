import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';

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

  int _selectedTabIndex = 0; // 0 = Cost, 1 = Payments
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
        _dateController.text = DateFormat('MMMM d, yyyy').format(budget.createdAt);
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
        _dateController.text = DateFormat('MMMM d, yyyy').format(picked);
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
          // Animated Gradient Background
          Positioned.fill(
            child: AnimatedGradientBackground(),
          ),

          // Main Content Column
          Column(
            children: [
              // Header Bar dengan SafeArea
              SafeArea(
                bottom: false,
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close Button
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
                      // Tab Buttons di Tengah
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabButton('Cost', 0),
                          const SizedBox(width: 7),
                          _buildTabButton('Payments', 1),
                        ],
                      ),
                      // Spacer
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),

              // Spacer untuk cat image
              const SizedBox(height: 160),

              // White Container dengan Content
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
                      children: [
                        _buildTitleRow(),
                        const SizedBox(height: 28),
                        _selectedTabIndex == 0
                            ? _buildCostDetails()
                            : _buildPaymentsList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Cat Image - Positioned dengan simetris antara header dan card
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 60,
            child: Center(
              child: Image.asset(
                'assets/image/bored.png',
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _budget!.itemName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 25,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
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
                ),
              ),
            ],
          ),
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
          ),
        if (_selectedTabIndex == 1) ...[
          GestureDetector(
            onTap: _budget!.payments.isNotEmpty
                ? () => _showEditPaymentDialog(_budget!.payments.first)
                : null,
            child: Container(
              width: 31,
              height: 31,
              decoration: const ShapeDecoration(
                color: Color(0xFFFFE100),
                shape: OvalBorder(),
              ),
              child: const Icon(
                Icons.edit,
                size: 18,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      ],
    );
  }

  Widget _buildCostDetails() {
    return Column(
      children: [
        _buildDetailField(
          'Budget Name',
          _isEditMode
              ? _nameController.text
              : _budget!.itemName,
          controller: _isEditMode ? _nameController : null,
          enabled: _isEditMode,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Date',
          _isEditMode
              ? _dateController.text
              : DateFormat('MMMM d, yyyy').format(_budget!.createdAt),
          enabled: false,
          onTap: _isEditMode ? _selectDate : null,
          isDateField: true,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Budget',
          _isEditMode
              ? _budgetController.text
              : 'Rp${NumberFormat('#,###', 'id_ID').format(_budget!.totalCost)}',
          controller: _isEditMode ? _budgetController : null,
          enabled: _isEditMode,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Paid',
          'Rp${NumberFormat('#,###', 'id_ID').format(_budget!.paidAmount)}',
          enabled: false,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Unpaid',
          'Rp${NumberFormat('#,###', 'id_ID').format(_budget!.unpaidAmount)}',
          enabled: false,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Note',
          _isEditMode ? null : (_budget!.note ?? '-'),
          controller: _isEditMode ? _noteController : null,
          enabled: _isEditMode,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Category',
          _budget!.category,
          enabled: false,
        ),
        const SizedBox(height: 12),
        _buildDetailField(
          'Status',
          _budget!.unpaidAmount <= 0 ? 'Paid' : 'Unpaid',
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildPaymentsList() {
    if (_budget!.payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            'No payments yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _budget!.payments.map((payment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              _buildDetailField('Payment ID', payment.paymentId, enabled: false),
              const SizedBox(height: 12),
              _buildDetailField(
                'Amount',
                'Rp${NumberFormat('#,###', 'id_ID').format(payment.amount)}',
                enabled: false,
              ),
              const SizedBox(height: 12),
              _buildDetailField(
                'Date',
                DateFormat('MMMM d, yyyy').format(payment.date),
                enabled: false,
              ),
              const SizedBox(height: 12),
              _buildDetailField('Note', payment.note ?? '-', enabled: false),
              const Divider(height: 32),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailField(
      String label,
      String? value, {
        bool enabled = false,
        TextEditingController? controller,
        TextInputType? keyboardType,
        VoidCallback? onTap,
        bool isDateField = false,
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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        if (isDateField)
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 2,
                    color: Color(0xFFFFE100),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_today, size: 18, color: Colors.black),
                ],
              ),
            ),
          )
        else if (enabled && controller != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 2,
                  color: Color(0xFFFFE100),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
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
          )
        else
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 2,
                    color: Color(0xFFFFE100),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                value ?? '',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  final amount = double.tryParse(
                    amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                      0;

                  if (amount > 0) {
                    final result = await _budgetService.addPayment(
                      budgetId: widget.budgetId,
                      amount: amount,
                      date: selectedDate,
                      note: noteController.text.isEmpty
                          ? null
                          : noteController.text,
                    );

                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      if (result['success']) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        await _loadBudget();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['error']),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFE100),
                foregroundColor: Colors.black,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPaymentDialog(PaymentRecord payment) {
    final amountController = TextEditingController(
      text: payment.amount.toStringAsFixed(0),
    );
    final noteController = TextEditingController(text: payment.note ?? '');
    DateTime selectedDate = payment.date;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  final amount = double.tryParse(
                    amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                      0;

                  if (amount > 0) {
                    final result = await _budgetService.updatePayment(
                      budgetId: widget.budgetId,
                      paymentId: payment.paymentId,
                      amount: amount,
                      date: selectedDate,
                      note: noteController.text.isEmpty
                          ? null
                          : noteController.text,
                    );

                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      if (result['success']) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        await _loadBudget();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['error']),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFE100),
                foregroundColor: Colors.black,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}