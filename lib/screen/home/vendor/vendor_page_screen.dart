import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../widget/profile_menu.dart';
import 'add_vendor_screen.dart';
import 'vendor_details_screen.dart';
import '../../../utilty/app_responsive.dart';

class VendorPageScreen extends StatefulWidget {
  final String? eventId;
  final String? eventName;

  const VendorPageScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  @override
  State<VendorPageScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorPageScreen> {
  final AuthService _authService = AuthService();

  String _username = 'User';
  String _selectedEventName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _selectedEventName = widget.eventName ?? '';

    if (widget.eventId != null && _selectedEventName.isEmpty) {
      _loadEventName();
    }
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

  Future<void> _loadEventName() async {
    if (widget.eventId == null) return;

    try {
      final eventDoc = await _authService.firestore
          .collection('events')
          .doc(widget.eventId)
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

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: widget.eventId == null
                  ? _buildNoEventState()
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.eventId)
                    .collection('vendors')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: AppResponsive.bodyStyle(),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildVendorList(docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: AppResponsive.responsivePaddingAll(AppResponsive.responsivePadding()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: AppResponsive.responsivePaddingAll(8),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.black,
                size: AppResponsive.responsiveIconSize(20),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: AppResponsive.responsivePaddingSymmetric(
                horizontal: 8,
                vertical: 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Vendors',
                    style: AppResponsive.responsiveTextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: AppResponsive.spacingSmall() * 0.3),
                  Text(
                    'For ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: AppResponsive.responsiveFont(13),
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: AppResponsive.responsivePaddingAll(AppResponsive.spacingSmall()),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppResponsive.borderRadiusLarge()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppResponsive.responsiveSize(0.089),
                  height: AppResponsive.responsiveSize(0.089),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: AppResponsive.notificationIconSize(),
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

  Widget _buildToContactSection() {
    return Padding(
      padding: AppResponsive.responsivePaddingSymmetric(
        horizontal: 16,
        vertical: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'To Contact',
            style: AppResponsive.responsiveTextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (widget.eventId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddVendorScreen(
                      eventId: widget.eventId!,
                      listName: '',
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: AppResponsive.responsiveSize(0.075),
              height: AppResponsive.responsiveSize(0.075),
              decoration: const BoxDecoration(
                color: Color(0xFFFFE100),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: Colors.black,
                size: AppResponsive.responsiveIconSize(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorList(List<QueryDocumentSnapshot> docs) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        SizedBox(height: AppResponsive.spacingLarge()),
        _buildToContactSection(),
        SizedBox(height: AppResponsive.spacingLarge()),
        Padding(
          padding: AppResponsive.responsivePaddingSymmetric(
            horizontal: 16,
            vertical: 0,
          ),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final vendorName = data['vendorName'] ?? 'Unknown Vendor';
              final category = data['category'] ?? 'General';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VendorDetailsScreen(
                        vendorId: doc.id,
                        eventId: widget.eventId!,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: AppResponsive.spacingMedium(),
                  ),
                  padding: AppResponsive.responsivePaddingAll(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadiusMedium(),
                    ),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha:  0.2),
                    ),
                    boxShadow: [
                      AppResponsive.responsiveBoxShadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                        opacity: 0.05,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendorName,
                              style: AppResponsive.responsiveTextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: AppResponsive.spacingSmall() * 0.6),
                            Container(
                              padding: AppResponsive.responsivePaddingSymmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE100).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(
                                  AppResponsive.borderRadiusSmall(),
                                ),
                              ),
                              child: Text(
                                category,
                                style: AppResponsive.responsiveTextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
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
            }).toList(),
          ),
        ),
        SizedBox(height: AppResponsive.spacingLarge()),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: AppResponsive.spacingExtraLarge()),
          _buildToContactSection(),
          SizedBox(height: AppResponsive.getHeight(20)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/image/noVendor.png',
                width: AppResponsive.responsiveSize(0.29),
                height: AppResponsive.responsiveSize(0.29),
              ),
              SizedBox(height: AppResponsive.spacingExtraLarge()),
              Text(
                'There are no vendors',
                style: AppResponsive.responsiveTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: AppResponsive.responsiveSize(0.193),
            color: Colors.grey,
          ),
          SizedBox(height: AppResponsive.spacingLarge()),
          Text(
            'No event selected',
            style: AppResponsive.responsiveTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}