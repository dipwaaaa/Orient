
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widget/Animated_Gradient_Background.dart';
import '../../../model/vendor_model.dart';

class AddVendorScreen extends StatefulWidget {
  final String eventId;
  final String listName;

  const AddVendorScreen({
    Key? key,
    required this.eventId,
    required this.listName,
  }) : super(key: key);

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();

  // Form state
  String? _selectedCategory;
  String _selectedStatus = 'not contacted';
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

  final List<String> _statuses = [
    'Not Contacted',
    'Contacted',
    'Reserved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _categories = List.from(_defaultCategories);
    _selectedCategory = _categories[0]; // Default to 'Unassigned'
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

  Future<void> _saveVendor() async {
    // Validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter vendor name')),
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
      final vendor = VendorModel(
        vendorId: FirebaseFirestore.instance.collection('temp').doc().id,
        eventId: widget.eventId,
        vendorName: _nameController.text.trim(),
        category: _selectedCategory!,
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        totalCost: 0.0,
        paidAmount: 0.0,
        pendingAmount: 0.0,
        agreementStatus: _selectedStatus,
        addToBudget: false,
        payments: [],
        listName: widget.listName,
        createdBy: "current_user_id",
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('vendors')
          .doc(vendor.vendorId)
          .set(vendor.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving vendor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save vendor: $e')),
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
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                fontSize: 13,
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

  Widget _buildStatusSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _statuses.map((status) {
                  final statusValue = status.toLowerCase().replaceAll(' ', ' ');
                  final isSelected = _selectedStatus == statusValue;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStatus = statusValue;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFE100)
                              : Colors.white,
                          border: Border.all(width: 1.5, color: Colors.black),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontFamily: 'SF Pro',
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // ✅ CAT IMAGE - LARGER TO MATCH MOCKUP
        Image.asset(
          'assets/image/AddTaskImageCat.png',
          height: 240,
          width: 200,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              height: 240,
              width: 200,
              child: const Icon(Icons.image_not_supported, size: 60),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated Gradient Background
          Positioned.fill(
            child: AnimatedGradientBackground(),
          ),

          // Content
          Column(
            children: [
              // Header dengan SafeArea
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 25),
                  ],
                ),
              ),

              // Form Section (Scrollable) - Yellow gradient area
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 31),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField('Name', _nameController, 'Type here'),
                        const SizedBox(height: 15),
                        _buildTextField(
                          'Phone',
                          _phoneController,
                          'Type here',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          'E-Mail',
                          _emailController,
                          'Type here',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          'Address',
                          _addressController,
                          'Type here',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),

              // Category dan Status Section (White container)
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 31, vertical: 31),
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
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
                          // Category Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
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
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFE100),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Custom Category Input
                          if (_showCustomCategoryInput)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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
                                          fontSize: 12,
                                          fontFamily: 'SF Pro',
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _addCustomCategory,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE100),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          width: 1,
                                          color: Colors.black,
                                        ),
                                      ),
                                      child: const Text(
                                        'Add',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontFamily: 'SF Pro',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Category Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((category) {
                              final isSelected = _selectedCategory == category;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFE100)
                                        : Colors.white,
                                    border: Border.all(
                                      width: 1.5,
                                      color: Colors.black,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
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
                          const SizedBox(height: 25),

                          // Status Section
                          _buildStatusSection(),
                          const SizedBox(height: 30),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveVendor,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFE100),
                                foregroundColor: Colors.black,
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  side: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                                  : const Text(
                                'Save Vendor',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 31),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          const Text(
            'Add a Vendor',
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
}