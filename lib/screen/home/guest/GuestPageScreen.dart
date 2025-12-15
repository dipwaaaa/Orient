import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:untitled/service/auth_service.dart';
import '../../../model/guest_model.dart';
import 'AddGuestScreen.dart';
import 'guest_detail_screen.dart';
import '../../../widget/profile_menu.dart';

class GuestPageScreen extends StatefulWidget {
  final String? eventId;
  final String? eventName;

  const GuestPageScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  @override
  State<GuestPageScreen> createState() => _GuestPageScreenState();
}

class _GuestPageScreenState extends State<GuestPageScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = 'User';
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  // ✨ Event Selection State - same as TaskScreen
  late String? _selectedEventId;
  late String _selectedEventName;

  @override
  void initState() {
    super.initState();
    // ✨ Initialize with passed eventId/eventName from HomeScreen carousel
    _selectedEventId = widget.eventId;
    _selectedEventName = widget.eventName ?? '';

    debugPrint('🎯 GuestPageScreen initialized:');
    debugPrint('   eventId: $_selectedEventId');
    debugPrint('   eventName: $_selectedEventName');

    _loadUserData();

    // Setup FAB Animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _authService.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        String username = userDoc.data()?['username'] ?? user.displayName ?? 'User';
        username = username.replaceAll(' ', '');
        if (username.isEmpty) username = 'User';

        setState(() => _username = username);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            "Please log in",
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
              fontSize: 16,
              fontFamily: 'SF Pro',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(screenWidth),
            // ✨ Only show guest list if eventId is selected
            if (_selectedEventId != null && _selectedEventId!.isNotEmpty)
              Expanded(
                child: _buildGuestList(user.uid),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_note,
                        size: 64,
                        color: Colors.black.withOpacity(0.2),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Please select an event',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.3),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
      (_selectedEventId != null && _selectedEventId!.isNotEmpty)
          ? _buildTwitterStyleFAB()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// Add Guest Button
  Widget _buildTwitterStyleFAB() {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 70, right: 16),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddGuestScreen(eventId: _selectedEventId),
              ),
            ).then((_) {
              _fabAnimationController.reset();
              _fabAnimationController.forward();
            });
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: null,
                borderRadius: BorderRadius.circular(28),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header with Event Info - Same as TaskScreen style
  Widget _buildHeader(double screenWidth) {
    return Padding(
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

          // Title Section - ✨ Shows current event from carousel
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Guest List",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  // ✨ Shows selected event name from carousel
                  Text(
                    _selectedEventId != null && _selectedEventId!.isNotEmpty
                        ? 'For $_selectedEventName'
                        : 'No event selected',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
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
    );
  }

  /// Build Guest List - ✨ ONLY shows guests for selected eventId
  Widget _buildGuestList(String userId) {
    // ✨ IMPORTANT: Query ONLY guests for this specific event
    // This is the KEY FIX - filter by eventId like TaskScreen does
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedEventId != null && _selectedEventId!.isNotEmpty
          ? _firestore
          .collection('guests')
          .where('createdBy', isEqualTo: userId)
          .where('eventId', isEqualTo: _selectedEventId) // ✨ FILTER BY EVENT!
          .snapshots()
          : Stream.empty(),
      builder: (context, snapshot) {
        debugPrint('📊 Guest Stream Update:');
        debugPrint('   State: ${snapshot.connectionState}');
        debugPrint('   Has Error: ${snapshot.hasError}');
        if (snapshot.hasData) {
          debugPrint('   Docs Count: ${snapshot.data?.docs.length ?? 0}');
          debugPrint('   Event Filter: $_selectedEventId');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('❌ Stream Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        debugPrint('✅ Loaded ${docs.length} guests for event $_selectedEventId');

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        // Convert to GuestModel and sort by name
        final guests = docs
            .map((doc) =>
            GuestModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: guests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final guest = guests[index];
            return _buildGuestTile(guest);
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
            Icons.people,
            size: 64,
            color: Colors.black.withOpacity(0.2),
          ),
          SizedBox(height: 16),
          Text(
            'There are no guests',
            style: TextStyle(
              color: Colors.black.withOpacity(0.3),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }

  /// Guest Tile - ✨ Navigates to GuestDetailScreen
  Widget _buildGuestTile(GuestModel guest) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuestDetailScreen(guest: guest),
          ),
        ).then((result) {
          if (result == true) {
            // Refresh list after edit/delete
            setState(() {});
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: _getGenderColor(guest.gender),
              child: Text(
                guest.name.isNotEmpty ? guest.name[0].toUpperCase() : "?",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ✨ Status Badge
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(guest.status ?? 'Pending')
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      guest.status ?? 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(guest.status ?? 'Pending'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return Colors.blue.shade600;
      case 'female':
        return Colors.pink.shade400;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'not sent':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}