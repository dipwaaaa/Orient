import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/vendor_model.dart';
import '../../../model/budget_model.dart';
import '../../../widget/animated_gradient_background.dart';
import '../../../service/budget_service.dart';
import '../../../utilty/app_responsive.dart';

class VendorDetailsScreen extends StatefulWidget {
  final String vendorId;
  final String eventId;

  const VendorDetailsScreen({
    super.key,
    required this.vendorId,
    required this.eventId,
  });

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  late Future<DocumentSnapshot> _vendorFuture;
  late Future<List<BudgetModel>> _budgetsFuture;
  final BudgetService _budgetService = BudgetService();

  bool _isEditMode = false;
  String? _selectedBudgetId;
  String? _selectedStatus;
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _totalCostController;
  late TextEditingController _noteController;

  final List<String> _statuses = [
    'Not Contacted',
    'Contacted',
    'Reserved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _vendorFuture = _loadVendor();
    _budgetsFuture = _loadBudgets();

    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _totalCostController = TextEditingController();
    _noteController = TextEditingController();
  }

  Future<DocumentSnapshot> _loadVendor() async {
    return await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('vendors')
        .doc(widget.vendorId)
        .get();
  }

  Future<List<BudgetModel>> _loadBudgets() async {
    try {
      debugPrint('📂 Loading budgets for event: ${widget.eventId}');

      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('budgets')
          .get();

      debugPrint('📊 Budgets found: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No budgets found for event: ${widget.eventId}');
        return [];
      }

      final budgets = snapshot.docs
          .map((doc) {
        try {
          final budget = BudgetModel.fromMap(doc.data());
          debugPrint('✅ Loaded budget: ${budget.itemName}');
          return budget;
        } catch (e) {
          debugPrint('❌ Error parsing budget: $e');
          return null;
        }
      })
          .whereType<BudgetModel>()
          .toList();

      debugPrint('✅ Successfully loaded ${budgets.length} budgets');
      return budgets;
    } catch (e) {
      debugPrint('❌ Error loading budgets: $e');
      return [];
    }
  }

  void _initializeControllers(VendorModel vendor) {
    _nameController.text = vendor.vendorName;
    _phoneController.text = vendor.phoneNumber ?? '';
    _emailController.text = vendor.email ?? '';
    _addressController.text = vendor.address ?? '';
    _totalCostController.text = vendor.totalCost.toString();
    _noteController.text = vendor.note ?? '';
    _selectedStatus = vendor.agreementStatus;

    _selectedBudgetId = (vendor.toMap()['linkedBudgetId'] as String?) ?? '';
    debugPrint('🔗 Loaded selectedBudgetId: $_selectedBudgetId');
  }

  Future<void> _toggleAddToBudget(VendorModel vendor, bool value) async {
    if (!value) {
      await _unlinkVendorFromBudget(vendor);
      return;
    }

    if (_selectedBudgetId == null || _selectedBudgetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a budget first')),
      );
      return;
    }

    await _linkVendorToBudget(vendor, _selectedBudgetId!);
  }

  Future<void> _linkVendorToBudget(VendorModel vendor, String budgetId) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('vendors')
          .doc(widget.vendorId)
          .update({
        'addToBudget': true,
        'linkedBudgetId': budgetId,
        'lastUpdated': DateTime.now(),
      });

      final result = await _budgetService.addLinkedVendor(
        budgetId: budgetId,
        vendorId: widget.vendorId,
        vendorName: vendor.vendorName,
        vendorCategory: vendor.category,
        contribution: vendor.totalCost,
      );

      if (mounted) {
        setState(() {
          _vendorFuture = _loadVendor();
          _isLoading = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vendor linked to budget!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result['error']}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error linking vendor to budget: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unlinkVendorFromBudget(VendorModel vendor) async {
    try {
      setState(() => _isLoading = true);

      final budgets = await _budgetsFuture;
      String? linkedBudgetId;

      for (var budget in budgets) {
        final isLinked = budget.linkedVendors.any(
              (v) => v.vendorId == widget.vendorId,
        );
        if (isLinked) {
          linkedBudgetId = budget.budgetId;
          break;
        }
      }

      if (linkedBudgetId == null) {
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('vendors')
          .doc(widget.vendorId)
          .update({
        'addToBudget': false,
        'lastUpdated': DateTime.now(),
      });

      final result = await _budgetService.removeLinkedVendor(
        budgetId: linkedBudgetId,
        vendorId: widget.vendorId,
      );

      if (mounted) {
        setState(() {
          _vendorFuture = _loadVendor();
          _isLoading = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vendor unlinked from budget'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result['error']}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error unlinking vendor from budget: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges(VendorModel vendor) async {
    try {
      final updatedCost = double.tryParse(_totalCostController.text.trim());
      if (updatedCost == null || updatedCost <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid total cost')),
        );
        return;
      }

      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('vendors')
          .doc(widget.vendorId)
          .update({
        'vendorName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'totalCost': updatedCost,
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'agreementStatus': _selectedStatus ?? 'not contacted',
        'linkedBudgetId': _selectedBudgetId ?? '',
        'lastUpdated': DateTime.now(),
      });

      if (mounted) {
        setState(() {
          _isEditMode = false;
          _vendorFuture = _loadVendor();
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating vendor: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildFormField(
      String label,
      TextEditingController controller, {
        bool enabled = false,
        TextInputType? keyboardType,
        int maxLines = 1,
      }) {
    if (_isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppResponsive.responsiveTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF616161),
            ),
          ),
          SizedBox(height: AppResponsive.spacingSmall()),
          Container(
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 2,
                  color: Color(0xFFFFE100),
                ),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadiusSmall()),
              ),
            ),
            child: Padding(
              padding: AppResponsive.responsivePaddingSymmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: TextField(
                controller: controller,
                enabled: enabled || _isEditMode,
                keyboardType: keyboardType,
                maxLines: maxLines,
                style: AppResponsive.responsiveTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          SizedBox(height: AppResponsive.spacingMedium()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppResponsive.responsiveTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF616161),
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Text(
          controller.text.isEmpty ? '-' : controller.text,
          style: AppResponsive.responsiveTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        SizedBox(height: AppResponsive.spacingMedium()),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    if (!_isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: AppResponsive.responsiveTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF616161),
            ),
          ),
          SizedBox(height: AppResponsive.spacingSmall()),
          Text(
            _selectedStatus?.toUpperCase() ?? 'NOT CONTACTED',
            style: AppResponsive.responsiveTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: AppResponsive.spacingMedium()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: AppResponsive.responsiveTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF616161),
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 2,
                color: Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusSmall()),
            ),
          ),
          child: Padding(
            padding: AppResponsive.responsivePaddingSymmetric(
              horizontal: 12,
              vertical: 4,
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _selectedStatus,
              hint: Text(
                'Select Status',
                style: AppResponsive.responsiveTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              items: _statuses.map((status) {
                return DropdownMenuItem<String>(
                  value: status.toLowerCase(),
                  child: Text(
                    status,
                    style: AppResponsive.responsiveTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ),
        ),
        SizedBox(height: AppResponsive.spacingMedium()),
      ],
    );
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
                  padding: AppResponsive.responsivePaddingSymmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: AppResponsive.responsiveSize(0.097),
                          height: AppResponsive.responsiveSize(0.097),
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
                      SizedBox(width: AppResponsive.spacingSmall()),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: _vendorFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFE100),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(
                        child: Text(
                          'Vendor not found',
                          style: AppResponsive.bodyStyle(),
                        ),
                      );
                    }

                    final vendor = VendorModel.fromMap(
                      snapshot.data!.data() as Map<String, dynamic>,
                    );

                    if (!_isEditMode) {
                      _initializeControllers(vendor);
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/image/bored.png',
                            height: AppResponsive.responsiveHeight(20),
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: AppResponsive.spacingMedium()),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(AppResponsive.borderRadiusLarge()),
                                topRight: Radius.circular(AppResponsive.borderRadiusLarge()),
                              ),
                            ),
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              padding: AppResponsive.responsivePaddingSymmetric(
                                horizontal: 45,
                                vertical: 43,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              vendor.vendorName,
                                              style: AppResponsive.responsiveTextStyle(
                                                fontSize: 25,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black,
                                                height: 0.88,
                                              ),
                                            ),
                                            SizedBox(height: AppResponsive.spacingSmall() * 0.3),
                                            Text(
                                              'Rp${NumberFormat('#,###', 'id_ID').format(vendor.totalCost)} Total Cost',
                                              style: AppResponsive.responsiveTextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                                height: 1.69,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (_isEditMode) {
                                            _saveChanges(vendor);
                                          } else {
                                            setState(() {
                                              _isEditMode = !_isEditMode;
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: AppResponsive.responsiveSize(0.075),
                                          height: AppResponsive.responsiveSize(0.075),
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
                                  SizedBox(height: AppResponsive.spacingLarge()),
                                  _buildFormField(
                                    'Vendor Name',
                                    _nameController,
                                    enabled: _isEditMode,
                                  ),
                                  _buildFormField(
                                    'Phone',
                                    _phoneController,
                                    enabled: _isEditMode,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  _buildFormField(
                                    'E-Mail',
                                    _emailController,
                                    enabled: _isEditMode,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  _buildFormField(
                                    'Address',
                                    _addressController,
                                    enabled: _isEditMode,
                                    maxLines: 2,
                                  ),
                                  _buildFormField(
                                    'Total Cost (Rp)',
                                    _totalCostController,
                                    enabled: _isEditMode,
                                    keyboardType: TextInputType.number,
                                  ),
                                  _buildFormField(
                                    'Note',
                                    _noteController,
                                    enabled: _isEditMode,
                                    maxLines: 2,
                                  ),
                                  _buildStatusDropdown(),
                                  SizedBox(height: AppResponsive.spacingLarge()),
                                  const Divider(
                                    height: 1,
                                    color: Colors.black12,
                                  ),
                                  SizedBox(height: AppResponsive.spacingLarge()),
                                  Text(
                                    'Add to Budget',
                                    style: AppResponsive.responsiveTextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: AppResponsive.spacingMedium()),
                                  FutureBuilder<List<BudgetModel>>(
                                    future: _budgetsFuture,
                                    builder: (context, budgetSnapshot) {
                                      if (budgetSnapshot.connectionState == ConnectionState.waiting) {
                                        return const CircularProgressIndicator();
                                      }

                                      if (budgetSnapshot.hasError) {
                                        return Text(
                                          'Error: ${budgetSnapshot.error}',
                                          style: AppResponsive.responsiveTextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.red,
                                          ),
                                        );
                                      }

                                      final budgets = budgetSnapshot.data ?? [];

                                      if (budgets.isEmpty) {
                                        return Text(
                                          'No budgets available',
                                          style: AppResponsive.responsiveTextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_isEditMode)
                                            Container(
                                              padding: AppResponsive.responsivePaddingSymmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.black,
                                                ),
                                                borderRadius: BorderRadius.circular(
                                                  AppResponsive.borderRadiusSmall(),
                                                ),
                                              ),
                                              child: DropdownButton<String>(
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                value: _selectedBudgetId?.isEmpty == true ? null : _selectedBudgetId,
                                                hint: Text(
                                                  'Select Budget',
                                                  style: AppResponsive.responsiveTextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                items: budgets.map((budget) {
                                                  return DropdownMenuItem<String>(
                                                    value: budget.budgetId,
                                                    child: Text(
                                                      '${budget.itemName} (${budget.category})',
                                                      style: AppResponsive.responsiveTextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w400,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedBudgetId = value;
                                                  });
                                                },
                                              ),
                                            )
                                          else
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Selected Budget',
                                                  style: AppResponsive.responsiveTextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF616161),
                                                  ),
                                                ),
                                                SizedBox(height: AppResponsive.spacingSmall()),
                                                Text(
                                                  _selectedBudgetId?.isEmpty == true
                                                      ? 'No budget selected'
                                                      : budgets
                                                      .firstWhere(
                                                        (b) => b.budgetId == _selectedBudgetId,
                                                    orElse: () => BudgetModel(
                                                      budgetId: '',
                                                      eventId: '',
                                                      itemName: 'Unknown',
                                                      category: '',
                                                      totalCost: 0,
                                                      paidAmount: 0,
                                                      unpaidAmount: 0,
                                                      linkedVendors: [],
                                                      payments: [],
                                                      lastUpdated: DateTime.now(),
                                                      createdAt: DateTime.now(),
                                                    ),
                                                  )
                                                      .itemName,
                                                  style: AppResponsive.responsiveTextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                SizedBox(height: AppResponsive.spacingMedium()),
                                              ],
                                            ),
                                          SizedBox(height: AppResponsive.spacingMedium()),
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.withValues(alpha:  0.3),
                                              ),
                                              borderRadius: BorderRadius.circular(
                                                AppResponsive.borderRadiusSmall(),
                                              ),
                                            ),
                                            child: CheckboxListTile(
                                              title: Text(
                                                'Link this vendor to selected budget',
                                                style: AppResponsive.responsiveTextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Cost: Rp ${NumberFormat('#,###', 'id_ID').format(vendor.totalCost)}',
                                                style: AppResponsive.responsiveTextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              value: vendor.addToBudget ?? false,
                                              onChanged: _isLoading
                                                  ? null
                                                  : (value) {
                                                if (value != null) {
                                                  _toggleAddToBudget(
                                                    vendor,
                                                    value,
                                                  );
                                                }
                                              },
                                              activeColor: const Color(0xFFFFE100),
                                              checkColor: Colors.black,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  SizedBox(height: AppResponsive.spacingExtraLarge()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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
    _totalCostController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}