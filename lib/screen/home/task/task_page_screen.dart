import 'package:flutter/material.dart';
import 'dart:async';
import 'add_task_screen.dart';
import '../../../widget/profile_menu.dart';
import '../../../widget/TaskLitWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../utilty/app_responsive.dart';
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

  List<DateTime> _getWeekDates({int pageOffset = 0}) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final weekStart = startOfWeek.add(Duration(days: 7 * pageOffset));
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }

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
    AppResponsive.init(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppResponsive.spacingMedium()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: AppResponsive.responsiveSize(0.1),
                      height: AppResponsive.responsiveSize(0.1),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.black,
                        size: AppResponsive.responsiveIconSize(28),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: AppResponsive.spacingSmall()),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Tasks",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: AppResponsive.responsiveFont(25),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppResponsive.spacingSmall() * 0.3),
                          Text(
                            DateFormat('For MMMM d, yyyy').format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: AppResponsive.responsiveFont(13),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.all(AppResponsive.spacingSmall()),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadiusLarge()),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: AppResponsive.notificationIconSize(),
                          height: AppResponsive.notificationIconSize(),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications,
                            color: Colors.white,
                            size: AppResponsive.responsiveIconSize(20),
                          ),
                        ),
                        SizedBox(width: AppResponsive.spacingSmall()),

                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            debugPrint('Profile avatar tapped');
                            if (_authService.currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please login first')),
                              );
                              return;
                            }
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
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isWeekView = true;
                      });
                    },
                    child: _buildToggleButton('Week', _isWeekView),
                  ),
                  SizedBox(width: AppResponsive.spacingSmall()),

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

            SizedBox(height: AppResponsive.spacingLarge()),
            if (_isWeekView) _buildWeekView() else _buildMonthView(),
            Expanded(
              child: Container(
                decoration: _isWeekView
                    ? null
                    : BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppResponsive.borderRadiusLarge()),
                    topRight: Radius.circular(AppResponsive.borderRadiusLarge()),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.spacingMedium(),
                        vertical: AppResponsive.spacingMedium(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'To Do',
                            style: TextStyle(
                              color: _isWeekView ? Colors.black : Colors.white,
                              fontSize: AppResponsive.responsiveFont(25),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Container(
                            width: AppResponsive.responsiveSize(0.122),
                            height: AppResponsive.responsiveSize(0.122),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE100),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.add,
                                size: AppResponsive.responsiveIconSize(25),
                              ),
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


  Widget _buildToggleButton(String label, bool isSelected) {
    return Container(
      width: AppResponsive.responsiveWidth(18),
      height: AppResponsive.responsiveHeight(3.5),
      decoration: ShapeDecoration(
        color: isSelected ? const Color(0xFFFFE100) : Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Colors.black),
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: AppResponsive.responsiveFont(14),
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildWeekView() {
    final today = DateTime.now();

    return SizedBox(
      height: AppResponsive.responsiveHeight(8),
      child: PageView.builder(
        controller: _weekPageController,
        onPageChanged: (page) {
          setState(() {
          });
        },
        itemBuilder: (context, pageIndex) {
          final offset = pageIndex - 1000;
          final weekDates = _getWeekDates(pageOffset: offset);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: AppResponsive.spacingMedium()),
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
                      margin: EdgeInsets.symmetric(horizontal: AppResponsive.spacingSmall() * 0.2),
                      padding: EdgeInsets.symmetric(vertical: AppResponsive.spacingSmall() * 0.6),
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.black
                            : (isSelected ? const Color(0xFFFFE100) : Colors.white),
                        borderRadius: BorderRadius.circular(AppResponsive.borderRadiusMedium()),
                        border: Border.all(
                          color: isToday
                              ? Colors.black
                              : (isSelected ? const Color(0xFFFFE100) : const Color(0xFFFFE100)),
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
                                  ? const Color(0xFFFFE100)
                                  : (isSelected ? Colors.black : const Color(0xFFFFE100)),
                              fontSize: AppResponsive.responsiveFont(10),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppResponsive.spacingSmall() * 0.2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isToday
                                  ? const Color(0xFFFFE100)
                                  : (isSelected ? Colors.black : const Color(0xFFFFE100)),
                              fontSize: AppResponsive.responsiveFont(17),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

  Widget _buildMonthView() {
    final monthDates = _getMonthDates();
    final today = DateTime.now();
    final weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.spacingMedium()),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: AppResponsive.responsiveSize(0.1),
                  height: AppResponsive.responsiveSize(0.1),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_left, color: Colors.white, size: AppResponsive.responsiveIconSize(20)),
                    iconSize: AppResponsive.responsiveIconSize(20),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      });
                    },
                  ),
                ),

                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.responsiveFont(16),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                Container(
                  width: AppResponsive.responsiveSize(0.1),
                  height: AppResponsive.responsiveSize(0.1),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_right, color: Colors.white, size: AppResponsive.responsiveIconSize(20)),
                    iconSize: AppResponsive.responsiveIconSize(20),
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

            SizedBox(height: AppResponsive.spacingSmall()),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays
                  .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.responsiveFont(12),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ))
                  .toList(),
            ),

            SizedBox(height: AppResponsive.spacingSmall()),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: AppResponsive.spacingSmall(),
                crossAxisSpacing: AppResponsive.spacingSmall() * 0.4,
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
                          ? const Color(0xFFFF6B00)
                          : (isSelected ? const Color(0xFFFFE100) : Colors.transparent),
                      shape: BoxShape.rectangle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isCurrentMonth ? Colors.black : Colors.grey,
                          fontSize: AppResponsive.responsiveFont(14),
                          fontFamily: 'SF Pro',
                          fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}