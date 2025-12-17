import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../model/task_model.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/animated_gradient_background.dart';
import 'package:intl/intl.dart';

class AddTaskPage extends StatefulWidget {
  final String? eventId;

  const AddTaskPage({super.key, this.eventId});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory;
  String _selectedStatus = 'pending';
  DateTime? _selectedDate;
  String? _selectedEventId;
  String _selectedEventName = '';
  bool _isLoading = false;

  final List<String> _categories = [
    'Unassigned',
    'Attire & Accessories',
    'Food And Beverages',
    'Music & Show',
    'Flowers & Decor',
    'Photo & Video',
    'Transportation',
    'Accomodation',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.eventId;
    if (_selectedEventId != null) {
      _loadEventName();
    } else {
      _fetchUserEvent();
    }
  }

  Future<void> _loadEventName() async {
    if (_selectedEventId == null) return;

    try {
      final eventDoc = await _firestore
          .collection('events')
          .doc(_selectedEventId)
          .get();

      if (eventDoc.exists && mounted) {
        setState(() {
          _selectedEventName = eventDoc.data()?['eventName'] ?? 'Active Event';
        });
      }
    } catch (e) {
      debugPrint('Error loading event name: $e');
    }
  }

  Future<void> _fetchUserEvent() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final snapshot = await _firestore
            .collection('events')
            .where('ownerId', isEqualTo: user.uid)
            .get();

        if (snapshot.docs.isNotEmpty && mounted) {
          final events = snapshot.docs.toList();
          events.sort((a, b) {
            final dateA = (a.data()['eventDate'] as Timestamp).toDate();
            final dateB = (b.data()['eventDate'] as Timestamp).toDate();
            return dateA.compareTo(dateB);
          });

          final eventData = events.first.data();
          setState(() {
            _selectedEventId = events.first.id;
            _selectedEventName = eventData['eventName'] ?? 'Active Event';
          });

          debugPrint('Event found: ${events.first.id} - $_selectedEventName');
        } else {
          debugPrint('No events found for user: ${user.uid}');
        }
      } catch (e) {
        debugPrint('Error fetching event: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading event: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
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

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMMM d, yyyy').format(picked);
      });
    }
  }

  Future<void> _createTask() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter task name')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_selectedEventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No event found. Please create an event first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final taskId = _firestore.collection('tasks').doc().id;
      final now = DateTime.now();

      double? budgetValue;
      if (_budgetController.text.isNotEmpty) {
        budgetValue = double.tryParse(_budgetController.text.replaceAll(',', ''));
      }

      final task = TaskModel(
        taskId: taskId,
        eventId: _selectedEventId!,
        name: _nameController.text.trim(),
        category: _selectedCategory ?? 'Unassigned',
        dueDate: _selectedDate!,
        status: _selectedStatus,
        note: _noteController.text.isNotEmpty ? _noteController.text.trim() : null,
        budget: budgetValue,
        imageUrls: null,
        createdBy: user.uid,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('tasks').doc(taskId).set(task.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedGradientBackground(),
          ),

          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SizedBox(height: AppResponsive.spacingMedium()),
                    _buildHeader(),
                    SizedBox(height: AppResponsive.spacingLarge()),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildFormSection(),
                      SizedBox(height: AppResponsive.spacingLarge()),

                      Container(
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
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: AppResponsive.responsiveFont(14),
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: AppResponsive.spacingSmall()),
                                Wrap(
                                  spacing: AppResponsive.spacingSmall(),
                                  runSpacing: AppResponsive.spacingSmall(),
                                  children: _categories.map((category) {
                                    final isSelected = _selectedCategory == category;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppResponsive.responsivePadding(),
                                          vertical: AppResponsive.spacingSmall() * 0.6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFFFE100) : Colors.white,
                                          border: Border.all(width: 1, color: Colors.black),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: AppResponsive.responsiveFont(14),
                                            fontFamily: 'SF Pro',
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: AppResponsive.spacingLarge()),
                                _buildStatusSection(),
                                SizedBox(height: AppResponsive.spacingMedium()),
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

  Widget _buildStatusSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: AppResponsive.responsiveFont(14),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppResponsive.spacingSmall()),
              Wrap(
                spacing: AppResponsive.spacingSmall(),
                runSpacing: AppResponsive.spacingSmall(),
                children: ['Completed', 'Pending'].map((status) {
                  final statusValue = status.toLowerCase();
                  final isSelected = _selectedStatus == statusValue;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = statusValue;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.responsivePadding() * 1.8,
                        vertical: AppResponsive.spacingSmall() * 0.6,
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
                          fontSize: AppResponsive.responsiveFont(14),
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w500,
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
        SizedBox(width: AppResponsive.spacingMedium()),
        Image.asset(
          'assets/image/AddTaskImageCat.png',
          height: AppResponsive.responsiveHeight(12),
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding() * 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

              Text(
                'Create a Task',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: AppResponsive.responsiveFont(25),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              GestureDetector(
                onTap: _isLoading ? null : _createTask,
                child: Container(
                  width: AppResponsive.responsiveSize(0.122),
                  height: AppResponsive.responsiveSize(0.122),
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
          if (_selectedEventName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: AppResponsive.spacingSmall()),
              child: Text(
                'for $_selectedEventName',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontSize: AppResponsive.responsiveFont(13),
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding() * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Name', _nameController, 'Type here'),
          SizedBox(height: AppResponsive.spacingMedium()),
          _buildDateField(),
          SizedBox(height: AppResponsive.spacingMedium()),
          _buildTextField('Budget', _budgetController, 'Type here', keyboardType: TextInputType.number),
          SizedBox(height: AppResponsive.spacingMedium()),
          _buildTextField('Note', _noteController, 'Type here', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      String hint, {
        TextInputType? keyboardType,
        int maxLines = 1,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        Container(
          padding: EdgeInsets.all(AppResponsive.spacingSmall()),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.black),
            borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            minLines: 1,
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.responsiveFont(14),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF1D1D1D).withValues(alpha: 0.6),
                fontSize: AppResponsive.responsiveFont(13),
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
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.spacingSmall()),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.all(AppResponsive.spacingSmall()),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateController.text.isEmpty ? 'Select date' : _dateController.text,
                    style: TextStyle(
                      color: _dateController.text.isEmpty
                          ? const Color(0xFF1D1D1D).withValues(alpha: 0.6)
                          : Colors.black,
                      fontSize: AppResponsive.responsiveFont(13),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}