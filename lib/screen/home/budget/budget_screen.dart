import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../widget/ProfileMenu.dart';
import 'budget_detail_screen.dart';
import 'create_budget_screen.dart';
import 'payment_detail_screen.dart';

class BudgetScreen extends StatefulWidget {
  final String? eventId;
  final String? eventName;

  const BudgetScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final AuthService _authService = AuthService();
  final BudgetService _budgetService = BudgetService();

  String _username = 'User';
  String _selectedEventName = '';
  Map<String, double> _budgetSummary = {
    'totalPaid': 0,
    'totalUnpaid': 0,
    'remainingBalance': 0,
  };

  @override
  void initState() {
    super.initState();
    debugPrint('BudgetScreen initState - eventId: ${widget.eventId}');
    _loadUserData();
    _selectedEventName = widget.eventName ?? '';

    if (widget.eventId != null) {
      if (_selectedEventName.isEmpty) {
        _loadEventName();
      }
      _loadBudgetSummary();
    }
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    debugPrint('Current user: ${user?.uid}');

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

          debugPrint('Loaded username: $username');
          setState(() {
            _username = username;
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
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
        final eventName = eventDoc.data()?['eventName'] ?? '';
        debugPrint('Loaded event name: $eventName');
        setState(() {
          _selectedEventName = eventName;
        });
      }
    } catch (e) {
      debugPrint('Error loading event name: $e');
    }
  }

  Future<void> _loadBudgetSummary() async {
    if (widget.eventId == null) {
      debugPrint('No eventId provided');
      return;
    }

    debugPrint('Loading budget summary for eventId: ${widget.eventId}');
    final summary = await _budgetService.getBudgetSummary(widget.eventId!);

    if (mounted) {
      debugPrint('Budget summary loaded: $summary');
      setState(() {
        _budgetSummary = summary;
      });
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(amount);
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
                  : StreamBuilder<List<BudgetModel>>(
                stream: _budgetService.getBudgetsByEvent(widget.eventId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFE100),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('Stream error: ${snapshot.error}');
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final budgets = snapshot.data ?? [];
                  debugPrint('Budgets count: ${budgets.length}');

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const SizedBox(height: 15),
                      _buildBalanceCarousel(screenWidth),
                      const SizedBox(height: 20),
                      _buildToSpendSection(screenWidth),
                      const SizedBox(height: 15),
                      budgets.isEmpty
                          ? _buildEmptyState()
                          : _buildBudgetList(screenWidth, budgets),
                      const SizedBox(height: 20),
                    ],
                  );
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
              child: const Icon(
                Icons.arrow_back_ios,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Budget',
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
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
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

  Widget _buildBalanceCarousel(double screenWidth) {
    debugPrint('Building carousel - remainingBalance: ${_budgetSummary['remainingBalance']}');
    debugPrint('Building carousel - totalPaid: ${_budgetSummary['totalPaid']}');
    debugPrint('Building carousel - totalUnpaid: ${_budgetSummary['totalUnpaid']}');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildCarouselCard(
              label: 'Remaining Balance',
              amount: _formatCurrency(_budgetSummary['remainingBalance'] ?? 0),
              backgroundColor: const Color(0xFFFFE100),
              imagePath: 'assets/image/balance-pig.png',
            ),
            const SizedBox(width: 12),
            _buildCarouselCard(
              label: 'Amount Paid',
              amount: _formatCurrency(_budgetSummary['totalPaid'] ?? 0),
              backgroundColor: const Color(0xFF51FF00),
              imagePath: 'assets/image/bussines.png',
            ),
            const SizedBox(width: 12),
            _buildCarouselCard(
              label: 'Amount Unpaid',
              amount: _formatCurrency(_budgetSummary['totalUnpaid'] ?? 0),
              backgroundColor: const Color(0xFFFF6B00),
              imagePath: 'assets/image/cash.png',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselCard({
    required String label,
    required String amount,
    required Color backgroundColor,
    required String imagePath,
  }) {
    return Container(
      width: 220,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: 0.5),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Text content on the left
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Image on the right
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 70,
              height: 80,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading image: $imagePath - $error');
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToSpendSection(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'To Spend',
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
                    builder: (context) => CreateBudgetScreen(
                      eventId: widget.eventId!,
                    ),
                  ),
                ).then((_) => _loadBudgetSummary());
              }
            },
            child: Container(
              width: 31,
              height: 31,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE100),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetList(double screenWidth, List<BudgetModel> budgets) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: budgets.map((budget) {
          final isPaid = budget.unpaidAmount <= 0;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetDetailScreen(
                    budgetId: budget.budgetId,
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
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPaid ? Colors.green : Colors.grey,
                        width: 2,
                      ),
                      color: isPaid ? Colors.green : Colors.transparent,
                    ),
                    child: isPaid
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.itemName,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatCurrency(budget.totalCost),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE100).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                budget.category,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/image/no-budget.png',
            width: 156,
            height: 136,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          Text(
            'There are no budgets',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.30),
              fontSize: 15,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first budget to start tracking expenses',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.20),
              fontSize: 12,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
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
          const Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            'No event selected',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.30),
              fontSize: 18,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}