import 'package:flutter/material.dart';
import '../../../widget/NavigationBar.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  int _currentIndex = 0; // 0 karena Task adalah index pertama

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Today's Tasks",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'For September 1st, 2025',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 24),

                // Week/Month Toggle
                Row(
                  children: [
                    _buildToggleButton('Week', true),
                    SizedBox(width: 7),
                    _buildToggleButton('Month', false),
                  ],
                ),

                SizedBox(height: 24),

                // Calendar Week View
                // Add your calendar implementation here

                SizedBox(height: 32),

                // To Do Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'To Do',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 25,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, size: 31),
                      onPressed: () {
                        // Add task functionality
                      },
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Task List
                _buildTaskItem('Buy Cake', '01/09/2025', false),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onIndexChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // Navigate based on index
          if (index == 1) {
            Navigator.pop(context); // Back to HomeScreen
          }
        },
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected) {
    return Container(
      width: 75,
      height: 30,
      decoration: ShapeDecoration(
        color: isSelected ? Color(0xFFFFE100) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: Colors.black),
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(String title, String date, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: ShapeDecoration(
            color: isCompleted ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1.5, color: Colors.black),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(width: 5),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          date,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}