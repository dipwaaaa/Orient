import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/budget_service.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/animated_gradient_background.dart';
import 'package:intl/intl.dart';

class CreateBudgetScreen extends StatefulWidget {
  final String eventId;

  const CreateBudgetScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BudgetService _budgetService = BudgetService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();

  String _selectedEventName = '';
  String? _selectedCategory;
  String _selectedStatus = 'pending';
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _showCustomCategoryInput = false;

  final List<String> _defaultCategories = [
    'Unassigned',
    'Attire & Accessories',
    'Food And Beverages',
    'Music & Show',
    'Flowers & Decor',
    'Photo & Video',
    'Transportation',
    'Accommodation',
  ];

  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(_defaultCategories);
    _loadEventName();
  }

  Future<void> _loadEventName() async {
    try {
      final eventDoc = await _firestore
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (eventDoc.exists && mounted) {
        setState(() {
          _selectedEventName = eventDoc.data()?['eventName'] ?? 'Active Event';
        });
      }
    } catch (e) {
      debugPrint('Error loading event name: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
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

  void _addCustomCategory() {
    final customCategory = _customCategoryController.text.trim();

    if (customCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    if (_categories.contains(customCategory)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category already exists')),
      );
      return;
    }

    setState(() {
      _categories.add(customCategory);
      _selectedCategory = customCategory;
      _customCategoryController.clear();
      _showCustomCategoryInput = false;
    });
  }

  Future<void> _createBudget() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter budget name')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_budgetController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter budget amount')),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final budget = double.tryParse(
        _budgetController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
      ) ??
          0;

      if (budget <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid budget amount')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final result = await _budgetService.createBudget(
        eventId: widget.eventId,
        itemName: _nameController.text.trim(),
        category: _selectedCategory!,
        totalCost: budget,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'])),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating budget: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create budget: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      String hint, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
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
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
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
                    _dateController.text.isEmpty
                        ? 'Select date'
                        : _dateController.text,
                    style: TextStyle(
                      color: _dateController.text.isEmpty
                          ? const Color(0xFF1D1D1D).withValues(alpha: 0.6)
                          : Colors.black,
                      fontSize: AppResponsive.responsiveFont(13),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: AppResponsive.responsiveIconSize(18)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                children: ['Completed', 'Pending'].map((status) {
                  final statusValue = status.toLowerCase();
                  final isSelected = _selectedStatus == statusValue;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = statusValue;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.responsivePadding(),
                        vertical: AppResponsive.spacingSmall() * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFE100)
                            : Colors.white,
                        border: Border.all(width: 1, color: Colors.black),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: AppResponsive.responsiveFont(14),
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w500,
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
    );
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
                child: Column(
                  children: [
                    SizedBox(height: AppResponsive.spacingMedium()),
                    _buildHeader(),
                    SizedBox(height: AppResponsive.spacingLarge()),
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.responsivePadding() * 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField('Name', _nameController, 'Type here'),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildDateField(),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildTextField('Budget', _budgetController, 'Type here',
                            keyboardType: TextInputType.number),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        _buildTextField('Note', _noteController, 'Type here',
                            maxLines: 3),
                        SizedBox(height: AppResponsive.spacingLarge()),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                flex: 3,
                child: Container(
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
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Category',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: AppResponsive.responsiveFont(14),
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showCustomCategoryInput =
                                    !_showCustomCategoryInput;
                                  });
                                },
                                child: Container(
                                  width: AppResponsive.responsiveSize(0.089),
                                  height: AppResponsive.responsiveSize(0.089),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFE100),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.black,
                                    size: AppResponsive.responsiveIconSize(18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppResponsive.spacingSmall()),

                          if (_showCustomCategoryInput)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: AppResponsive.spacingSmall(),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customCategoryController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter category name',
                                        hintStyle: TextStyle(
                                          color: const Color(0xFF1D1D1D)
                                              .withValues(alpha: 0.6),
                                          fontSize: AppResponsive.responsiveFont(12),
                                          fontFamily: 'SF Pro',
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppResponsive.borderRadiusMedium(),
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: AppResponsive.spacingSmall(),
                                          vertical: AppResponsive.spacingSmall() * 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: AppResponsive.spacingSmall()),
                                  GestureDetector(
                                    onTap: _addCustomCategory,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppResponsive.spacingSmall(),
                                        vertical: AppResponsive.spacingSmall() * 0.8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE100),
                                        borderRadius: BorderRadius.circular(
                                          AppResponsive.borderRadiusMedium(),
                                        ),
                                        border: Border.all(
                                          width: 1,
                                          color: Colors.black,
                                        ),
                                      ),
                                      child: Text(
                                        'Add',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: AppResponsive.responsiveFont(12),
                                          fontFamily: 'SF Pro',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Wrap(
                            spacing: AppResponsive.spacingSmall(),
                            runSpacing: AppResponsive.spacingSmall(),
                            children: _categories.map((category) {
                              final isSelected =
                                  _selectedCategory == category;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppResponsive.spacingSmall() * 1.3,
                                    vertical: AppResponsive.spacingSmall() * 0.8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFE100)
                                        : Colors.white,
                                    border: Border.all(
                                        width: 1, color: Colors.black),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    category,
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
                          SizedBox(height: AppResponsive.spacingLarge()),

                          _buildStatusSection(),
                        ],
                      ),
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

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.responsivePadding() * 2,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Text(
                'Create a Budget',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: AppResponsive.responsiveFont(25),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
              ),
              GestureDetector(
                onTap: _isLoading ? null : _createBudget,
                child: Container(
                  width: AppResponsive.responsiveSize(0.122),
                  height: AppResponsive.responsiveSize(0.122),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.save,
                    color: Colors.white,
                    size: AppResponsive.responsiveIconSize(24),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedEventName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: AppResponsive.spacingSmall()),
              child: Text(
                'for $_selectedEventName',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontSize: AppResponsive.responsiveFont(13),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
}