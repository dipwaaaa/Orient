import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/screen/home/budget/budget_screen.dart';
import 'dart:async';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/event_service.dart';
import 'package:untitled/service/budget_service.dart';
import 'package:untitled/utilty/app_responsive.dart';
import '../../widget/Animated_Gradient_Background.dart';
import '../../widget/NavigationBar.dart';
import '../../widget/profile_menu.dart';
import '../../widget/TaskLitWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_signup_screen.dart';
import 'task/task_page_screen.dart';
import 'guest/GuestPageScreen.dart';
import 'vendor/vendorPageScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final BudgetService _budgetService = BudgetService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = 'User';
  int _currentIndex = 1;

  // Carousel and Event State
  final _carouselController = PageController();
  int _currentCarouselIndex = 0;
  List<Map<String, dynamic>> _userEvents = [];
  bool _isLoadingEvents = true;

  // Current Event State
  DateTime? _currentEventDate;
  String _currentEventName = 'No Active Event';
  String? _currentEventId;

  // Budget State
  Map<String, double> _budgetSummary = {
    'totalPaid': 0,
    'totalUnpaid': 0,
    'remainingBalance': 0,
  };

  // Auto-delete state
  bool _isAutoDeleting = false;

  Timer? _countdownTimer;
  StreamSubscription<QuerySnapshot>? _eventSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _budgetSubscription;

  final ValueNotifier<Map<String, int>> _countdownNotifier =
  ValueNotifier({'days': 0, 'hours': 0});

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _loadUserData();

    // Trigger auto-delete when app starts
    _triggerAutoDeletePastEvents();

    _listenToEvents();

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentEventDate != null && mounted) {
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

  /// Trigger auto-delete for past events
  Future<void> _triggerAutoDeletePastEvents() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in, skipping auto-delete');
        return;
      }

      if (_isAutoDeleting) {
        debugPrint('⏳ Auto-delete already in progress, skipping');
        return;
      }

      setState(() => _isAutoDeleting = true);

      debugPrint('🗑️ Starting auto-delete for past events...');

      // Call auto-delete service
      final deletedCount = await _eventService.autoDeletePastEvents(user.uid);

      if (mounted) {
        setState(() => _isAutoDeleting = false);

        if (deletedCount > 0) {
          debugPrint('✅ Auto-deleted $deletedCount past events');

          // Show snackbar notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deletedCount event${deletedCount > 1 ? 's' : ''} archived'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green[600],
            ),
          );

          // Refresh events list
          _listenToEvents();
        }
      }
    } catch (e) {
      debugPrint('❌ Error in auto-delete: $e');
      if (mounted) {
        setState(() => _isAutoDeleting = false);
      }
    }
  }

  void _setupAuthListener() {
    _authSubscription = _authService.auth.authStateChanges().listen((user) {
      if (user == null && mounted) {
        _cleanupAndNavigateToLogin();
      }
    });
  }

  void _listenToEvents() {
    final user = _authService.currentUser;

    if (user == null) {
      setState(() {
        _isLoadingEvents = false;
      });
      return;
    }

    if (_isLoadingEvents) {
      setState(() {
        _isLoadingEvents = true;
      });
    }

    _eventSubscription = _firestore
        .collection('events')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen((ownerSnapshot) async {

      if (_authService.currentUser == null) {
        return;
      }

      try {
        final collaboratorSnapshot = await _firestore
            .collection('events')
            .where('collaborators', arrayContains: user.uid)
            .get()
            .timeout(Duration(seconds: 10));

        if (!mounted || _authService.currentUser == null) return;

        final allEventDocs = [
          ...ownerSnapshot.docs,
          ...collaboratorSnapshot.docs,
        ];

        final uniqueEvents = <String, QueryDocumentSnapshot>{};
        for (var doc in allEventDocs) {
          uniqueEvents[doc.id] = doc;
        }

        if (uniqueEvents.isEmpty) {
          if (mounted) {
            setState(() {
              _userEvents = [];
              _isLoadingEvents = false;
              _currentEventDate = null;
              _currentEventName = 'No Active Event';
              _currentEventId = null;
            });
          }
          _countdownNotifier.value = {'days': 0, 'hours': 0};
          _listenToBudgetSummary(null);
          return;
        }

        final events = uniqueEvents.values.toList();
        events.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>?;
          final dataB = b.data() as Map<String, dynamic>?;

          if (dataA == null || dataB == null) return 0;

          final dateA = (dataA['eventDate'] as Timestamp?)?.toDate();
          final dateB = (dataB['eventDate'] as Timestamp?)?.toDate();

          if (dateA == null || dateB == null) return 0;

          return dateA.compareTo(dateB);
        });

        final eventsList = events.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;

          if (data == null) {
            return {
              'id': doc.id,
              'name': 'Unnamed Event',
              'date': DateTime.now(),
              'location': '',
              'description': '',
              'isOwner': false,
              'isCollaborator': false,
            };
          }

          return {
            'id': doc.id,
            'name': data['eventName'] ?? 'Unnamed Event',
            'date': (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'location': data['eventLocation'] ?? '',
            'description': data['description'] ?? '',
            'isOwner': data['ownerId'] == user.uid,
            'isCollaborator': (data['collaborators'] as List<dynamic>?)?.contains(user.uid) ?? false,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _userEvents = eventsList;
            _isLoadingEvents = false;
            if (_userEvents.isNotEmpty && _currentCarouselIndex < _userEvents.length) {
              _updateCurrentEvent(_currentCarouselIndex);
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading collaborator events: $e');
        if (!mounted || _authService.currentUser == null) return;

        final events = ownerSnapshot.docs.toList();
        final eventsList = events.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return null;

          return {
            'id': doc.id,
            'name': data['eventName'] ?? 'Unnamed Event',
            'date': (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'location': data['eventLocation'] ?? '',
            'description': data['description'] ?? '',
            'isOwner': true,
            'isCollaborator': false,
          };
        }).whereType<Map<String, dynamic>>().toList();

        if (mounted) {
          setState(() {
            _userEvents = eventsList;
            _isLoadingEvents = false;
          });
        }
      }
    }, onError: (error) {
      debugPrint('Stream error: $error');
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    });
  }

  void _listenToBudgetSummary(String? eventId) {
    _budgetSubscription?.cancel();

    if (eventId == null) {
      setState(() {
        _budgetSummary = {
          'totalPaid': 0,
          'totalUnpaid': 0,
          'remainingBalance': 0,
        };
      });
      return;
    }

    _budgetSubscription = _firestore
        .collection('budgets')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .listen((snapshot) {
      double totalBudget = 0;
      double totalPaid = 0;
      double totalUnpaid = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalBudget += (data['totalCost'] ?? 0).toDouble();
        totalPaid += (data['paidAmount'] ?? 0).toDouble();
        totalUnpaid += (data['unpaidAmount'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _budgetSummary = {
            'totalPaid': totalPaid,
            'totalUnpaid': totalUnpaid,
            'remainingBalance': totalBudget - totalPaid,
          };
        });
      }
    });
  }

  void _updateCurrentEvent(int index) {
    if (_userEvents.isEmpty) {
      setState(() {
        _currentEventDate = null;
        _currentEventName = 'No Active Event';
        _currentEventId = null;
      });
      _countdownNotifier.value = {'days': 0, 'hours': 0};
      _listenToBudgetSummary(null);
      return;
    }

    final event = _userEvents[index];
    final eventDate = event['date'] as DateTime;
    final eventName = event['name'] as String;
    final eventId = event['id'] as String;

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

    _listenToBudgetSummary(eventId);
  }

  void _cleanupAndNavigateToLogin() {
    _countdownTimer?.cancel();
    _eventSubscription?.cancel();
    _authSubscription?.cancel();
    _budgetSubscription?.cancel();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _eventSubscription?.cancel();
    _authSubscription?.cancel();
    _budgetSubscription?.cancel();
    _countdownNotifier.dispose();
    _carouselController.dispose();
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
        debugPrint('Error loading user data: $e');
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

  String _formatCurrency(double amount) {
    return 'Rp${NumberFormat('#,###', 'id_ID').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: SafeArea(
              child: Column(
                children: [
                  HeaderWithAvatar(
                    username: _username,
                    greeting: 'Hi, $_username!',
                    subtitle: 'What event are you planning today?',
                    authService: _authService,
                    onNotificationTap: () {
                      debugPrint('Notification tapped');
                    },
                  ),

                  SizedBox(height: 24),
                  _buildCarousel(),
                  SizedBox(height: 16),
                  _buildFeatureButtons(),
                  SizedBox(height: 24),
                  if (_currentEventId != null)
                    _buildTaskSection(),
                  SizedBox(height: 24),
                  if (_currentEventId != null)
                    _buildBudgetSection(),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Auto-delete loading overlay
          if (_isAutoDeleting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFE100),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Checking for past events...',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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

  // ============================================================
  // BUDGET SECTION
  // ============================================================
  Widget _buildBudgetSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.responsivePadding(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget',
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
                    MaterialPageRoute(
                      builder: (context) => BudgetScreen(
                        eventId: _currentEventId,
                        eventName: _currentEventName,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildBudgetSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildBudgetSummaryCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBudgetRow(
            icon: '●',
            label: 'Balance',
            amount: _formatCurrency(_budgetSummary['remainingBalance'] ?? 0),
            color: Color(0xFFFFE100),
          ),
          SizedBox(height: 12),
          _buildBudgetRow(
            icon: '●',
            label: 'Paid',
            amount: _formatCurrency(_budgetSummary['totalPaid'] ?? 0),
            color: Color(0xFF51FF00),
          ),
          SizedBox(height: 12),
          _buildBudgetRow(
            icon: '●',
            label: 'Unpaid',
            amount: _formatCurrency(_budgetSummary['totalUnpaid'] ?? 0),
            color: Color(0xFFFF6B00),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow({
    required String icon,
    required String label,
    required String amount,
    required Color color,
  }) {
    return Row(
      children: [
        Text(
          icon,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.responsivePadding(),
      ),
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
                    MaterialPageRoute(
                      builder: (context) => TaskScreen(
                        eventId: _currentEventId,
                        eventName: _currentEventName,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.black.withValues(alpha: 0.6),
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
            hideCompletedInHome: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    final cardWidth = AppResponsive.screenWidth * 0.85;
    final cardHeight = 189.0;

    if (_isLoadingEvents) {
      return SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
          ),
        ),
      );
    }

    if (_userEvents.isEmpty) {
      return _buildEmptyCarousel(cardWidth, cardHeight);
    }

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: _userEvents.length,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
              _updateCurrentEvent(index);
            },
            itemBuilder: (context, index) {
              final event = _userEvents[index];
              return ValueListenableBuilder<Map<String, int>>(
                valueListenable: _countdownNotifier,
                builder: (context, countdown, child) {
                  if (index == _currentCarouselIndex) {
                    return _buildEventCarousel(
                      cardWidth,
                      cardHeight,
                      event['name'],
                      countdown['days']!,
                      countdown['hours']!,
                    );
                  } else {
                    final eventDate = event['date'] as DateTime;
                    final difference = eventDate.difference(DateTime.now());
                    return _buildEventCarousel(
                      cardWidth,
                      cardHeight,
                      event['name'],
                      difference.inDays.clamp(0, 999),
                      (difference.inHours % 24).clamp(0, 23),
                    );
                  }
                },
              );
            },
          ),
        ),
        SizedBox(height: 12),
        if (_userEvents.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _userEvents.length,
                  (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: _currentCarouselIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentCarouselIndex == index
                      ? Color(0xFFFFE100)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
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
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedGradientBackground(
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
              child: SizedBox(
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
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              child: SizedBox(
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

  String? _pressedButton;

  Widget _buildFeatureButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding()),
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
                MaterialPageRoute(
                  builder: (context) => TaskScreen(
                    eventId: _currentEventId,
                    eventName: _currentEventName,
                  ),
                ),
              );
            },
          ),
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonVendor.png',
            label: 'Vendor',
            color: const Color(0xFFFFE100),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VendorPageScreen(
                    eventId: _currentEventId,
                    eventName: _currentEventName,
                  ),
                ),
              );
            },
          ),
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonBudget.png',
            label: 'Budget',
            color: Color(0xFFFFE100),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetScreen(
                    eventId: _currentEventId,
                    eventName: _currentEventName,
                  ),
                ),
              );
            },
          ),
          _buildFeatureButton(
            imagePath: 'assets/image/ButtonGuest.png',
            label: 'Guest',
            color: const Color(0xFFFFE100),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuestPageScreen(),
                ),
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
                  color: Colors.black.withValues(alpha: 0.1),
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