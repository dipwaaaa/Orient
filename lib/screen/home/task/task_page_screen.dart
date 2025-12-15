import 'package:flutter/material.dart';
import 'dart:async';
import 'add_task_screen.dart';
import '../../../widget/profile_menu.dart';
import '../../../widget/TaskLitWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import 'package:intl/intl.dart';

class TaskScreen extends StatefulWidget {
  final String? eventId;
  final String? eventName;

  const TaskScreen({super.key, this.eventId, this.eventName});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = 'User';
  String? _selectedEventId;
  String _selectedEventName = '';
  bool _isWeekView = true;
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  final PageController _weekPageController = PageController(initialPage: 1000);

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.eventId;
    _selectedEventName = widget.eventName ?? '';
    _loadUserData();
    if (_selectedEventId != null && _selectedEventName.isEmpty) {
      _loadEventName();
    }
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  /// Load event name dari Firestore berdasarkan event ID
  Future<void> _loadEventName() async {
    if (_selectedEventId == null) return;

    try {
      final eventDoc = await _firestore
          .collection('events')
          .doc(_selectedEventId)
          .get();

      if (eventDoc.exists && mounted) {
        setState(() {
          _selectedEventName = eventDoc.data()?['eventName'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading event name: $e');
    }
  }

  /// Load user data (username) dari Firestore
  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final userDoc = await _authService.firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          String username = userDoc.data()?['username'] ?? user.displayName ?? '';
          username = username.replaceAll(' ', '');

          if (username.isEmpty) {
            username = 'User';
          }

          setState(() {
            _username = username;
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  /// Generate list of dates untuk week view
  List<DateTime> _getWeekDates({int pageOffset = 0}) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final weekStart = startOfWeek.add(Duration(days: 7 * pageOffset));
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }

  /// Generate list of dates untuk month view
  List<DateTime> _getMonthDates() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startDate = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    List<DateTime> dates = [];
    DateTime current = startDate;

    while (dates.length < 35) {
      dates.add(current);
      current = current.add(Duration(days: 1));
    }

    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                  ),

                  // Title Section
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            DateFormat('For MMMM d, yyyy').format(DateTime.now()),
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
                  ),

                  // Notification + Avatar Section
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.022),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(screenWidth * 0.069),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Notification Icon
                        Container(
                          width: screenWidth * 0.089,
                          height: screenWidth * 0.089,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications,
                            color: Colors.white,
                            size: screenWidth * 0.069,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.022),

                        // Avatar - Tap to show ProfileMenu
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            debugPrint('Profile avatar tapped');
                            if (_authService.currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please login first')),
                              );
                              return;
                            }
                            // Open ProfileMenu
                            ProfileMenu.show(context, _authService, _username);
                          },
                          child: AvatarWidgetCompact(
                            authService: _authService,
                            username: _username,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Week Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isWeekView = true;
                      });
                    },
                    child: _buildToggleButton('Week', _isWeekView),
                  ),
                  SizedBox(width: 7),

                  // Month Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isWeekView = false;
                      });
                    },
                    child: _buildToggleButton('Month', !_isWeekView),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // ============================================================
            // CALENDAR VIEW (Week or Month)
            // ============================================================
            if (_isWeekView) _buildWeekView() else _buildMonthView(),

            // ============================================================
            // TO DO LIST SECTION
            // ============================================================
            Expanded(
              child: Container(
                decoration: _isWeekView
                    ? null
                    : BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // To Do Header + Add Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'To Do',
                            style: TextStyle(
                              color: _isWeekView ? Colors.black : Colors.white,
                              fontSize: 25,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFFFFE100),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.add, size: 25),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddTaskPage(
                                      eventId: _selectedEventId,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Task List
                    Expanded(
                      child: TaskListWidget(
                        eventId: _selectedEventId,
                        filterDate: _selectedDate,
                        showInBlackBackground: !_isWeekView,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show ProfileMenu (alternative method)
  void _showProfileMenu() {
    ProfileMenu.show(context, _authService, _username);
  }

  /// Build toggle button untuk Week/Month
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

  /// Build Week View Calendar
  Widget _buildWeekView() {
    final today = DateTime.now();

    return SizedBox(
      height: 70,
      child: PageView.builder(
        controller: _weekPageController,
        onPageChanged: (page) {
          setState(() {
            // Update UI ketika page berubah
          });
        },
        itemBuilder: (context, pageIndex) {
          final offset = pageIndex - 1000;
          final weekDates = _getWeekDates(pageOffset: offset);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekDates.map((date) {
                final isToday = date.day == today.day &&
                    date.month == today.month &&
                    date.year == today.year;
                final isSelected = date.day == _selectedDate.day &&
                    date.month == _selectedDate.month &&
                    date.year == _selectedDate.year;
                final monthShort = DateFormat('MMM').format(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.black
                            : (isSelected ? Color(0xFFFFE100) : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isToday
                              ? Colors.black
                              : (isSelected ? Color(0xFFFFE100) : Color(0xFFFFE100)),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthShort,
                            style: TextStyle(
                              color: isToday
                                  ? Color(0xFFFFE100)
                                  : (isSelected ? Colors.black : Color(0xFFFFE100)),
                              fontSize: 10,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isToday
                                  ? Color(0xFFFFE100)
                                  : (isSelected ? Colors.black : Color(0xFFFFE100)),
                              fontSize: 17,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  /// Build Month View Calendar
  Widget _buildMonthView() {
    final monthDates = _getMonthDates();
    final today = DateTime.now();
    final weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous Month Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.white),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                ),
              ),

              // Month & Year Display
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
                ),
              ),

              // Next Month Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.white),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    });
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // Week Days Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays
                .map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ))
                .toList(),
          ),

          SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
            ),
            itemCount: monthDates.length,
            itemBuilder: (context, index) {
              final date = monthDates[index];
              final isToday = date.day == today.day &&
                  date.month == today.month &&
                  date.year == today.year;
              final isSelected = date.day == _selectedDate.day &&
                  date.month == _selectedDate.month &&
                  date.year == _selectedDate.year &&
                  !isToday;
              final isCurrentMonth = date.month == _currentMonth.month;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? Color(0xFFFF6B00)
                        : (isSelected ? Color(0xFFFFE100) : Colors.transparent),
                    shape: BoxShape.rectangle,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isCurrentMonth ? Colors.black : Colors.grey,
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
                      ),
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
}