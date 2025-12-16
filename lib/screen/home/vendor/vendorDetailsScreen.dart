import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/vendor_model.dart';
import '../../../model/budget_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';
import '../../../service/budget_service.dart';

class VendorDetailsScreen extends StatefulWidget {
  final String vendorId;
  final String eventId;

  const VendorDetailsScreen({
    Key? key,
    required this.vendorId,
    required this.eventId,
  }) : super(key: key);

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

  // Controllers
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

  ///  Load budgets dari events/{eventId}/budgets/ (FIXED PATH)
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
    _selectedStatus = vendor.agreementStatus ?? 'not contacted';


    _selectedBudgetId = (vendor.toMap()['linkedBudgetId'] as String?) ?? '';
    debugPrint(' Loaded selectedBudgetId: $_selectedBudgetId');
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

      // Update vendor flag
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

      // Add vendor to budget using BudgetService
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

      // Update vendor flag
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('vendors')
          .doc(widget.vendorId)
          .update({
        'addToBudget': false,
        'lastUpdated': DateTime.now(),
      });

      // Remove vendor from budget using BudgetService
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
            style: const TextStyle(
              color: Color(0xFF616161),
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: controller,
                enabled: enabled || _isEditMode,
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
          ),
          const SizedBox(height: 12),
        ],
      );
    }

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
        Text(
          controller.text.isEmpty ? '-' : controller.text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Status Dropdown
  Widget _buildStatusDropdown() {
    if (!_isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(
              color: Color(0xFF616161),
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _selectedStatus?.toUpperCase() ?? 'NOT CONTACTED',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButton<String>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _selectedStatus,
              hint: const Text('Select Status'),
              items: _statuses.map((status) {
                return DropdownMenuItem<String>(
                  value: status.toLowerCase(),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
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
        const SizedBox(height: 12),
      ],
    );
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
              // Header
              SafeArea(
                bottom: false,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
              // Content Area
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
                      return const Center(
                        child: Text('Vendor not found'),
                      );
                    }

                    final vendor = VendorModel.fromMap(
                      snapshot.data!.data() as Map<String, dynamic>,
                    );

                    if (!_isEditMode) {
                      _initializeControllers(vendor);
                    }

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // Image
                          Image.asset(
                            'assets/image/bored.png',
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 15),
                          // White Container
                          Container(
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
                                  // Title Section
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vendor.vendorName,
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
                                            'Rp${NumberFormat('#,###', 'id_ID').format(vendor.totalCost)} Total Cost',
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
                                          width: 31,
                                          height: 31,
                                          decoration: const ShapeDecoration(
                                            color: Color(0xFFFFE100),
                                            shape: OvalBorder(),
                                          ),
                                          child: Icon(
                                            _isEditMode
                                                ? Icons.check
                                                : Icons.edit,
                                            size: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),

                                  // Vendor Details
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

                                  // Status Dropdown
                                  _buildStatusDropdown(),

                                  const SizedBox(height: 20),

                                  // Budget Section
                                  const Divider(
                                    height: 1,
                                    color: Colors.black12,
                                  ),
                                  const SizedBox(height: 20),

                                  const Text(
                                    'Add to Budget',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'SF Pro',
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 15),

                                  // Budget Dropdown & Checkbox
                                  FutureBuilder<List<BudgetModel>>(
                                    future: _budgetsFuture,
                                    builder: (context, budgetSnapshot) {
                                      if (budgetSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const CircularProgressIndicator();
                                      }

                                      if (budgetSnapshot.hasError) {
                                        return Text(
                                          'Error: ${budgetSnapshot.error}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'SF Pro',
                                            color: Colors.red,
                                          ),
                                        );
                                      }

                                      final budgets =
                                          budgetSnapshot.data ?? [];

                                      if (budgets.isEmpty) {
                                        return Text(
                                          'No budgets available',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'SF Pro',
                                            color: Colors.grey[600],
                                          ),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          //  Dropdown
                                          if (_isEditMode)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.black,
                                                ),
                                                borderRadius:
                                                BorderRadius.circular(8),
                                              ),
                                              child: DropdownButton<String>(
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                value: _selectedBudgetId?.isEmpty == true ? null : _selectedBudgetId,
                                                hint: const Text(
                                                  'Select Budget',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro',
                                                  ),
                                                ),
                                                items: budgets.map((budget) {
                                                  return DropdownMenuItem<String>(
                                                    value: budget.budgetId,
                                                    child: Text(
                                                      '${budget.itemName} (${budget.category})',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontFamily: 'SF Pro',
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
                                          //  View mode - tampilkan selected budget
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Selected Budget',
                                                  style: TextStyle(
                                                    color: Color(0xFF616161),
                                                    fontSize: 14,
                                                    fontFamily: 'SF Pro',
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 7),
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
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 14,
                                                    fontFamily: 'SF Pro',
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            ),

                                          const SizedBox(height: 15),

                                          // Checkbox
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey
                                                    .withOpacity(0.3),
                                              ),
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                            child: CheckboxListTile(
                                              title: const Text(
                                                'Link this vendor to selected budget',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'SF Pro',
                                                  color: Colors.black,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Cost: Rp ${NumberFormat('#,###', 'id_ID').format(vendor.totalCost)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'SF Pro',
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              value: vendor.addToBudget ??
                                                  false,
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
                                              activeColor:
                                              const Color(0xFFFFE100),
                                              checkColor: Colors.black,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 30),
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