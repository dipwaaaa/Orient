import 'package:flutter/material.dart';
import 'dart:async';
import 'package:untitled/service/auth_service.dart';
import '../login_signup_screen.dart';
import '../../widget/Animated_Gradient_Background.dart';
import '../../widget/NavigationBar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Event data untuk countdown
  DateTime? _currentEventDate;
  String _currentEventName = 'No Active Event';
  Timer? _countdownTimer;
  StreamSubscription<QuerySnapshot>? _eventSubscription;

  // Countdown notifier
  final ValueNotifier<Map<String, int>> _countdownNotifier =
  ValueNotifier({'days': 0, 'hours': 0});

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToEvents();

    // Timer untuk countdown - update setiap detik
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentEventDate != null) {
        final now = DateTime.now();
        final difference = _currentEventDate!.difference(now);
        final newDays = difference.inDays.clamp(0, 999);
        final newHours = (difference.inHours % 24).clamp(0, 23);

        // Hanya update jika nilai berubah
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

    print('🔍 _listenToEvents called');

    if (user == null) {
      print('❌ User is NULL - not logged in');
      return;
    }

    print('✅ User authenticated');
    print('   UID: ${user.uid}');
    print('   Email: ${user.email}');

    _eventSubscription = _firestore
        .collection('events')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {

      print('📦 Firestore snapshot received');
      print('   Document count: ${snapshot.docs.length}');

      if (!mounted) {
        print('⚠️ Widget not mounted, ignoring update');
        return;
      }

      if (snapshot.docs.isEmpty) {
        print('❌ No events found for user: ${user.uid}');
        print('   Make sure the ownerId in Firestore matches this UID exactly');
        setState(() {
          _currentEventDate = null;
          _currentEventName = 'No Active Event';
        });
        _countdownNotifier.value = {'days': 0, 'hours': 0};
        return;
      }

      print('✅ Found ${snapshot.docs.length} event(s)');

      // Sort di client side
      final events = snapshot.docs.toList();

      // Debug: Print semua events
      for (var i = 0; i < events.length; i++) {
        final data = events[i].data();
        print('   Event $i:');
        print('     - Name: ${data['eventName']}');
        print('     - Date: ${data['eventDate']}');
        print('     - Owner: ${data['ownerId']}');
      }

      events.sort((a, b) {
        final dateA = (a.data()['eventDate'] as Timestamp).toDate();
        final dateB = (b.data()['eventDate'] as Timestamp).toDate();
        return dateA.compareTo(dateB);
      });

      final eventData = events.first.data();
      final eventName = eventData['eventName'] ?? 'Active Event';
      final Timestamp timestamp = eventData['eventDate'];
      final eventDate = timestamp.toDate();

      print('🎯 Selected event:');
      print('   Name: $eventName');
      print('   Date: $eventDate');

      if (_currentEventDate != eventDate || _currentEventName != eventName) {
        print('🔄 Updating event state');
        setState(() {
          _currentEventDate = eventDate;
          _currentEventName = eventName;
        });

        final now = DateTime.now();
        final difference = eventDate.difference(now);
        _countdownNotifier.value = {
          'days': difference.inDays.clamp(0, 999),
          'hours': (difference.inHours % 24).clamp(0, 23),
        };

        print('⏰ Countdown: ${_countdownNotifier.value}');
      } else {
        print('✓ Event unchanged, no update needed');
      }
    }, onError: (error) {
      print('❌ Firestore error: $error');
      print('   Stack trace: ${StackTrace.current}');
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
      body: Container(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 24),
                  _buildCarousel(screenWidth),
                  SizedBox(height: 32),
                  _buildFeatureButtons(),
                ],
              ),
            )
          ],
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
                      child: Container(
                        color: Color(0xFFDEF3FF),
                        child: _authService.currentUser?.photoURL != null
                            ? Image.network(
                          _authService.currentUser!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                                'assets/image/AvatarKimmy.png');
                          },
                        )
                            : Image.asset('assets/image/AvatarKimmy.png'),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFDEF3FF),
                    backgroundImage: _authService.currentUser?.photoURL != null
                        ? NetworkImage(_authService.currentUser!.photoURL!)
                        : AssetImage('assets/image/AvatarKimmy.png')
                    as ImageProvider,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _username,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _authService.currentUser?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.person, color: Color(0xFFFF6A00)),
              title: Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile settings coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut();
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task management coming soon!')),
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
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
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
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

