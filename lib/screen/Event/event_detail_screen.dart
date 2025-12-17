import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../service/auth_service.dart';
import '../../service/notification_service.dart';
import '../../service/notification_service.dart';
import '../../widget/animated_gradient_background.dart';
import '../../../utilty/app_responsive.dart';

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
  List<String> _collaborators = [];
  List<String> _collaboratorNames = [];
  String _selectedStatus = 'Pending';
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isDeleting = false;

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
        final collaboratorIds = List<String>.from(eventData['collaborators'] as List<dynamic>? ?? []);

        // Load collaborators usernames for editing
        List<String> collaboratorUsernames = [];
        for (String userId in collaboratorIds) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            collaboratorUsernames.add(userDoc.data()?['username'] ?? 'Unknown');
          }
        }

        // Load collaborators names for display
        await _loadCollaborators(collaboratorIds);

        setState(() {
          _event = eventData;
          _collaborators = collaboratorUsernames;
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


      final currentCollaborators = (_event!['collaborators'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [];


      final newCollaborators = validCollaboratorIds
          .where((id) => !currentCollaborators.contains(id))
          .toList();

      debugPrint('Current collaborators: $currentCollaborators');
      debugPrint('New collaborators: $newCollaborators');


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

      if (newCollaborators.isNotEmpty) {
        final notificationService = NotificationService();
        final authService = AuthService();
        final currentUser = authService.currentUser;

        String currentUsername = 'Unknown';
        if (currentUser != null) {
          try {
            final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
            if (userDoc.exists) {
              currentUsername = userDoc.data()?['username'] ?? currentUser.displayName ?? 'Unknown';
            }
          } catch (e) {
            debugPrint('Error getting username: $e');
            currentUsername = currentUser.displayName ?? 'Unknown';
          }
        }

        final eventName = _nameController.text.trim();

        for (String newCollaboratorId in newCollaborators) {
          try {
            await notificationService.sendNotification(
              userId: newCollaboratorId,
              title: 'Collaborator Invite',
              message: '$currentUsername invited you as collaborator to "$eventName"',
              type: 'event',
              relatedId: widget.eventId,
            );
            debugPrint(' Notifikasi terkirim ke collaborator: $newCollaboratorId');
          } catch (e) {
            debugPrint(' Gagal kirim notif ke $newCollaboratorId: $e');
          }
        }
      }

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
        debugPrint(' Starting event deletion for: ${widget.eventId}');

        final tasksSnapshot = await _firestore
            .collection('tasks')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('Found ${tasksSnapshot.docs.length} tasks to delete');
        for (var doc in tasksSnapshot.docs) {
          await doc.reference.delete();
        }

        final budgetsSnapshot = await _firestore
            .collection('budgets')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('💰 Found ${budgetsSnapshot.docs.length} budgets to delete');
        for (var doc in budgetsSnapshot.docs) {
          await doc.reference.delete();
        }

        final vendorsSnapshot = await _firestore
            .collection('vendors')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('🏪 Found ${vendorsSnapshot.docs.length} vendors to delete');
        for (var doc in vendorsSnapshot.docs) {
          await doc.reference.delete();
        }

        final guestsSnapshot = await _firestore
            .collection('guests')
            .where('eventId', isEqualTo: widget.eventId)
            .get();

        debugPrint('👥 Found ${guestsSnapshot.docs.length} guests to delete');
        for (var doc in guestsSnapshot.docs) {
          await doc.reference.delete();
        }

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
    AppResponsive.init(context);

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
              SizedBox(height: AppResponsive.spacingLarge()),
              const Text('Event not found'),
              SizedBox(height: AppResponsive.spacingExtraLarge()),
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
    final isLandscape = AppResponsive.isLandscape();

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
                    height: isLandscape
                        ? AppResponsive.getHeight(25)
                        : AppResponsive.getHeight(30),
                    child: Stack(
                      children: [
                        // Back Button
                        Positioned(
                          top: AppResponsive.spacingMedium(),
                          left: AppResponsive.spacingMedium(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: _isDeleting ? null : () => Navigator.pop(context),
                              iconSize: AppResponsive.responsiveIconSize(24),
                            ),
                          ),
                        ),
                        // Delete Button
                        if (!_isEditing && !_isDeleting)
                          Positioned(
                            top: AppResponsive.spacingMedium(),
                            right: AppResponsive.spacingMedium(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _deleteEvent,
                                iconSize: AppResponsive.responsiveIconSize(24),
                              ),
                            ),
                          ),
                        // Loading indicator during deletion
                        if (_isDeleting)
                          Positioned(
                            top: AppResponsive.spacingMedium(),
                            right: AppResponsive.spacingMedium(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(AppResponsive.spacingSmall()),
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
                              height: isLandscape
                                  ? AppResponsive.getHeight(20)
                                  : AppResponsive.getHeight(18),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.event,
                                  size: AppResponsive.responsiveIconSize(100),
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
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppResponsive.borderRadiusLarge()),
                      topRight: Radius.circular(AppResponsive.borderRadiusLarge()),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            AppResponsive.responsivePadding(),
                            AppResponsive.responsivePadding() * 1.5,
                            AppResponsive.responsivePadding(),
                            AppResponsive.responsivePadding(),
                          ),
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
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: AppResponsive.headerFontSize(),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: AppResponsive.spacingSmall()),
                                        Text(
                                          eventDate != null
                                              ? 'On ${DateFormat('MMMM d, yyyy').format(eventDate)}'
                                              : 'No date set',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: AppResponsive.smallFontSize(),
                                            fontFamily: 'SF Pro',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: AppResponsive.spacingMedium()),
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

                              SizedBox(height: AppResponsive.spacingExtraLarge()),

                              // Event Name Field
                              _buildField(
                                label: 'Event Name',
                                controller: _nameController,
                                enabled: _isEditing,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              // Event Type Field
                              _buildEventTypeDropdown(),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              // Date Field (Read-only)
                              _buildReadOnlyField(
                                label: 'Event Date',
                                value: eventDate != null
                                    ? DateFormat('EEEE, MMMM d, yyyy').format(eventDate)
                                    : 'No date set',
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              _buildField(
                                label: 'Event Budget',
                                controller: _budgetController,
                                enabled: _isEditing,
                                placeholder: 'e.g., 5000000',
                                keyboardType: TextInputType.number,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              // Location Field
                              _buildField(
                                label: 'Location',
                                controller: _locationController,
                                enabled: _isEditing,
                                placeholder: 'Event location',
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

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

                              SizedBox(height: AppResponsive.spacingMedium()),

                              // Collaborators Field (Editable)
                              _buildCollaboratorsField(
                                label: 'Collaborators',
                                enabled: _isEditing,
                              ),

                              SizedBox(height: AppResponsive.spacingMedium()),

                              // Save Button (only when editing)
                              if (_isEditing) ...[
                                SizedBox(height: AppResponsive.spacingExtraLarge()),
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
                                    child: Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: AppResponsive.bodyFontSize(),
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                        ),
                        SizedBox(height: AppResponsive.spacingLarge()),
                        Text(
                          'Deleting event...',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: AppResponsive.bodyFontSize(),
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.responsivePadding() * 0.8,
            vertical: AppResponsive.spacingMedium(),
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
            keyboardType: keyboardType,
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.bodyFontSize(),
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
                fontSize: AppResponsive.bodyFontSize(),
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
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.responsivePadding() * 0.8,
            vertical: AppResponsive.spacingMedium(),
          ),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.bodyFontSize(),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF616161),
              fontSize: AppResponsive.smallFontSize(),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppResponsive.spacingSmall()),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.responsivePadding() * 0.8,
              vertical: AppResponsive.spacingMedium(),
            ),
            decoration: BoxDecoration(
              border: Border.all(
                width: 2,
                color: const Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
            ),
            child: Text(
              _collaboratorNames.isEmpty
                  ? '-'
                  : _collaboratorNames.join(', '),
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.bodyFontSize(),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.all(AppResponsive.spacingMedium()),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: const Color(0xFFFFE100)),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_collaborators.isNotEmpty) ...[
                Wrap(
                  spacing: AppResponsive.spacingSmall(),
                  runSpacing: AppResponsive.spacingSmall(),
                  children: List.generate(
                    _collaborators.length,
                        (index) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.spacingSmall(),
                          vertical: AppResponsive.spacingSmall() * 0.75,
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
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: AppResponsive.extraSmallFontSize(),
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: AppResponsive.spacingSmall() * 0.5),
                            GestureDetector(
                              onTap: () => _removeCollaborator(index),
                              child: Icon(
                                Icons.close,
                                size: AppResponsive.responsiveIconSize(14),
                                color: Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: AppResponsive.spacingSmall()),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _collaboratorController,
                      decoration: InputDecoration(
                        hintText: 'Email or username',
                        hintStyle: TextStyle(
                          color: Colors.black.withValues(alpha: 0.5),
                          fontSize: AppResponsive.smallFontSize(),
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: AppResponsive.smallFontSize(),
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                      onSubmitted: (_) => _addCollaborator(),
                    ),
                  ),
                  SizedBox(width: AppResponsive.spacingSmall()),
                  GestureDetector(
                    onTap: _addCollaborator,
                    child: Icon(
                      Icons.add_circle,
                      color: const Color(0xFFFFE100),
                      size: AppResponsive.responsiveIconSize(24),
                    ),
                  ),
                ],
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
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.symmetric(vertical: AppResponsive.spacingSmall() * 0.5),
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
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.bodyFontSize(),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
              onChanged: onChanged,
              items: statusOptions.map<DropdownMenuItem<String>>((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Row(
                    children: [
                      SizedBox(
                        width: AppResponsive.spacingSmall(),
                        height: AppResponsive.spacingSmall(),
                      ),
                      SizedBox(width: AppResponsive.spacingSmall()),
                      Text(status),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
              : Padding(
            padding: EdgeInsets.symmetric(vertical: AppResponsive.spacingSmall()),
            child: Row(
              children: [
                SizedBox(
                  width: AppResponsive.spacingSmall(),
                  height: AppResponsive.spacingSmall(),
                ),
                SizedBox(width: AppResponsive.spacingSmall()),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.bodyFontSize(),
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
    final eventTypes = ['Wedding', 'Birthday', 'Corporate Event', 'Conference', 'Workshop', 'Other'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Type',
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.spacingMedium(),
            vertical: AppResponsive.spacingSmall() * 0.5,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: const Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: _isEditing
              ? DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEventType,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.bodyFontSize(),
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
                    padding: EdgeInsets.only(left: AppResponsive.spacingSmall()),
                    child: Text(eventType),
                  ),
                );
              }).toList(),
            ),
          )
              : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.spacingMedium(),
              vertical: AppResponsive.spacingSmall(),
            ),
            child: Text(
              _selectedEventType,
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.bodyFontSize(),
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
    _budgetController.dispose();
    _collaboratorController.dispose();
    super.dispose();
  }
}