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
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  Map<String, dynamic>? _event;
  String? _collaboratorsText;
  String _selectedStatus = 'Pending';
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final doc = await _firestore.collection('events').doc(widget.eventId).get();

      if (doc.exists && mounted) {
        final eventData = doc.data()!;

        // Load collaborators names
        await _loadCollaborators(eventData['collaborators'] as List<dynamic>?);

        setState(() {
          _event = eventData;
          _nameController.text = eventData['eventName'] ?? '';
          _typeController.text = eventData['eventType'] ?? '';
          _descriptionController.text = eventData['description'] ?? '';
          _locationController.text = eventData['eventLocation'] ?? '';
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

  Future<void> _loadCollaborators(List<dynamic>? collaboratorIds) async {
    if (collaboratorIds == null || collaboratorIds.isEmpty) {
      setState(() {
        _collaboratorsText = '-';
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
        _collaboratorsText = names.isNotEmpty ? names.join(', ') : '-';
      });
    } catch (e) {
      debugPrint('Error loading collaborators: $e');
      setState(() {
        _collaboratorsText = '-';
      });
    }
  }

  Future<void> _updateEvent() async {
    if (_event == null) return;

    try {
      await _firestore.collection('events').doc(widget.eventId).update({
        'eventName': _nameController.text.trim(),
        'eventType': _typeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'eventLocation': _locationController.text.trim(),
        'eventStatus': _selectedStatus,
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
      try {
        // Delete related tasks
        final tasksSnapshot = await _firestore
            .collection('tasks')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        for (var doc in tasksSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete related budgets
        final budgetsSnapshot = await _firestore
            .collection('budgets')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        for (var doc in budgetsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete related vendors
        final vendorsSnapshot = await _firestore
            .collection('vendors')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        for (var doc in vendorsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete the event
        await _firestore.collection('events').doc(widget.eventId).delete();

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting event: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete event'),
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

    return Scaffold(
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
          SafeArea(
            child: Column(
              children: [
                // Top Section with Image
                Container(
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
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      // Delete Button
                      if (!_isEditing)
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
                              onPressed: _deleteEvent,
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
                            _buildField(
                              label: 'Event Type',
                              controller: _typeController,
                              enabled: _isEditing,
                              placeholder: 'e.g., Wedding, Birthday, Conference',
                            ),

                            const SizedBox(height: 12),

                            // Date Field (Read-only)
                            _buildReadOnlyField(
                              label: 'Event Date',
                              value: eventDate != null
                                  ? DateFormat('EEEE, MMMM d, yyyy').format(eventDate)
                                  : 'No date set',
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

                            // Description Field
                            _buildField(
                              label: 'Description',
                              controller: _descriptionController,
                              enabled: _isEditing,
                              placeholder: 'Event description',
                              maxLines: 3,
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

                            // Collaborators Field (Read-only)
                            _buildReadOnlyField(
                              label: 'Collaborators',
                              value: _collaboratorsText ?? 'Loading...',
                            ),

                            const SizedBox(height: 12),

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
              ],
            ),
          ),
        ],
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

  Widget _buildStatusDropdown({
    required String label,
    required String value,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    final statusOptions = ['Pending','Completed'];



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
                      Container(
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
                Container(
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

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}