import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:untitled/widget/Animated_Gradient_Background.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  String _selectedEventType = 'General';
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _collaboratorController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();


  Map<String, dynamic>? _event;
  List<String> _collaborators = []; // List of collaborator identifiers
  List<String> _collaboratorNames = []; // List of collaborator names
  String _selectedStatus = 'Pending';
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return 'Rp0';
    return 'Rp${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => '.',
    )}';
  }

  Future<void> _loadEvent() async {
    try {
      final doc = await _firestore.collection('events').doc(widget.eventId).get();

      if (doc.exists && mounted) {
        final eventData = doc.data()!;
        final collaboratorIds = List<String>.from(eventData['collaborators'] as List<dynamic>? ?? []);

        // Load collaborators names
        await _loadCollaborators(collaboratorIds);

        setState(() {
          _event = eventData;
          _collaborators = collaboratorIds;
          _nameController.text = eventData['eventName'] ?? '';
          _selectedEventType = eventData['eventType'] ?? 'General';
          _descriptionController.text = eventData['description'] ?? '';
          _locationController.text = eventData['eventLocation'] ?? '';
          _budgetController.text = (eventData['budget'] ?? 0.0).toString();
          _selectedStatus = eventData['eventStatus'] ?? 'Pending';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading event: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCollaborators(List<String> collaboratorIds) async {
    if (collaboratorIds.isEmpty) {
      setState(() {
        _collaboratorNames = [];
      });
      return;
    }

    try {
      List<String> names = [];
      for (String userId in collaboratorIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          names.add(userDoc.data()?['username'] ?? 'Unknown');
        }
      }

      setState(() {
        _collaboratorNames = names;
      });
    } catch (e) {
      debugPrint('Error loading collaborators: $e');
      setState(() {
        _collaboratorNames = List.filled(collaboratorIds.length, 'Unknown');
      });
    }
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

  Future<void> _updateEvent() async {
    if (_event == null) return;

    try {
      // Validate collaborators
      List<String> validCollaboratorIds = [];

      if (_collaborators.isNotEmpty) {
        final validationResult = await _validateCollaborators(_collaborators);
        validCollaboratorIds = validationResult['validIds'] as List<String>;
        List<String> invalidCollaborators = validationResult['invalid'] as List<String>;

        if (invalidCollaborators.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'The following collaborators were not found:\n${invalidCollaborators.join(', ')}\n\nPlease check the username/email and try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      double budgetValue = 0.0;
      if (_budgetController.text.trim().isNotEmpty) {
        budgetValue = double.tryParse(_budgetController.text.trim()) ?? 0.0;
      }

      await _firestore.collection('events').doc(widget.eventId).update({
        'eventName': _nameController.text.trim(),
        'eventType': _selectedEventType,
        'description': _descriptionController.text.trim(),
        'eventLocation': _locationController.text.trim(),
        'eventStatus': _selectedStatus,
        'budget': budgetValue,
        'collaborators': validCollaboratorIds,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        setState(() {
          _isEditing = false;
        });
        _loadEvent();
      }
    } catch (e) {
      debugPrint('Error updating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update event'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event? This will also delete all associated tasks, budgets, and vendors.'),
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
        debugPrint('🗑️ Starting event deletion for: ${widget.eventId}');

        // Delete related tasks
        final tasksSnapshot = await _firestore
            .collection('tasks')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('📋 Found ${tasksSnapshot.docs.length} tasks to delete');
        for (var doc in tasksSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete related budgets
        final budgetsSnapshot = await _firestore
            .collection('budgets')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('💰 Found ${budgetsSnapshot.docs.length} budgets to delete');
        for (var doc in budgetsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete related vendors
        final vendorsSnapshot = await _firestore
            .collection('vendors')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('🏪 Found ${vendorsSnapshot.docs.length} vendors to delete');
        for (var doc in vendorsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete related guests
        final guestsSnapshot = await _firestore
            .collection('guests')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('👥 Found ${guestsSnapshot.docs.length} guests to delete');
        for (var doc in guestsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete the event
        debugPrint('📅 Deleting event: ${widget.eventId}');
        await _firestore.collection('events').doc(widget.eventId).delete();

        debugPrint('✅ Event deleted successfully');

        if (mounted) {
          setState(() => _isDeleting = false);
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on FirebaseException catch (e) {
        debugPrint('❌ Firebase Error: ${e.code} - ${e.message}');
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permission denied: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error deleting event: $e');
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete event: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
          ),
        ),
      );
    }

    if (_event == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Event not found'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final eventDate = (_event!['eventDate'] as Timestamp?)?.toDate();

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
              child: AnimatedGradientBackground(
                duration: const Duration(seconds: 5),
                radius: 2.22,
                colors: const [
                  Color(0xFFFF6A00),
                  Color(0xFFFFE100),
                ],
              ),
            ),

            // Main Content
            Column(
              children: [
                // Top Section with Image dan SafeArea
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
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: _isDeleting ? null : () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        // Delete Button
                        if (!_isEditing && !_isDeleting)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _deleteEvent,
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
                                color: Colors.white.withValues(alpha: 0.9),
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
                        // Event Image
                        Positioned.fill(
                          child: Center(
                            child: Image.asset(
                              'assets/image/TaskDetailImage.png',
                              height: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.event,
                                  size: 100,
                                  color: Colors.white,
                                );
                              },
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
                                          _event!['eventName'] ?? 'Unnamed Event',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 25,
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          eventDate != null
                                              ? 'On ${DateFormat('MMMM d, yyyy').format(eventDate)}'
                                              : 'No date set',
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
                                      color: _isEditing ? Colors.grey[200] : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        _isEditing ? Icons.close : Icons.edit,
                                        color: Colors.black,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = !_isEditing;
                                          if (!_isEditing) {
                                            _loadEvent();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              // Event Name Field
                              _buildField(
                                label: 'Event Name',
                                controller: _nameController,
                                enabled: _isEditing,
                              ),

                              const SizedBox(height: 12),

                              // Event Type Field

                                _buildEventTypeDropdown(),


                              const SizedBox(height: 12),

                              // Date Field (Read-only)
                              _buildReadOnlyField(
                                label: 'Event Date',
                                value: eventDate != null
                                    ? DateFormat('EEEE, MMMM d, yyyy').format(eventDate)
                                    : 'No date set',
                              ),

                              const SizedBox(height: 12),

                              _buildField(
                                label: 'Event Budget',
                                controller: _budgetController,
                                enabled: _isEditing,
                                placeholder: 'e.g., 5000000',
                                keyboardType: TextInputType.number,
                              ),

                              const SizedBox(height: 12),

                              // Location Field
                              _buildField(
                                label: 'Location',
                                controller: _locationController,
                                enabled: _isEditing,
                                placeholder: 'Event location',
                              ),

                              const SizedBox(height: 12),

                              // Event Status Dropdown
                              _buildStatusDropdown(
                                label: 'Event Status',
                                value: _selectedStatus,
                                enabled: _isEditing,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedStatus = newValue;
                                    });
                                  }
                                },
                              ),

                              const SizedBox(height: 12),

                              // Collaborators Field (Editable)
                              _buildCollaboratorsField(
                                label: 'Collaborators',
                                enabled: _isEditing,
                              ),

                              const SizedBox(height: 12),

                              // Save Button (only when editing)
                              if (_isEditing) ...[
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _updateEvent,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFE100),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontFamily: 'SF Pro',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Deleting event...',
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
    TextInputType keyboardType = TextInputType.text, // ✨ NEW
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
            keyboardType: keyboardType, // ✨ NEW
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
                color: Colors.black.withValues(alpha: 0.5),
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

  Widget _buildReadOnlyField({
    required String label,
    required String value,
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
        ),
      ],
    );
  }

  Widget _buildCollaboratorsField({
    required String label,
    required bool enabled,
  }) {
    if (!enabled) {
      // Read-only mode
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
              _collaboratorNames.isEmpty
                  ? '-'
                  : _collaboratorNames.join(', '),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    // Editable mode
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: const Color(0xFFFFE100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Collaborators chips + buttons
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

                  // Buttons on the right (top)
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

              // Input field (bottom)
              TextField(
                controller: _collaboratorController,
                decoration: InputDecoration(
                  hintText: 'Email or username',
                  hintStyle: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown({
    required String label,
    required String value,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    final statusOptions = ['Pending', 'Completed'];

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
                      const SizedBox(
                        width: 12,
                        height: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(status),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isEditing
              ? DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEventType,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
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
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(eventType),
                  ),
                );
              }).toList(),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              _selectedEventType,
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


  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose(); // ✨ NEW
    _collaboratorController.dispose();
    super.dispose();
  }
}