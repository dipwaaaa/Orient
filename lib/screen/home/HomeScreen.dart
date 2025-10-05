import 'package:flutter/material.dart';
import 'dart:async';
import 'package:untitled/service/auth_service.dart';
import '../../widget/Animated_Gradient_Background.dart';
import '../../widget/NavigationBar.dart';
import '../../widget/ProfileMenu.dart';
import '../../widget/TaskLitWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task/TaskPageScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = 'User';
  int _currentIndex = 1;

  DateTime? _currentEventDate;
  String _currentEventName = 'No Active Event';
  String? _currentEventId;
  Timer? _countdownTimer;
  StreamSubscription<QuerySnapshot>? _eventSubscription;

  final ValueNotifier<Map<String, int>> _countdownNotifier =
  ValueNotifier({'days': 0, 'hours': 0});

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToEvents();

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentEventDate != null) {
        final now = DateTime.now();
        final difference = _currentEventDate!.difference(now);
        final newDays = difference.inDays.clamp(0, 999);
        final newHours = (difference.inHours % 24).clamp(0, 23);

        if (_countdownNotifier.value['days'] != newDays ||
            _countdownNotifier.value['hours'] != newHours) {
          _countdownNotifier.value = {
            'days': newDays,
            'hours': newHours,
          };
        }
      }
    });
  }

  void _listenToEvents() {
    final user = _authService.currentUser;

    if (user == null) {
      return;
    }

    _eventSubscription = _firestore
        .collection('events')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {

      if (!mounted) {
        return;
      }

      if (snapshot.docs.isEmpty) {
        setState(() {
          _currentEventDate = null;
          _currentEventName = 'No Active Event';
          _currentEventId = null;
        });
        _countdownNotifier.value = {'days': 0, 'hours': 0};
        return;
      }

      final events = snapshot.docs.toList();

      events.sort((a, b) {
        final dateA = (a.data()['eventDate'] as Timestamp).toDate();
        final dateB = (b.data()['eventDate'] as Timestamp).toDate();
        return dateA.compareTo(dateB);
      });

      final eventData = events.first.data();
      final eventName = eventData['eventName'] ?? 'Active Event';
      final Timestamp timestamp = eventData['eventDate'];
      final eventDate = timestamp.toDate();
      final eventId = events.first.id;

      if (_currentEventDate != eventDate || _currentEventName != eventName) {
        setState(() {
          _currentEventDate = eventDate;
          _currentEventName = eventName;
          _currentEventId = eventId;
        });

        final now = DateTime.now();
        final difference = eventDate.difference(now);
        _countdownNotifier.value = {
          'days': difference.inDays.clamp(0, 999),
          'hours': (difference.inHours % 24).clamp(0, 23),
        };
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _eventSubscription?.cancel();
    _countdownNotifier.dispose();
    super.dispose();
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
            username = _generateRandomUsername();
          }

          setState(() {
            _username = username;
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  String _generateRandomUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String username = '';

    for (int i = 0; i < 8; i++) {
      username += chars[(random + i) % chars.length];
    }

    return username;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              SizedBox(height: 24),
              _buildCarousel(screenWidth),
              SizedBox(height: 16),
              _buildFeatureButtons(),
              SizedBox(height: 24),
              if (_currentEventId != null)
                _buildTaskSection(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onIndexChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildTaskSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TaskScreen()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TaskListWidget(
            eventId: _currentEventId,
            maxItems: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(double screenWidth) {
    final cardWidth = screenWidth * 0.85;
    final cardHeight = 189.0;

    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: _countdownNotifier,
      builder: (context, countdown, child) {
        if (_currentEventDate == null) {
          return _buildEmptyCarousel(cardWidth, cardHeight);
        }

        return _buildEventCarousel(
          cardWidth,
          cardHeight,
          _currentEventName,
          countdown['days']!,
          countdown['hours']!,
        );
      },
    );
  }

  Widget _buildEmptyCarousel(double cardWidth, double cardHeight) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedGradientBackground(
        duration: Duration(seconds: 5),
        radius: 1.5,
        colors: [
          Color(0xFFFFE100),
          Color(0xFFFF6A00),
        ],
        child: Stack(
          children: [
            Positioned(
              left: 16,
              top: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No Active Event",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '00',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w700,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        'DAYS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '00',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w700,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        'HOURS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              bottom: 16,
              child: Container(
                width: cardWidth * 0.70,
                child: _buildIllustration(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCarousel(
      double cardWidth,
      double cardHeight,
      String eventName,
      int days,
      int hours,
      ) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedGradientBackground(
        duration: Duration(seconds: 5),
        radius: 1.5,
        colors: [
          Color(0xFFFFE100),
          Color(0xFFFF6A00),
        ],
        child: Stack(
          children: [
            Positioned(
              left: 16,
              top: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: cardWidth * 0.4),
                    child: Text(
                      eventName,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        days.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w700,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        'DAYS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hours.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w700,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        'HOURS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              bottom: 16,
              child: Container(
                width: cardWidth * 0.70,
                child: _buildIllustration(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: AssetImage('assets/image/CarouselImage.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $_username!',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'What event are you planning today?',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32.5,
                  height: 32.5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _showProfileMenu,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFDEF3FF),
                    ),
                    child: ClipOval(
                      child: _authService.currentUser?.photoURL != null
                          ? Image.network(
                        _authService.currentUser!.photoURL!,
                        fit: BoxFit.cover,
                      )
                          : Image.asset(
                        'assets/image/AvatarKimmy.png',
                        fit: BoxFit.cover,
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

  void _showProfileMenu() {
    ProfileMenu.show(context, _authService, _username);
  }

  String? _pressedButton;

  Widget _buildFeatureButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonTask.png',
            label: 'Task',
            color: Color(0xFFFFE100),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskScreen()),
              );
            },
          ),
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonVendor.png',
            label: 'Vendor',
            color: Color(0xFFFFE100),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Vendor management coming soon!')),
              );
            },
          ),
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonBudget.png',
            label: 'Budget',
            color: Color(0xFFFFE100),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Budget tracker coming soon!')),
              );
            },
          ),
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonGuest.png',
            label: 'Guest',
            color: Color(0xFFFFE100),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Guest list coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton({
    required String imagePath,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isPressed = _pressedButton == label;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressedButton = label;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressedButton = null;
        });
        onTap();
      },
      onTapCancel: () {
        setState(() {
          _pressedButton = null;
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 150),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isPressed ? Colors.white : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.yellow,
                width: isPressed ? 2 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: ColorFiltered(
                colorFilter: isPressed
                    ? ColorFilter.mode(Colors.black, BlendMode.srcIn)
                    : ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}