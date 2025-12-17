import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../service/auth_service.dart';
import '../../widget/navigation_bar.dart';
import '../../widget/profile_menu.dart';
import '../../screen/Event/event_detail_screen.dart';
import '../../utilty/app_responsive.dart';
import 'create_event_screen.dart';
import '../login_signup_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = 'User';
  int _currentIndex = 0;
  bool _hasCollaboratorPermission = true;

  // Subscriptions
  StreamSubscription? _authSubscription;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _loadUserData();
  }

  /// Setup auth state listener untuk handle sign-out
  void _setupAuthListener() {
    _authSubscription = _authService.auth.authStateChanges().listen((user) {
      if (user == null && mounted) {
        debugPrint('🔴 User signed out from EventListScreen');
        _cleanupAndNavigateToLogin();
      }
    });
  }

  /// Cleanup dan navigate ke login ketika sign-out
  void _cleanupAndNavigateToLogin() {
    // Cancel semua subscriptions
    _authSubscription?.cancel();
    _eventSubscription?.cancel();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
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

                  SizedBox(height: AppResponsive.spacingLarge()),

                  _buildEventListSection(),

                  SizedBox(height: AppResponsive.spacingLarge()),
                ],
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildEventListSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.responsivePadding(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventList(),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final user = _authService.currentUser;

    if (user == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.responsivePadding()),
          child: Text(
            'Please login to view events',
            style: TextStyle(
              fontSize: AppResponsive.responsiveFont(14),
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, ownerSnapshot) {
        // For collaborator events
        return StreamBuilder<QuerySnapshot>(
          stream: _buildCollaboratorStream(user.uid),
          builder: (context, collaboratorSnapshot) {
            // Handle loading states
            if (ownerSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(AppResponsive.responsivePadding()),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFE100),
                    ),
                  ),
                ),
              );
            }

            // Handle owner events error
            if (ownerSnapshot.hasError) {
              debugPrint(
                ' Owner events error: ${ownerSnapshot.error}',
              );
              return _buildErrorState(ownerSnapshot.error);
            }

            // Merge events from owner and collaborator
            final allEvents = <String, QueryDocumentSnapshot>{};

            if (ownerSnapshot.hasData && ownerSnapshot.data != null) {
              for (var doc in ownerSnapshot.data!.docs) {
                allEvents[doc.id] = doc;
              }
            }

            // Add collaborator events if available
            if (collaboratorSnapshot.hasData &&
                collaboratorSnapshot.data != null) {
              for (var doc in collaboratorSnapshot.data!.docs) {
                allEvents[doc.id] = doc;
              }
            }

            if (collaboratorSnapshot.hasError) {
              debugPrint(
                ' Collaborator events permission denied (expected behavior): ${collaboratorSnapshot.error}',
              );
              if (mounted) {
                setState(() => _hasCollaboratorPermission = false);
              }
            } else {
              if (!_hasCollaboratorPermission && mounted) {
                setState(() => _hasCollaboratorPermission = true);
              }
            }

            if (allEvents.isEmpty) {
              return _buildEmptyState();
            }

            // Sort by date
            final sortedEvents = allEvents.values.toList()
              ..sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>?;
                final dataB = b.data() as Map<String, dynamic>?;

                if (dataA == null || dataB == null) return 0;

                final dateA = dataA['eventDate'] as Timestamp?;
                final dateB = dataB['eventDate'] as Timestamp?;

                if (dateA == null || dateB == null) return 0;

                return dateA.compareTo(dateB);
              });

            return _buildEventListView(sortedEvents);
          },
        );
      },
    );
  }

  // Build collaborator stream dengan error handling
  Stream<QuerySnapshot> _buildCollaboratorStream(String userId) {
    try {
      return _firestore
          .collection('events')
          .where('collaborators', arrayContains: userId)
          .snapshots()
          .handleError((error) {
        debugPrint('Collaborator stream error: $error');
        // Return empty stream on error instead of crashing
        return Stream.empty();
      });
    } catch (e) {
      debugPrint('Error creating collaborator stream: $e');
      // Return empty stream on catch
      return Stream.empty();
    }
  }

  Widget _buildEventListView(List<QueryDocumentSnapshot> sortedEvents) {
    return Column(
      children: List.generate(
        sortedEvents.length,
            (index) {
          final docData = sortedEvents[index].data();
          final event = docData is Map<String, dynamic>
              ? docData
              : <String, dynamic>{};
          final eventId = sortedEvents[index].id;
          return _buildEventCard(event, eventId);
        },
      ),
    );
  }

  Widget _buildErrorState(dynamic error) {
    String errorMessage = 'Error loading events';
    String errorDescription = error.toString();

    // Handle specific error types
    if (error.toString().contains('PERMISSION_DENIED')) {
      errorMessage = 'Permission Denied';
      errorDescription =
      'Check your Firestore Security Rules. Contact administrator if needed.';
    } else if (error.toString().contains('NOT_FOUND')) {
      errorMessage = 'Database Not Found';
      errorDescription = 'Please check your Firestore database connection.';
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.responsivePadding()),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: AppResponsive.responsiveFont(64),
              color: Colors.red,
            ),
            SizedBox(height: AppResponsive.spacingMedium()),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: AppResponsive.responsiveFont(16),
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            SizedBox(height: AppResponsive.spacingSmall()),
            Text(
              errorDescription,
              style: TextStyle(
                fontSize: AppResponsive.responsiveFont(12),
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppResponsive.spacingMedium()),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFE100),
                foregroundColor: Colors.black,
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenHeight = AppResponsive.screenHeight;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * 0.1,
        horizontal: AppResponsive.responsivePadding(),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: AppResponsive.responsiveFont(80),
            color: Colors.grey[400],
          ),
          SizedBox(height: AppResponsive.spacingLarge()),
          Text(
            'No Events Yet',
            style: TextStyle(
              fontSize: AppResponsive.responsiveFont(20),
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              fontFamily: 'SF Pro',
            ),
          ),
          SizedBox(height: AppResponsive.spacingSmall()),
          Text(
            'Create your first event to get started!',
            style: TextStyle(
              fontSize: AppResponsive.responsiveFont(14),
              color: Colors.grey[500],
              fontFamily: 'SF Pro',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, String eventId) {
    final eventName = event['eventName'] as String? ?? 'Unnamed Event';
    final eventDate = (event['eventDate'] as Timestamp?)?.toDate();
    final eventLocation = event['eventLocation'] as String? ?? 'No location';
    final ownerId = event['ownerId'] as String? ?? '';
    final collaborators = event['collaborators'] != null
        ? List<String>.from(event['collaborators'] as List)
        : <String>[];

    final user = _authService.currentUser;
    final isOwner = user != null && ownerId == user.uid;
    final isCollaborator = user != null && collaborators.contains(user.uid);

    // Calculate days remaining
    int daysRemaining = 0;
    if (eventDate != null) {
      daysRemaining = eventDate.difference(DateTime.now()).inDays;
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.spacingMedium()),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE100),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(eventId: eventId),
              ),
            );

            if (result == true && mounted) {
              setState(() {});
            }
          },
          child: Padding(
            padding: EdgeInsets.all(AppResponsive.responsivePadding() * 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Row - Owner or Collaborator
                if (isOwner || isCollaborator)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: AppResponsive.spacingSmall(),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppResponsive.spacingSmall(),
                            vertical: AppResponsive.spacingSmall() * 0.5,
                          ),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? Colors.black
                                : Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOwner ? 'Owner' : 'Collaborator',
                            style: TextStyle(
                              color: Color(0xFFFFE100),
                              fontSize: AppResponsive.responsiveFont(10),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Event Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Name
                          Text(
                            eventName,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: AppResponsive.responsiveFont(18),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppResponsive.spacingSmall() * 0.5),

                          // Location with Icon
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: AppResponsive.responsiveFont(14),
                                color: Colors.black54,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  eventLocation,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: AppResponsive.responsiveFont(12),
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: AppResponsive.spacingSmall()),

                    // Days Remaining + Arrow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          eventDate != null
                              ? 'In $daysRemaining days'
                              : 'No date',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: AppResponsive.responsiveFont(13),
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacingSmall() * 0.5),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black,
                          size: AppResponsive.responsiveFont(16),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE100),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6AA0).withValues(alpha: 0.5),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () async {
            // Navigate to CreateEventScreen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateEventScreen(),
              ),
            );

            // Refresh list if event was created
            if (result == true && mounted) {
              setState(() {});
            }
          },
          child: Icon(
            Icons.add,
            color: Colors.black,
            size: AppResponsive.responsiveFont(30),
          ),
        ),
      ),
    );
  }
}