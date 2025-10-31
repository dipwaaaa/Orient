import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../model/task_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';
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
      _loadEventName(); // Load nama event jika eventId sudah ada
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
        // Ambil semua events milik user tanpa orderBy untuk menghindari masalah index
        final snapshot = await _firestore
            .collection('events')
            .where('ownerId', isEqualTo: user.uid)
            .get();

        if (snapshot.docs.isNotEmpty && mounted) {
          // Sort manual di client side
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

      // Parse budget value
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated Gradient Background
          Positioned.fill(
            child: AnimatedGradientBackground(
            ),
          ),

          // Content
          Column(
            children: [
              // Header dengan SafeArea
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 25),
                  ],
                ),
              ),

              // Form dan Category dengan scroll
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildFormSection(),
                      const SizedBox(height: 24),

                      // Category Section
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 31),
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
                                  'Category',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: _categories.map((category) {
                                    final isSelected = _selectedCategory == category;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFFFE100) : Colors.white,
                                          border: Border.all(width: 1, color: Colors.black),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'SF Pro',
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 25),
                                _buildStatusSection(),
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

// Method untuk status section
  Widget _buildStatusSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Wrap(
                spacing: 7,
                runSpacing: 7,
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
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFE100) : Colors.white,
                        border: Border.all(width: 1, color: Colors.black),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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

// Method untuk create button
  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createTask,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading ? Colors.grey : const Color(0xFFFFE100),
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
          'Create Task',
          style: TextStyle(
            fontSize: 17,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 51),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Create a Task',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 25,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          if (_selectedEventName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'for $_selectedEventName',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 51),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Name', _nameController, 'Type here'),
          const SizedBox(height: 15),
          _buildDateField(),
          const SizedBox(height: 15),
          _buildTextField('Budget', _budgetController, 'Type here', keyboardType: TextInputType.number),
          const SizedBox(height: 15),
          _buildTextField('Note', _noteController, 'Type here', maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
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
              hintText: hint,
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
                    _dateController.text.isEmpty ? 'Select date' : _dateController.text,
                    style: TextStyle(
                      color: _dateController.text.isEmpty
                          ? const Color(0xFF1D1D1D).withValues(alpha: 0.6)
                          : Colors.black,
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



  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}