import 'package:flutter/material.dart';
import '../../../service/auth_service.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/animated_gradient_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/guest_model.dart';

class AddGuestScreen extends StatefulWidget {
  final String? guestId;
  final GuestModel? existingGuest;
  final String? eventId;

  const AddGuestScreen({
    super.key,
    this.guestId,
    this.existingGuest,
    this.eventId,
  });

  @override
  State<AddGuestScreen> createState() => _AddGuestScreenState();
}

class _AddGuestScreenState extends State<AddGuestScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedAgeStatus = 'Adult';
  String _selectedGuestStatus = 'Pending';

  bool _isSaving = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingGuest != null) {
      _loadExistingGuest();
      _isEditMode = true;
    }
  }

  void _loadExistingGuest() {
    final guest = widget.existingGuest!;
    _nameController.text = guest.name;
    _groupController.text = guest.group;
    _phoneNumberController.text = guest.phoneNumber ?? '';
    _emailController.text = guest.email ?? '';
    _addressController.text = guest.address ?? '';
    _noteController.text = guest.note ?? '';
    _selectedGender = guest.gender;
    _selectedAgeStatus = guest.ageStatus[0].toUpperCase() + guest.ageStatus.substring(1);
    _selectedGuestStatus = guest.status ?? 'Pending';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }


  Future<void> _saveGuest() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name is required")),
      );
      return;
    }

    // ✅ Validate eventId
    if (widget.eventId == null || widget.eventId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Event ID is missing")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw "User not logged in";

      if (_isEditMode && widget.guestId != null) {
        await _firestore
            .collection('events')
            .doc(widget.eventId!)
            .collection('guests')
            .doc(widget.guestId)
            .update({
          'name': _nameController.text.trim(),
          'gender': _selectedGender,
          'ageStatus': _selectedAgeStatus.toLowerCase(),
          'group': _groupController.text.trim().isEmpty
              ? "General"
              : _groupController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim().isEmpty
              ? null
              : _phoneNumberController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          'note': _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          'status': _selectedGuestStatus,
          'updatedAt': DateTime.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Guest updated successfully!")),
          );
          Navigator.pop(context, true);
        }
      } else {
        final guestRef = _firestore
            .collection('events')
            .doc(widget.eventId!)
            .collection('guests')
            .doc();

        final guest = GuestModel(
          guestId: guestRef.id,
          name: _nameController.text.trim(),
          gender: _selectedGender,
          ageStatus: _selectedAgeStatus.toLowerCase(),
          group: _groupController.text.trim().isEmpty
              ? "General"
              : _groupController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim().isEmpty
              ? null
              : _phoneNumberController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          status: _selectedGuestStatus,
          createdBy: user.uid,
          createdAt: DateTime.now(),
          eventId: widget.eventId!,
          eventInvitations: [],
        );

        await guestRef.set(guest.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Guest added successfully!")),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

    return Scaffold(
      body: Stack(
        children: [
          AnimatedGradientBackground(),

          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppResponsive.responsivePadding(),
                    AppResponsive.responsivePadding(),
                    AppResponsive.responsivePadding(),
                    AppResponsive.spacingMedium(),
                  ),
                  child: Row(
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
                      SizedBox(width: AppResponsive.spacingSmall()),
                      Expanded(
                        child: Text(
                          _isEditMode ? 'Edit Guest' : 'Add a New Guest',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: AppResponsive.responsiveFont(25),
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isSaving ? null : _saveGuest,
                        child: Container(
                          width: AppResponsive.responsiveSize(0.122),
                          height: AppResponsive.responsiveSize(0.122),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isSaving ? Icons.hourglass_empty : Icons.save,
                            color: Colors.white,
                            size: AppResponsive.responsiveIconSize(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.responsivePadding() * 1.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Name"),
                      _buildTextField(_nameController, "Type here"),

                      _buildSectionTitle("Gender"),
                      _buildToggleButtons(
                        ["Male", "Female"],
                        _selectedGender,
                            (value) => setState(() => _selectedGender = value),
                      ),

                      _buildSectionTitle("Age Status"),
                      _buildToggleButtons(
                        ["Adult", "Child", "Baby"],
                        _selectedAgeStatus,
                            (value) => setState(() => _selectedAgeStatus = value),
                      ),

                      _buildSectionTitle("Group"),
                      _buildTextField(_groupController, "Type here"),

                      _buildSectionTitle("Phone Number"),
                      _buildTextField(_phoneNumberController, "Type here"),

                      _buildSectionTitle("Email"),
                      _buildTextField(_emailController, "Type here"),

                      _buildSectionTitle("Address"),
                      _buildTextField(_addressController, "Type here"),

                      _buildSectionTitle("Note"),
                      _buildTextField(_noteController, "Type here", maxLines: 3),

                      SizedBox(height: AppResponsive.spacingLarge()),
                    ],
                  ),
                ),
              ),

              Expanded(
                flex: 1,
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
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guest Status',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: AppResponsive.responsiveFont(14),
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: AppResponsive.spacingMedium()),

                                Wrap(
                                  spacing: AppResponsive.spacingSmall(),
                                  runSpacing: AppResponsive.spacingSmall(),
                                  children: ['Not Sent', 'Pending', 'Accepted', 'Rejected']
                                      .map((status) {
                                    final isSelected = _selectedGuestStatus == status;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedGuestStatus = status;
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppResponsive.responsivePadding(),
                                          vertical: AppResponsive.spacingSmall() * 0.7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.white,
                                          border: Border.all(
                                            width: 1.5,
                                            color: Colors.black,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: AppResponsive.responsiveFont(13),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppResponsive.spacingMedium(),
        bottom: AppResponsive.spacingSmall(),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppResponsive.responsiveFont(14),
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint, {
        int maxLines = 1,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.spacingMedium()),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        style: TextStyle(
          color: Colors.black87,
          fontSize: AppResponsive.responsiveFont(16),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.black45,
            fontSize: AppResponsive.responsiveFont(16),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppResponsive.spacingSmall(),
            vertical: AppResponsive.spacingSmall() * 0.9,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildToggleButtons(
      List<String> options,
      String selected,
      Function(String) onSelect,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.spacingMedium()),
      child: Row(
        children: options.map((option) {
          final isSelected = selected == option;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(option),
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: AppResponsive.spacingSmall() * 0.3,
                ),
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.spacingSmall() * 0.8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  option,
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
      ),
    );
  }
}