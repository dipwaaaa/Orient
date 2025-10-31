import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/task_model.dart';
import '../../../widget/Animated_Gradient_Background.dart';

class IndividualTaskScreen extends StatefulWidget {
  final String taskId;

  const IndividualTaskScreen({super.key, required this.taskId});

  @override
  State<IndividualTaskScreen> createState() => _IndividualTaskScreenState();
}

class _IndividualTaskScreenState extends State<IndividualTaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  TaskModel? _task;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    try {
      final doc = await _firestore.collection('tasks').doc(widget.taskId).get();

      if (doc.exists && mounted) {
        final task = TaskModel.fromMap(doc.data()!);
        setState(() {
          _task = task;
          _nameController.text = task.name;
          _budgetController.text = task.budget != null ? 'Rp${NumberFormat('#,###', 'id_ID').format(task.budget)}' : '';
          _noteController.text = task.note ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading task: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateTask() async {
    if (_task == null) return;

    try {
      double? budgetValue;
      if (_budgetController.text.isNotEmpty) {
        String cleanedBudget = _budgetController.text
            .replaceAll('Rp', '')
            .replaceAll('.', '')
            .replaceAll(',', '')
            .trim();
        budgetValue = double.tryParse(cleanedBudget);
      }

      await _firestore.collection('tasks').doc(widget.taskId).update({
        'name': _nameController.text.trim(),
        'budget': budgetValue,
        'note': _noteController.text.isNotEmpty ? _noteController.text.trim() : null,
        'updatedAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task updated successfully!')),
        );
        setState(() {
          _isEditing = false;
        });
        _loadTask();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Task'),
        content: Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('tasks').doc(widget.taskId).delete();

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task deleted')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting task: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete task'),
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
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_task == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Task not found'),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

          return Scaffold(
            body: Stack(
                children: [
            // Animated Gradient Background untuk seluruh layar
            Positioned.fill(
            child: AnimatedGradientBackground(
            duration: Duration(seconds: 5),
            radius: 2.22,
            colors: [
              Color(0xFFFF6A00),
              Color(0xFFFFE100),
            ],
          ),
          ),

          // Konten utama
          SafeArea(
          child: Column(
          children: [
          // Top Section with Cat Image
          SizedBox(
          height: 280,
          child: Stack(
          children: [
          // Back Button
          Positioned(
          top: 16,
          left: 16,
          child: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
          ),
          ),
          // Delete Button
          if (!_isEditing)
          Positioned(
          top: 16,
          right: 16,
          child: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: _deleteTask,
          ),
          ),
          // Cat Image
          Positioned.fill(
          child: Center(
          child: Image.asset(
          'assets/image/TaskIndividualImage.png',
          height: 180,
          fit: BoxFit.contain,
          ),
          ),
          ),
          ],
          ),
          ),

          // White Content Section
          Expanded(
          child: ClipRRect(
          borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
          ),
          child: Container(
          width: double.infinity,
          color: Colors.white,
          child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(45, 43, 45, 32),
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
                                  _task!.name,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 25,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'On ${DateFormat('MMMM d, yyyy').format(_task!.dueDate)}',
                                  style: TextStyle(
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
                                    _nameController.text = _task!.name;
                                    _budgetController.text = _task!.budget != null ? 'Rp${NumberFormat('#,###', 'id_ID').format(_task!.budget)}' : '';
                                    _noteController.text = _task!.note ?? '';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 28),

                      // Task Name Field
                      _buildField(
                        label: 'Task Name',
                        controller: _nameController,
                        enabled: _isEditing,
                      ),

                      SizedBox(height: 12),

                      // Budget Field
                      _buildField(
                        label: 'Budget',
                        controller: _budgetController,
                        enabled: _isEditing,
                        placeholder: 'Not set',
                      ),

                      SizedBox(height: 12),

                      // Note Field
                      _buildField(
                        label: 'Note',
                        controller: _noteController,
                        enabled: _isEditing,
                        placeholder: '-',
                      ),

                      SizedBox(height: 12),

                      // Category Field (Read-only)
                      _buildReadOnlyField(
                        label: 'Category',
                        value: _task!.category,
                      ),

                      SizedBox(height: 12),

                      // Status Field (Read-only)
                      _buildReadOnlyField(
                        label: 'Status',
                        value: _task!.status == 'completed' ? 'Completed' : 'Pending',
                      ),

                      if (_isEditing) ...[
                        SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _updateTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFE100),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
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
    )
          ],
        ),
      ),
    ]
            )
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 7),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 19, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: TextStyle(
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
          style: TextStyle(
            color: Color(0xFF616161),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 19, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: Color(0xFFFFE100),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
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

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}