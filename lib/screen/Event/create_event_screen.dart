import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/event_service.dart';
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
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _collaboratorController = TextEditingController();

  String _selectedEventType = 'General';

  // Form state
  DateTime? _selectedDate;
  String _selectedStatus = 'Pending';
  bool _isLoading = false;
  List<String> _collaborators = []; // List of collaborator identifiers

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    _collaboratorController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _validateCollaborators(List<String> collaborators) async {
    List<String> validCollaboratorIds = [];
    List<String> invalidCollaborators = [];

    for (String identifier in collaborators) {
      try {
        QuerySnapshot userQuery;

        if (identifier.contains('@')) {
          userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: identifier.trim().toLowerCase())
              .limit(1)
              .get();
        } else {
          userQuery = await _firestore
              .collection('users')
              .where('username', isEqualTo: identifier.trim())
              .limit(1)
              .get();
        }

        if (userQuery.docs.isNotEmpty) {
          validCollaboratorIds.add(userQuery.docs.first.id);
        } else {
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

  void _addCollaborator() {
    final collaborator = _collaboratorController.text.trim();

    if (collaborator.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email or username')),
      );
      return;
    }

    if (_collaborators.contains(collaborator)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborator already added')),
      );
      return;
    }

    setState(() {
      _collaborators.add(collaborator);
      _collaboratorController.clear();
    });
  }

  void _removeCollaborator(int index) {
    setState(() {
      _collaborators.removeAt(index);
    });
  }

  Future<void> _createEvent() async {
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
      List<String> validCollaboratorIds = [];

      if (_collaborators.isNotEmpty) {
        final validationResult = await _validateCollaborators(_collaborators);
        validCollaboratorIds = validationResult['validIds'] as List<String>;
        List<String> invalidCollaborators = validationResult['invalid'] as List<String>;

        if (invalidCollaborators.isNotEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showErrorDialog(
              'The following collaborators were not found:\n${invalidCollaborators.join(', ')}\n\nPlease check the username/email and try again.',
            );
          }
          return;
        }
      }

      validCollaboratorIds.remove(user.uid);

      // Parse budget dengan benar
      double budgetValue = 0.0;
      if (_budgetController.text.trim().isNotEmpty) {
        budgetValue = double.tryParse(_budgetController.text.trim()) ?? 0.0;
      }

      final result = await _eventService.createEvent(
        eventName: _nameController.text.trim(),
        eventDate: _selectedDate!,
        eventType: _selectedEventType,
        eventLocation: _locationController.text.trim(),
        description: '',
        ownerId: user.uid,
        collaborators: validCollaboratorIds,
        budget: budgetValue,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
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
            child: AnimatedGradientBackground(),
          ),

          // Main Content (Header + Form in Column)
          Column(
            children: [
              // Header dengan SafeArea
              SafeArea(
                bottom: false,
                child: Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close Button
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
                      // Title
                      const Text(
                        'Create an Event',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 25,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      // Save Button
                      GestureDetector(
                        onTap: _isLoading ? null : _createEvent,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.save,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Form Section (Scrollable)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          'Name',
                          'Type here',
                          _nameController,
                        ),
                        const SizedBox(height: 15),

                        _buildEventTypeDropdown(),
                        const SizedBox(height: 15),

                        _buildDateField(),
                        const SizedBox(height: 15),

                        _buildTextField(
                          'Budget',
                          'Type here',
                          _budgetController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 15),

                        _buildTextField(
                          'Location',
                          'Type here',
                          _locationController,
                        ),
                        const SizedBox(height: 20),

                        // Collaborators Section
                        _buildCollaboratorsSection(),

                        const SizedBox(height: 280),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Status Section (Draggable Bottom Sheet) - Positioned in Stack
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.25,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.25, 0.5, 0.9],
            builder: (context, scrollController) {
              return Container(
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
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 31),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collaborators',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),

        // Field container yang memanjang dengan collaborators di dalam
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Collaborators chips + buttons (atas)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collaborators chips (left side)
                  Expanded(
                    child: _collaborators.isEmpty
                        ? const SizedBox.shrink()
                        : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(
                        _collaborators.length,
                            (index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE100),
                              border: Border.all(
                                width: 1,
                                color: Colors.black,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _collaborators[index],
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeCollaborator(index),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Buttons on the right (atas)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        // Remove button (-)
                        if (_collaborators.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                _removeCollaborator(_collaborators.length - 1),
                            child: Icon(
                              Icons.remove_circle,
                              color: Colors.red[600],
                              size: 20,
                            ),
                          ),
                        if (_collaborators.isNotEmpty)
                          const SizedBox(width: 4),
                        // Add button (+)
                        GestureDetector(
                          onTap: _addCollaborator,
                          child: const Icon(
                            Icons.add_circle,
                            color: Color(0xFFFFE100),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Spacing
              if (_collaborators.isNotEmpty) const SizedBox(height: 8),

              // Input field (bawah)
              TextField(
                controller: _collaboratorController,
                decoration: InputDecoration(
                  hintText: 'Email or username',
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      String label,
      String hintText,
      TextEditingController controller, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                        : 'Type here',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.black
                          : const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                      fontSize: 13,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    final statuses = ['Completed', 'Pending'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFE100) : Colors.white,
                      border: Border.all(width: 1, color: Colors.black),
                      borderRadius: BorderRadius.circular(25),
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

  Widget _buildEventTypeDropdown() {
    final eventTypes = ['General', 'Wedding', 'Birthday', 'Conference', 'Corporate', 'Celebration', 'Other'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Type',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEventType,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 24),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedEventType = newValue;
                  });
                }
              },
              items: eventTypes.map<DropdownMenuItem<String>>((String eventType) {
                return DropdownMenuItem<String>(
                  value: eventType,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(eventType),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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