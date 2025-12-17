import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../service/event_service.dart';
import 'package:intl/intl.dart';
import '../../service/notification_service.dart';
import '../../widget/animated_gradient_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utilty/app_responsive.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _collaboratorController = TextEditingController();

  String _selectedEventType = 'General';

  DateTime? _selectedDate;
  String _selectedStatus = 'Pending';
  bool _isLoading = false;
  final List<String> _collaborators = [];

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
              .where('email', isEqualTo: identifier.trim())
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

      // Send notifikasi ke semua collaborator setelah event berhasil dibuat
      if (result['success'] && validCollaboratorIds.isNotEmpty) {
        final notificationService = NotificationService();

        String currentUsername = 'Unknown';
        try {
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            currentUsername = userDoc.data()?['username'] ?? user.displayName ?? 'Unknown';
          }
        } catch (e) {
          debugPrint('Error getting username: $e');
          currentUsername = user.displayName ?? 'Unknown';
        }

        final eventName = _nameController.text.trim();
        final eventId = result['eventId'] as String;

        debugPrint('════════════════════════════════════════');
        debugPrint('🔔 SENDING COLLABORATOR INVITES');
        debugPrint('EVENT: $eventName (ID: $eventId)');
        debugPrint('OWNER: $currentUsername (${user.uid})');
        debugPrint('COLLABORATORS: ${validCollaboratorIds.length}');
        debugPrint('════════════════════════════════════════');

        for (String collaboratorId in validCollaboratorIds) {
          try {
            await notificationService.sendNotification(
              userId: collaboratorId,
              title: 'Collaborator Invite',
              message: '$currentUsername invited you as collaborator to "$eventName"',
              type: 'event',
              relatedId: eventId,
            );
            debugPrint('✅ Notifikasi terkirim ke collaborator: $collaboratorId');
          } catch (e) {
            debugPrint('❌ Gagal kirim notif ke $collaboratorId: $e');
          }
        }
      }

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
    AppResponsive.init(context);
    final isLandscape = AppResponsive.isLandscape();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedGradientBackground(),
          ),

          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  height: isLandscape
                      ? AppResponsive.getHeight(12)
                      : AppResponsive.getHeight(11),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.responsivePadding() * 1.5,
                  ),
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
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: AppResponsive.responsiveIconSize(24),
                          ),
                        ),
                      ),
                      Text(
                        'Create an Event',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: AppResponsive.headerFontSize(),
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : _createEvent,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.save,
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.responsivePadding() * 1.5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          'Name',
                          'Type here',
                          _nameController,
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),

                        _buildEventTypeDropdown(),
                        SizedBox(height: AppResponsive.spacingMedium()),

                        _buildDateField(),
                        SizedBox(height: AppResponsive.spacingMedium()),

                        _buildTextField(
                          'Budget',
                          'Type here',
                          _budgetController,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: AppResponsive.spacingMedium()),

                        _buildTextField(
                          'Location',
                          'Type here',
                          _locationController,
                        ),
                        SizedBox(height: AppResponsive.spacingLarge()),

                        _buildCollaboratorsSection(),

                        SizedBox(height: AppResponsive.getHeight(30)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.25,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.25, 0.5, 0.9],
            builder: (context, scrollController) {
              return Container(
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppResponsive.borderRadiusLarge()),
                      topRight: Radius.circular(AppResponsive.borderRadiusLarge()),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.responsivePadding() * 1.2,
                      vertical: AppResponsive.responsivePadding() * 1.2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        SizedBox(height: AppResponsive.spacingLarge()),
                        Text(
                          'Status',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: AppResponsive.smallFontSize(),
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacingSmall()),
                        _buildStatusSelector(),
                        SizedBox(height: AppResponsive.spacingLarge()),
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
        Text(
          'Collaborators',
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),

        Container(
          padding: EdgeInsets.all(AppResponsive.spacingMedium()),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _collaborators.isEmpty
                        ? const SizedBox.shrink()
                        : Wrap(
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
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(left: AppResponsive.spacingSmall()),
                    child: Row(
                      children: [
                        if (_collaborators.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                _removeCollaborator(_collaborators.length - 1),
                            child: Icon(
                              Icons.remove_circle,
                              color: Colors.red[600],
                              size: AppResponsive.responsiveIconSize(20),
                            ),
                          ),
                        if (_collaborators.isNotEmpty)
                          SizedBox(width: AppResponsive.spacingSmall() * 0.5),
                        GestureDetector(
                          onTap: _addCollaborator,
                          child: Icon(
                            Icons.add_circle,
                            color: const Color(0xFFFFE100),
                            size: AppResponsive.responsiveIconSize(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_collaborators.isNotEmpty) SizedBox(height: AppResponsive.spacingSmall()),

              TextField(
                controller: _collaboratorController,
                decoration: InputDecoration(
                  hintText: 'Email or username',
                  hintStyle: TextStyle(
                    color: const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                    fontSize: AppResponsive.smallFontSize(),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(),
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
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.all(AppResponsive.spacingMedium()),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                fontSize: AppResponsive.smallFontSize(),
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
        Text(
          'Date',
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.all(AppResponsive.spacingMedium()),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
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
                      fontSize: AppResponsive.smallFontSize(),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: AppResponsive.responsiveIconSize(18),
                ),
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
                margin: EdgeInsets.only(bottom: AppResponsive.spacingSmall()),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.responsivePadding() * 1.5,
                      vertical: AppResponsive.spacingSmall(),
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFE100) : Colors.white,
                      border: Border.all(width: 1, color: Colors.black),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: AppResponsive.smallFontSize(),
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
        SizedBox(width: AppResponsive.spacingMedium()),
        Image.asset(
          'assets/image/AddTaskImageCat.png',
          height: AppResponsive.getHeight(12),
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
        Text(
          'Event Type',
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.smallFontSize(),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.spacingMedium(),
            vertical: AppResponsive.spacingSmall() * 0.5,
          ),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEventType,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.black,
                size: AppResponsive.responsiveIconSize(24),
              ),
              style: TextStyle(
                color: Colors.black,
                fontSize: AppResponsive.smallFontSize(),
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