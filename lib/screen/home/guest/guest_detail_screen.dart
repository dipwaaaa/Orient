import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/guest_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';

class GuestDetailScreen extends StatefulWidget {
  final GuestModel guest;

  const GuestDetailScreen({
    super.key,
    required this.guest,
  });

  @override
  State<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends State<GuestDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late GuestModel _guest;
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isDeleting = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _noteController;
  late TextEditingController _groupController;

  String _selectedGender = '';
  String _selectedAgeStatus = '';
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    _guest = widget.guest;

    _nameController = TextEditingController(text: _guest.name);
    _phoneController = TextEditingController(text: _guest.phoneNumber ?? '');
    _emailController = TextEditingController(text: _guest.email ?? '');
    _addressController = TextEditingController(text: _guest.address ?? '');
    _noteController = TextEditingController(text: _guest.note ?? '');
    _groupController = TextEditingController(text: _guest.group);

    _selectedGender = _guest.gender;
    _selectedAgeStatus =
        _guest.ageStatus[0].toUpperCase() + _guest.ageStatus.substring(1);
    _selectedStatus = _guest.status ?? 'Pending';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('guests')
          .doc(_guest.guestId)
          .update({
        'name': _nameController.text.trim(),
        'gender': _selectedGender,
        'ageStatus': _selectedAgeStatus.toLowerCase(),
        'group': _groupController.text.trim().isEmpty
            ? "General"
            : _groupController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'status': _selectedStatus,
        'updatedAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteGuest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Guest'),
        content: const Text('Are you sure you want to delete this guest?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);

      try {
        await _firestore
            .collection('guests')
            .doc(_guest.guestId)
            .delete();

        if (mounted) {
          setState(() => _isDeleting = false);
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guest deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error deleting guest: $e');
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete guest: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isDeleting) return false;
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Animated Gradient Background
            Positioned.fill(
              child: AnimatedGradientBackground(),
            ),

            // Main Content
            Column(
              children: [
                // Top Section with Avatar
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        // Back Button
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: _isDeleting ? null : () => Navigator.pop(context, true),
                            ),
                          ),
                        ),
                        // Delete Button
                        if (!_isEditMode && !_isDeleting)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _deleteGuest,
                              ),
                            ),
                          ),
                        // Loading indicator during deletion
                        if (_isDeleting)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Guest Avatar centered
                        Positioned.fill(
                          child: Center(
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: _getGenderColor(_selectedGender),
                              child: Text(
                                _guest.name.isNotEmpty
                                    ? _guest.name[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // White Content Section
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(45, 43, 45, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Edit Button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _nameController.text,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 25,
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _selectedGender,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 13,
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 31,
                                    height: 31,
                                    decoration: BoxDecoration(
                                      color: _isEditMode ? Colors.grey[200] : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        _isEditMode ? Icons.check : Icons.edit,
                                        color: Colors.black,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        if (_isEditMode) {
                                          _saveChanges();
                                        } else {
                                          setState(() {
                                            _isEditMode = !_isEditMode;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              // Guest Name Field
                              _buildField(
                                label: 'Name',
                                controller: _nameController,
                                enabled: _isEditMode,
                              ),

                              const SizedBox(height: 12),

                              // Gender & Age Status (Row)
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Gender',
                                          style: TextStyle(
                                            color: Color(0xFF616161),
                                            fontSize: 14,
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        if (_isEditMode)
                                          _buildGenderSelection()
                                        else
                                          _buildReadOnlyDropdown(_selectedGender, value: ''),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Age Status',
                                          style: TextStyle(
                                            color: Color(0xFF616161),
                                            fontSize: 14,
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        if (_isEditMode)
                                          _buildAgeStatusSelection()
                                        else
                                          _buildReadOnlyDropdown(_selectedAgeStatus, value: ''),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Group
                              _buildField(
                                label: 'Group',
                                controller: _groupController,
                                enabled: _isEditMode,
                              ),

                              const SizedBox(height: 12),

                              // Phone
                              _buildField(
                                label: 'Phone',
                                controller: _phoneController,
                                enabled: _isEditMode,
                              ),

                              const SizedBox(height: 12),

                              // Email
                              _buildField(
                                label: 'Email',
                                controller: _emailController,
                                enabled: _isEditMode,
                              ),

                              const SizedBox(height: 12),

                              // Address
                              _buildField(
                                label: 'Address',
                                controller: _addressController,
                                enabled: _isEditMode,
                              ),

                              const SizedBox(height: 12),

                              // Note
                              _buildField(
                                label: 'Note',
                                controller: _noteController,
                                enabled: _isEditMode,
                                maxLines: 3,
                              ),

                              const SizedBox(height: 12),

                              // Status Dropdown
                              _buildStatusDropdown(
                                label: 'Status',
                                value: _selectedStatus,
                                enabled: _isEditMode,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedStatus = newValue;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Deletion overlay
            if (_isDeleting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Deleting guest...',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? placeholder,
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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: placeholder,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.5),
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

  Widget _buildReadOnlyDropdown(String selectedGender, {required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: const Color(0xFFFFE100),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Row(
      children: ['Male', 'Female'].map((gender) {
        final isSelected = _selectedGender == gender;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = gender;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                gender,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAgeStatusSelection() {
    return Row(
      children: ['Adult', 'Child', 'Baby'].map((status) {
        final isSelected = _selectedAgeStatus == status;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedAgeStatus = status;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusDropdown({
    required String label,
    required String value,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    final statusOptions = ['Not Sent', 'Pending', 'Accepted', 'Rejected'];

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: enabled
              ? DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
              onChanged: onChanged,
              items: statusOptions.map<DropdownMenuItem<String>>((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Text(status),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Text(
              value,
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

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return Colors.blue.shade600;
      case 'female':
        return Colors.pink.shade400;
      default:
        return Colors.grey.shade600;
    }
  }
}