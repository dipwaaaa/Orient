import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../service/auth_service.dart';
import '../../../utilty/app_responsive.dart';
import '../../../model/guest_model.dart';
import 'add_guest_screen.dart';
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

  late String? _selectedEventId;
  late String _selectedEventName;

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.eventId;
    _selectedEventName = widget.eventName ?? '';

    debugPrint(' GuestPageScreen initialized:');
    debugPrint('   eventId: $_selectedEventId');
    debugPrint('   eventName: $_selectedEventName');

    _loadUserData();

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
    AppResponsive.init(context);

    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            "Please log in",
            style: TextStyle(
              color: Colors.black.withValues(alpha:0.5),
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
            _buildHeader(),
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
                        color: Colors.black.withValues(alpha:0.2),
                      ),
                      SizedBox(height: AppResponsive.spacingMedium()),
                      Text(
                        'Please select an event',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha:0.3),
                          fontSize: AppResponsive.responsiveFont(15),
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

  Widget _buildTwitterStyleFAB() {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: AppResponsive.spacingLarge() * 4,
          right: AppResponsive.spacingMedium(),
        ),
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
            width: AppResponsive.responsiveSize(0.15),
            height: AppResponsive.responsiveSize(0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.15),
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
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.black,
                    size: AppResponsive.responsiveIconSize(28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(AppResponsive.responsivePadding()),
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
                    "Guest List",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.responsiveFont(25),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: AppResponsive.spacingSmall() * 0.5),
                  Text(
                    _selectedEventId != null && _selectedEventId!.isNotEmpty
                        ? 'For ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}'
                        : 'No event selected',
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
    );
  }

  Widget _buildGuestList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      // Query from event subcollection, not top-level
      stream: _selectedEventId != null && _selectedEventId!.isNotEmpty
          ? _firestore
          .collection('events')
          .doc(_selectedEventId!)
          .collection('guests')  //  Query subcollection
          .snapshots()  //  Remove createdBy filter so collaborators can see all guests
          : Stream.empty(),
      builder: (context, snapshot) {
        debugPrint('🔍 Guest Stream Update:');
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

        final guests = docs
            .map((doc) =>
            GuestModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.responsivePadding(),
            vertical: AppResponsive.responsivePadding(),
          ),
          itemCount: guests.length,
          separatorBuilder: (_, __) => SizedBox(height: AppResponsive.spacingMedium()),
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
            color: Colors.black.withValues(alpha:0.2),
          ),
          SizedBox(height: AppResponsive.spacingMedium()),
          Text(
            'There are no guests',
            style: TextStyle(
              color: Colors.black.withValues(alpha:0.3),
              fontSize: AppResponsive.responsiveFont(15),
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }

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
            setState(() {});
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.spacingSmall(),
          vertical: AppResponsive.spacingSmall() * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppResponsive.borderRadiusLarge()),
          border: Border.all(color: Colors.grey.withValues(alpha:0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppResponsive.avatarRadius() * 0.5,
              backgroundColor: _getGenderColor(guest.gender),
              child: Text(
                guest.name.isNotEmpty ? guest.name[0].toUpperCase() : "?",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppResponsive.responsiveFont(18),
                ),
              ),
            ),
            SizedBox(width: AppResponsive.spacingSmall()),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppResponsive.responsiveFont(15),
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppResponsive.spacingSmall() * 0.3),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.spacingSmall() * 0.5,
                      vertical: AppResponsive.spacingSmall() * 0.2,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(guest.status ?? 'Pending')
                          .withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadiusSmall()),
                    ),
                    child: Text(
                      guest.status ?? 'Pending',
                      style: TextStyle(
                        fontSize: AppResponsive.responsiveFont(11),
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(guest.status ?? 'Pending'),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios,
              size: AppResponsive.responsiveIconSize(16),
              color: Colors.grey[400],
            ),
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