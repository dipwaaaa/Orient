import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/EventService.dart';
import 'package:intl/intl.dart';
import '../../widget/Animated_Gradient_Background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _collaboratorController = TextEditingController();

  // Form state
  DateTime? _selectedDate;
  String _selectedStatus = 'Pending';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _collaboratorController.dispose();
    super.dispose();
  }

  // method untuk validasi collaborator
  Future<Map<String, dynamic>> _validateCollaborators(List<String> collaborators) async {
    List<String> validCollaboratorIds = [];
    List<String> invalidCollaborators = [];

    for (String identifier in collaborators) {
      try {
        // Cek apakah identifier adalah email atau username
        QuerySnapshot userQuery;

        // Cek berdasarkan email
        if (identifier.contains('@')) {
          userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: identifier.trim().toLowerCase())
              .limit(1)
              .get();
        } else {
          // Cek berdasarkan username
          userQuery = await _firestore
              .collection('users')
              .where('username', isEqualTo: identifier.trim())
              .limit(1)
              .get();
        }

        if (userQuery.docs.isNotEmpty) {
          // User ditemukan, ambil UID
          validCollaboratorIds.add(userQuery.docs.first.id);
        } else {
          // User tidak ditemukan
          invalidCollaborators.add(identifier);
        }
      } catch (e) {
        debugPrint('Error validating collaborator $identifier: $e');
        invalidCollaborators.add(identifier);
      }
    }

    return {
      'validIds': validCollaboratorIds,
      'invalid': invalidCollaborators,
    };
  }

// Modifikasi method _createEvent
  Future<void> _createEvent() async {
    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter event name');
      return;
    }

    if (_selectedDate == null) {
      _showErrorDialog('Please select event date');
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showErrorDialog('Please enter event location');
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      _showErrorDialog('Please login first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare collaborators list
      List<String> collaboratorInputs = [];
      if (_collaboratorController.text.trim().isNotEmpty) {
        collaboratorInputs = _collaboratorController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Validate collaborators
      List<String> validCollaboratorIds = [];
      if (collaboratorInputs.isNotEmpty) {
        final validationResult = await _validateCollaborators(collaboratorInputs);
        validCollaboratorIds = validationResult['validIds'] as List<String>;
        List<String> invalidCollaborators = validationResult['invalid'] as List<String>;

        // Jika ada collaborator yang tidak valid, tampilkan error
        if (invalidCollaborators.isNotEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showErrorDialog(
                'The following collaborators were not found:\n${invalidCollaborators.join(', ')}\n\nPlease check the username/email and try again.'
            );
          }
          return;
        }
      }

      // Pastikan owner tidak termasuk dalam collaborators
      validCollaboratorIds.remove(user.uid);

      final result = await _eventService.createEvent(
        eventName: _nameController.text.trim(),
        eventDate: _selectedDate!,
        eventType: 'General',
        eventLocation: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        ownerId: user.uid,
        collaborators: validCollaboratorIds,
      );

      if (mounted) {
        if (result['success']) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to EventListScreen
          Navigator.pop(context, true);
        } else {
          _showErrorDialog(result['error']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to create event: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          Positioned.fill(
            child: AnimatedGradientBackground(
            ),
          ),

          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _buildHeader(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildForm(),
                      const SizedBox(height: 30),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(31),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
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
                                const SizedBox(height: 7),
                                _buildStatusSelector(),
                                const SizedBox(height: 25),
                                _buildCreateButton(),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const ShapeDecoration(
                color: Color(0xFFFFE100),
                shape: OvalBorder(),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Create Event',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField(
            'Event Name',
            'Enter event name',
            _nameController,
          ),
          const SizedBox(height: 20),
          _buildDateField(),
          const SizedBox(height: 20),
          _buildTextField(
            'Event Location',
            'Enter event location',
            _locationController,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Description',
            'Add a description',
            _descriptionController,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Collaborators',
            'Add collaborators (email/username, separated by comma)',
            _collaboratorController,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      String hintText,
      TextEditingController controller, {
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 2, color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hintText,
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

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 2, color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                        : 'Select event date',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? const Color(0xFF1D1D1D)
                          : const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                      fontSize: 13,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF1D1D1D),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    final statuses = ['Pending', 'Completed'];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: statuses.map((status) {
              final isSelected = _selectedStatus == status;
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 8),
                    decoration: ShapeDecoration(
                      color: isSelected ? const Color(0xFFFFE100) : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 1, color: Colors.black),
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 10),
        Image.asset(
          'assets/image/AddTaskImageCat.png',
          height: 110,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFE100),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        )
            : const Text(
          'Create Event',
          style: TextStyle(
            fontSize: 17,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}