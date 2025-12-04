import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:intl/intl.dart';
import '../../../widget/Animated_Gradient_Background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/guest_model.dart';

class AddGuestScreen extends StatefulWidget {
  const AddGuestScreen({super.key});

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

  bool _isSaving = false;

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

    setState(() => _isSaving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw "User not logged in";

      final guestId = _firestore.collection('guests').doc().id;

      final guest = GuestModel(
        guestId: guestId,
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
        createdBy: user.uid,
        createdAt: DateTime.now(),
        eventInvitations: [],
      );

      await _firestore
          .collection('guests')
          .doc(guestId)
          .set(guest.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Guest added successfully!")),
        );
        Navigator.pop(context);
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
    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add a New Guest',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 25,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSaving ? null : _saveGuest,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.save, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 16),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildToggleButtons(
      List<String> options, String selected, Function(String) onSelect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: options.map((option) {
          final isSelected = selected == option;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(option),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  option,
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
      ),
    );
  }
}