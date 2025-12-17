import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/guest_model.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/animated_gradient_background.dart';

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
  bool _isDeleting = false;

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
    try {
      // Update in event subcollection
      await _firestore
          .collection('events')
          .doc(_guest.eventId)  //  Use eventId from guest model
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
        // Delete from event subcollection
        await _firestore
            .collection('events')
            .doc(_guest.eventId)  //  Use eventId from guest model
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
        debugPrint('Error deleting guest: $e');
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
    AppResponsive.init(context);

    return WillPopScope(
      onWillPop: () async {
        if (_isDeleting) return false;
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedGradientBackground(),
            ),

            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: AppResponsive.responsiveHeight(31),
                    child: Stack(
                      children: [
                        Positioned(
                          top: AppResponsive.spacingSmall(),
                          left: AppResponsive.spacingSmall(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: _isDeleting ? null : () => Navigator.pop(context, true),
                            ),
                          ),
                        ),
                        if (!_isEditMode && !_isDeleting)
                          Positioned(
                            top: AppResponsive.spacingSmall(),
                            right: AppResponsive.spacingSmall(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _deleteGuest,
                              ),
                            ),
                          ),
                        if (_isDeleting)
                          Positioned(
                            top: AppResponsive.spacingSmall(),
                            right: AppResponsive.spacingSmall(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(AppResponsive.spacingSmall() * 0.5),
                                child: SizedBox(
                                  width: AppResponsive.responsiveIconSize(24),
                                  height: AppResponsive.responsiveIconSize(24),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Center(
                            child: CircleAvatar(
                              radius: AppResponsive.avatarRadius(),
                              backgroundColor: _getGenderColor(_selectedGender),
                              child: Text(
                                _guest.name.isNotEmpty
                                    ? _guest.name[0].toUpperCase()
                                    : "?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppResponsive.responsiveFont(56),
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

                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppResponsive.borderRadiusLarge() * 2),
                      topRight: Radius.circular(AppResponsive.borderRadiusLarge() * 2),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            AppResponsive.responsivePadding() * 2.2,
                            AppResponsive.responsivePadding() * 2.6,
                            AppResponsive.responsivePadding() * 2.2,
                            AppResponsive.responsivePadding() * 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: AppResponsive.responsiveFont(25),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: AppResponsive.spacingSmall() * 0.3),
                                        Text(
                                          _selectedGender,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: AppResponsive.responsiveFont(13),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: AppResponsive.responsiveSize(0.089),
                                    height: AppResponsive.responsiveSize(0.089),
                                    decoration: BoxDecoration(
                                      color: _isEditMode ? Colors.grey[200] : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        _isEditMode ? Icons.check : Icons.edit,
                                        color: Colors.black,
                                        size: AppResponsive.responsiveIconSize(18),
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

                              SizedBox(height: AppResponsive.spacingLarge() * 2),

                              _buildField(
                                label: 'Name',
                                controller: _nameController,
                                enabled: _isEditMode,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gender',
                                          style: TextStyle(
                                            color: const Color(0xFF616161),
                                            fontSize: AppResponsive.responsiveFont(14),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: AppResponsive.spacingSmall()),
                                        if (_isEditMode)
                                          _buildGenderSelection()
                                        else
                                          _buildReadOnlyDropdown(_selectedGender),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: AppResponsive.spacingMedium()),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Age Status',
                                          style: TextStyle(
                                            color: const Color(0xFF616161),
                                            fontSize: AppResponsive.responsiveFont(14),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: AppResponsive.spacingSmall()),
                                        if (_isEditMode)
                                          _buildAgeStatusSelection()
                                        else
                                          _buildReadOnlyDropdown(_selectedAgeStatus),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              _buildField(
                                label: 'Group',
                                controller: _groupController,
                                enabled: _isEditMode,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              _buildField(
                                label: 'Phone',
                                controller: _phoneController,
                                enabled: _isEditMode,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              _buildField(
                                label: 'Email',
                                controller: _emailController,
                                enabled: _isEditMode,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              _buildField(
                                label: 'Address',
                                controller: _addressController,
                                enabled: _isEditMode,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              _buildField(
                                label: 'Note',
                                controller: _noteController,
                                enabled: _isEditMode,
                                maxLines: 3,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

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

            if (_isDeleting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha:0.3),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
                        Text(
                          'Deleting guest...',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: AppResponsive.responsiveFont(16),
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
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.spacingSmall(),
            vertical: AppResponsive.spacingSmall() * 0.9,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            minLines: 1,
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.responsiveFont(14),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: placeholder,
              hintStyle: TextStyle(
                color: Colors.black.withValues(alpha:0.5),
                fontSize: AppResponsive.responsiveFont(14),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyDropdown(String selectedValue) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.spacingSmall(),
        vertical: AppResponsive.spacingSmall() * 0.9,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: const Color(0xFFFFE100),
        ),
        borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
      ),
      child: Text(
        selectedValue,
        style: TextStyle(
          color: Colors.black,
          fontSize: AppResponsive.responsiveFont(14),
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
              margin: EdgeInsets.symmetric(horizontal: AppResponsive.spacingSmall() * 0.3),
              padding: EdgeInsets.symmetric(vertical: AppResponsive.spacingSmall() * 0.8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
              ),
              child: Text(
                gender,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: AppResponsive.responsiveFont(14),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              margin: EdgeInsets.symmetric(horizontal: AppResponsive.spacingSmall() * 0.2),
              padding: EdgeInsets.symmetric(vertical: AppResponsive.spacingSmall() * 0.6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontSize: AppResponsive.responsiveFont(12),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppResponsive.spacingSmall() * 0.2, vertical: AppResponsive.spacingSmall() * 0.3),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: enabled
              ? DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.black, size: AppResponsive.responsiveIconSize(20)),
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.responsiveFont(14),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
              onChanged: onChanged,
              items: statusOptions.map<DropdownMenuItem<String>>((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Row(
                    children: [
                      SizedBox(width: AppResponsive.spacingSmall()),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
              : Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppResponsive.spacingSmall() * 0.8,
              horizontal: AppResponsive.spacingSmall(),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.responsiveFont(14),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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