import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../model/task_model.dart';
import '../screen/home/task/IndividualTaskScreen.dart';

class TaskListWidget extends StatelessWidget {
  final String? eventId;
  final DateTime? filterDate;
  final bool showInBlackBackground;
  final int? maxItems;
  final bool hideCompletedInHome;

  const TaskListWidget({
    super.key,
    this.eventId,
    this.filterDate,
    this.showInBlackBackground = false,
    this.maxItems,
    this.hideCompletedInHome = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTasksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                showInBlackBackground ? Color(0xFFFFE100) : Colors.black,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading tasks',
              style: TextStyle(
                color: showInBlackBackground ? Colors.white : Colors.black,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final tasks = snapshot.data!.docs
            .map((doc) => TaskModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        var filteredTasks = _filterTasksByDate(tasks);

        // Hide completed tasks in HomeScreen if hideCompletedInHome is true
        if (hideCompletedInHome) {
          filteredTasks = filteredTasks.where((task) => task.status != 'completed').toList();
        }

        if (filteredTasks.isEmpty) {
          return _buildEmptyState();
        }

        // Limit tasks if maxItems is specified
        final displayTasks = maxItems != null && maxItems! < filteredTasks.length
            ? filteredTasks.take(maxItems!).toList()
            : filteredTasks;

        return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: displayTasks.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildTaskCard(context, displayTasks[index], filteredTasks.length);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getTasksStream() {
    Query query = FirebaseFirestore.instance.collection('tasks');

    if (eventId != null) {
      query = query.where('eventId', isEqualTo: eventId);
    }

    return query.snapshots();
  }

  List<TaskModel> _filterTasksByDate(List<TaskModel> tasks) {
    tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (filterDate == null) return tasks;

    return tasks.where((task) {
      return task.dueDate.year == filterDate!.year &&
          task.dueDate.month == filterDate!.month &&
          task.dueDate.day == filterDate!.day;
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: showInBlackBackground ? Colors.white.withOpacity(0.5) : Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No tasks yet',
              style: TextStyle(
                color: showInBlackBackground ? Colors.white : Colors.grey,
                fontSize: 16,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskStatus(BuildContext context, TaskModel task) async {
    try {
      final newStatus = task.status == 'completed' ? 'pending' : 'completed';

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.taskId)
          .update({
        'status': newStatus,
        'updatedAt': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'completed' ? 'Task completed!' : 'Task reopened'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task, int totalTasks) {
    final isCompleted = task.status == 'completed';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualTaskScreen(taskId: task.taskId),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Stop propagation to parent GestureDetector
                    _toggleTaskStatus(context, task);
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? Color(0xFFFF6A00) : Colors.black.withOpacity(0.3),
                        width: 2,
                      ),
                      color: isCompleted ? Color(0xFFFF6A00) : Colors.transparent,
                    ),
                    child: isCompleted
                        ? Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                        : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MM/dd/yyyy').format(task.dueDate),
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: isCompleted ? 1.0 : 0.0,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFFFFE100),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${isCompleted ? 100 : 0}% completed',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${isCompleted ? 1 : 0} out of 1',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskProgressWidget extends StatelessWidget {
  final String? eventId;

  const TaskProgressWidget({super.key, this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTasksStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final tasks = snapshot.data!.docs
            .map((doc) => TaskModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        if (tasks.isEmpty) {
          return SizedBox.shrink();
        }

        final totalTasks = tasks.length;
        final completedTasks = tasks.where((task) => task.status == 'completed').length;
        final percentage = (completedTasks / totalTasks * 100).round();

        return Container(
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFFFFE100),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Task Progress',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completedTasks / totalTasks,
                  backgroundColor: Colors.black.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  minHeight: 8,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '$completedTasks of $totalTasks tasks completed',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 12,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getTasksStream() {
    Query query = FirebaseFirestore.instance.collection('tasks');

    if (eventId != null) {
      query = query.where('eventId', isEqualTo: eventId);
    }

    return query.snapshots();
  }
}