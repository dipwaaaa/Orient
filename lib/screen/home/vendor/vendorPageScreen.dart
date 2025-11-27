import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../widget/ProfileMenu.dart';
import 'addVendorScreen.dart';           // Your Add Vendor screen
import 'vendorDetailsScreen.dart';       // Vendor detail page
import '../../../model/vendor_model.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(screenWidth),
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
                    return Center(child: Text('Error: ${snapshot.error}'));
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

  Widget _buildHeader(double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.044),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Vendors',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedEventName.isNotEmpty
                      ? 'For $_selectedEventName'
                      : 'As per ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ProfileMenu.show(context, _authService, _username);
                  },
                  child: Container(
                    width: 32.5,
                    height: 32.5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFDEF3FF),
                    ),
                    child: ClipOval(
                      child: _authService.currentUser?.photoURL != null
                          ? Image.network(
                        _authService.currentUser!.photoURL!,
                        fit: BoxFit.cover,
                      )
                          : Image.asset('assets/image/AvatarKimmy.png', fit: BoxFit.cover),
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

  Widget _buildToContactSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'To Contact',
            style: TextStyle(
              color: Colors.black,
              fontSize: 25,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (widget.eventId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddVendorScreen(eventId: widget.eventId!),
                  ),
                );
              }
            },
            child: Container(
              width: 31,
              height: 31,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE100),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorList(List<QueryDocumentSnapshot> docs) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 20),
        _buildToContactSection(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendorName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE100).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        _buildToContactSection(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/image/noVendor.png',  // Changed from no-budget.png
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 30),
                Text(
                  'There are no vendors',
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
    );
  }

  Widget _buildNoEventState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'No event selected',
            style: TextStyle(
              color: Colors.black.withOpacity(0.3),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }
}