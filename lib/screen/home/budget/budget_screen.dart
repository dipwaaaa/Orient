import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../service/auth_service.dart';
import '../../../service/budget_service.dart';
import '../../../model/budget_model.dart';
import '../../../utilty/app_responsive.dart';
import '../../../widget/profile_menu.dart';
import 'budget_detail_screen.dart';
import 'create_budget_screen.dart';

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

  final Map<String, double> _budgetSummaryFallback = {
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
                  : StreamBuilder<List<BudgetModel>>(
                stream: _budgetService.getBudgetsByEvent(widget.eventId!),
                builder: (context, snapshotBudgets) {
                  if (snapshotBudgets.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFE100),
                        ),
                      ),
                    );
                  }

                  if (snapshotBudgets.hasError) {
                    debugPrint(
                        'Stream error: ${snapshotBudgets.error}');
                    return Center(
                      child: Text('Error: ${snapshotBudgets.error}'),
                    );
                  }

                  final budgets = snapshotBudgets.data ?? [];
                  debugPrint('Budgets count: ${budgets.length}');

                  return StreamBuilder<Map<String, double>>(
                    stream: _budgetService
                        .getBudgetSummaryStream(widget.eventId!),
                    builder: (context, snapshotSummary) {
                      if (snapshotSummary.connectionState ==
                          ConnectionState.waiting) {
                        return ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            const SizedBox(height: 15),
                            _buildBalanceCarousel(
                              snapshotSummary.data ??
                                  _budgetSummaryFallback,
                            ),
                            const SizedBox(height: 20),
                            _buildToSpendSection(),
                            const SizedBox(height: 15),
                            budgets.isEmpty
                                ? _buildEmptyState()
                                : _buildBudgetList(budgets),
                            const SizedBox(height: 20),
                          ],
                        );
                      }

                      final summary = snapshotSummary.data ?? {};

                      return ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          const SizedBox(height: 15),
                          _buildBalanceCarousel(summary),
                          const SizedBox(height: 20),
                          _buildToSpendSection(),
                          const SizedBox(height: 15),
                          budgets.isEmpty
                              ? _buildEmptyState()
                              : _buildBudgetList(budgets),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  );
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
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.responsivePadding(),
        vertical: AppResponsive.spacingSmall(),
      ),
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
                Text(
                  'Your Budget',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.responsiveFont(25),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppResponsive.spacingSmall() * 0.5),
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
          Container(
            padding: EdgeInsets.all(AppResponsive.responsivePadding() * 0.5),
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

  Widget _buildBalanceCarousel(
      Map<String, double> summary,
      ) {
    debugPrint(
        'Building carousel - remainingBalance: ${summary['remainingBalance']}');
    debugPrint('Building carousel - totalPaid: ${summary['totalPaid']}');
    debugPrint('Building carousel - totalUnpaid: ${summary['totalUnpaid']}');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding()),
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildCarouselCard(
              label: 'Remaining Balance',
              amount: _formatCurrency(summary['remainingBalance'] ?? 0),
              backgroundColor: const Color(0xFFFFE100),
              imagePath: 'assets/image/balance-pig.png',
            ),
            SizedBox(width: AppResponsive.spacingSmall()),
            _buildCarouselCard(
              label: 'Amount Paid',
              amount: _formatCurrency(summary['totalPaid'] ?? 0),
              backgroundColor: const Color(0xFF51FF00),
              imagePath: 'assets/image/bussines.png',
            ),
            SizedBox(width: AppResponsive.spacingSmall()),
            _buildCarouselCard(
              label: 'Amount Unpaid',
              amount: _formatCurrency(summary['totalUnpaid'] ?? 0),
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
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.responsiveFont(9),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: AppResponsive.responsiveFont(16),
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildToSpendSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'To Spend',
            style: TextStyle(
              color: Colors.black,
              fontSize: AppResponsive.responsiveFont(25),
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

  Widget _buildBudgetList(List<BudgetModel> budgets) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.responsivePadding()),
      child: Column(
        children: budgets.map((budget) {
          final isPaid = budget.unpaidAmount <= 0;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetDetailScreen(
                    budgetId: budget.budgetId, eventId: '',
                  ),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.only(bottom: AppResponsive.spacingMedium()),
              padding: EdgeInsets.all(AppResponsive.responsivePadding()),
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
                  SizedBox(width: AppResponsive.spacingSmall()),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.itemName,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: AppResponsive.responsiveFont(15),
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacingSmall() * 0.5),
                        Row(
                          children: [
                            Text(
                              _formatCurrency(budget.totalCost),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: AppResponsive.responsiveFont(13),
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: AppResponsive.spacingSmall()),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppResponsive.spacingSmall(),
                                vertical: AppResponsive.spacingSmall() * 0.25,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE100)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                budget.category,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: AppResponsive.responsiveFont(10),
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
                    size: AppResponsive.responsiveFont(16),
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
      padding: EdgeInsets.symmetric(
        vertical: AppResponsive.spacingLarge() * 3,
        horizontal: AppResponsive.responsivePadding() * 2,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/image/no-budget.png',
            width: 156,
            height: 136,
            fit: BoxFit.contain,
          ),
          SizedBox(height: AppResponsive.spacingLarge()),
          Text(
            'There are no budgets',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.30),
              fontSize: AppResponsive.responsiveFont(15),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.spacingSmall()),
          Text(
            'Create your first budget to start tracking expenses',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.20),
              fontSize: AppResponsive.responsiveFont(12),
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
          SizedBox(height: AppResponsive.spacingLarge()),
          Text(
            'No event selected',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.30),
              fontSize: AppResponsive.responsiveFont(18),
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}