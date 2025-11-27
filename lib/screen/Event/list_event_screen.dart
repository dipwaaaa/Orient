import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/widget/NavigationBar.dart';
import 'package:untitled/widget/ProfileMenu.dart' as profile_menu;
import 'package:untitled/screen/Event/event_detail_screen.dart';
import 'create_event_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildEventList(),
            ),
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.044),
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
                    fontSize: screenWidth * 0.069,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  'What event are you planning today?',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.036,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(screenWidth * 0.022),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(screenWidth * 0.069),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: screenWidth * 0.089,
                  height: screenWidth * 0.089,
                  decoration: const BoxDecoration(
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
                GestureDetector(
                  onTap: () {
                    profile_menu.ProfileMenu.show(context, _authService, _username);
                  },
                  child: Container(
                    width: screenWidth * 0.088,
                    height: screenWidth * 0.088,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDEF3FF),
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

  Widget _buildEventList() {
    final user = _authService.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please login to view events'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, ownerSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('events')
              .where('collaborators', arrayContains: user.uid)
              .snapshots(),
          builder: (context, collaboratorSnapshot) {
            if (ownerSnapshot.connectionState == ConnectionState.waiting ||
                collaboratorSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                ),
              );
            }

            if (ownerSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${ownerSnapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (collaboratorSnapshot.hasError) {
              return Center(
                child: Text('Error: ${collaboratorSnapshot.error}'),
              );
            }

            // Gabungkan events dari owner dan collaborator
            final allEvents = <String, QueryDocumentSnapshot>{};

            if (ownerSnapshot.hasData && ownerSnapshot.data != null) {
              for (var doc in ownerSnapshot.data!.docs) {
                allEvents[doc.id] = doc;
              }
            }

            if (collaboratorSnapshot.hasData && collaboratorSnapshot.data != null) {
              for (var doc in collaboratorSnapshot.data!.docs) {
                allEvents[doc.id] = doc;
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

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedEvents.length,
              itemBuilder: (context, index) {
                final docData = sortedEvents[index].data();
                final event = docData is Map<String, dynamic>
                    ? docData
                    : <String, dynamic>{};
                final eventId = sortedEvents[index].id;
                return _buildEventCard(event, eventId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Events Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first event to get started!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
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
      margin: const EdgeInsets.only(bottom: 16),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Row - Owner or Collaborator
                if (isOwner || isCollaborator)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? Colors.black
                                : Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOwner ? 'Owner' : 'Collaborator',
                            style: const TextStyle(
                              color: Color(0xFFFFE100),
                              fontSize: 10,
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  eventLocation,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
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
                    const SizedBox(width: 12),
                    Text(
                      eventDate != null ? 'In $daysRemaining days' : 'No date',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black,
                      size: 20,
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
            color: const Color(0xFFFF6A00).withValues(alpha: 0.4),
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
          child: const Icon(
            Icons.add,
            color: Colors.black,
            size: 30,
          ),
        ),
      ),
    );
  }
}