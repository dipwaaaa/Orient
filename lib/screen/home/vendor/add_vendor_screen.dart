import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/animated_gradient_background.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  final TextEditingController _totalCostController = TextEditingController();

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
    _selectedCategory = _categories[0];
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

    if (_totalCostController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter total cost')),
      );
      return;
    }

    final totalCost = double.tryParse(_totalCostController.text.trim());
    if (totalCost == null || totalCost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid total cost (> 0)')),
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
        totalCost: totalCost,
        paidAmount: 0.0,
        pendingAmount: totalCost,
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
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.all(AppResponsive.spacingSmall()),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: TextField(
            controller: controller,
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
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF1D1D1D).withValues(alpha:  0.6),
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
              SizedBox(height: AppResponsive.spacingMedium()),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _statuses.map((status) {
                  final statusValue = status.toLowerCase().replaceAll(' ', ' ');
                  final isSelected = _selectedStatus == statusValue;

                  return Padding(
                    padding: EdgeInsets.only(bottom: AppResponsive.spacingSmall()),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStatus = statusValue;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.responsivePadding(),
                          vertical: AppResponsive.spacingSmall() * 0.6,
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
                            fontSize: AppResponsive.responsiveFont(13),
                            fontFamily: 'SF Pro',
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SizedBox(width: AppResponsive.spacingMedium()),
        Image.asset(
          'assets/image/AddTaskImageCat.png',
          height: AppResponsive.responsiveHeight(26),
          width: AppResponsive.responsiveWidth(48),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              height: AppResponsive.responsiveHeight(26),
              width: AppResponsive.responsiveWidth(48),
              child: Icon(Icons.image_not_supported, size: AppResponsive.responsiveIconSize(60)),
            );
          },
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
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding() * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField('Name', _nameController, 'Type here'),
                            SizedBox(height: AppResponsive.spacingMedium()),
                            _buildTextField(
                              'Phone',
                              _phoneController,
                              'Type here',
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: AppResponsive.spacingMedium()),
                            _buildTextField(
                              'E-Mail',
                              _emailController,
                              'Type here',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: AppResponsive.spacingMedium()),
                            _buildTextField(
                              'Address',
                              _addressController,
                              'Type here',
                              maxLines: 3,
                            ),
                            SizedBox(height: AppResponsive.spacingMedium()),

                            _buildTextField(
                              'Total Cost (Rp)',
                              _totalCostController,
                              'e.g. 2000000',
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: AppResponsive.spacingLarge() * 1.5),
                          ],
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
                                SizedBox(height: AppResponsive.spacingMedium()),

                                if (_showCustomCategoryInput)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: AppResponsive.spacingMedium()),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _customCategoryController,
                                            decoration: InputDecoration(
                                              hintText: 'Enter category name',
                                              hintStyle: TextStyle(
                                                color: const Color(0xFF1D1D1D)
                                                    .withValues(alpha:  0.6),
                                                fontSize: AppResponsive.responsiveFont(12),
                                                fontFamily: 'SF Pro',
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                BorderRadius.circular(AppResponsive.borderRadiusMedium()),
                                              ),
                                              contentPadding:
                                              EdgeInsets.symmetric(
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
                                              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
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
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                    final isSelected = _selectedCategory == category;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppResponsive.responsivePadding(),
                                          vertical: AppResponsive.spacingSmall() * 0.6,
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
                                            fontSize: AppResponsive.responsiveFont(13),
                                            fontFamily: 'SF Pro',
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: AppResponsive.spacingLarge()),

                                _buildStatusSection(),
                                SizedBox(height: AppResponsive.spacingLarge() * 1.5),

                                SizedBox(
                                  width: double.infinity,
                                  height: AppResponsive.responsiveHeight(6),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveVendor,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFE100),
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.symmetric(vertical: AppResponsive.spacingMedium()),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        side: const BorderSide(
                                          color: Colors.black,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                      height: AppResponsive.responsiveHeight(2),
                                      width: AppResponsive.responsiveHeight(2),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                          Colors.black,
                                        ),
                                      ),
                                    )
                                        : Text(
                                      'Save Vendor',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: AppResponsive.responsiveFont(16),
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

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding() * 2),
      child: Row(
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
              child: Icon(Icons.close, color: Colors.white, size: AppResponsive.responsiveIconSize(20)),
            ),
          ),
          Text(
            'Add a Vendor',
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.responsiveFont(22),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Container(
            width: AppResponsive.responsiveSize(0.122),
            height: AppResponsive.responsiveSize(0.122),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info, color: Colors.white, size: AppResponsive.responsiveIconSize(20)),
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
    _totalCostController.dispose();
    super.dispose();
  }
}