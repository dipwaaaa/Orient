import 'package:flutter/material.dart';
import '/screen/home/home_screen.dart';
import '/screen/Event/list_event_screen.dart';
import '/screen/message/chat_screen.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: BottomNavClipper(
                indicatorPosition: _getIndicatorPosition(screenWidth) + 45,
                cutoutWidth: 100,
              ),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _getIndicatorPosition(screenWidth),
            top: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _getIndicatorPosition(screenWidth) + 15,
            top: 5,
            child: Container(
              width: 60,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getSelectedIconData(),
                color: Color(0xFFFFE100),
                size: 35,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 120,
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(Icons.calendar_today_rounded, 0, context),
                  _buildNavItem(Icons.home_rounded, 1, context),
                  _buildNavItem(Icons.chat_bubble_rounded, 2, context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getIndicatorPosition(double screenWidth) {
    final itemWidth = (screenWidth - 100) / 3;

    switch (currentIndex) {
      case 0:
        return 50 + (itemWidth * 0) + (itemWidth / 2) - 45;
      case 1:
        return 50 + (itemWidth * 1) + (itemWidth / 2) - 45;
      case 2:
        return 50 + (itemWidth * 2) + (itemWidth / 2) - 45;
      default:
        return 50 + (itemWidth * 1) + (itemWidth / 2) - 45;
    }
  }

  IconData _getSelectedIconData() {
    switch (currentIndex) {
      case 0:
        return Icons.calendar_today_rounded;
      case 1:
        return Icons.home_rounded;
      case 2:
        return Icons.chat_bubble_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  Widget _buildNavItem(IconData icon, int index, BuildContext context) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        onIndexChanged(index);
        _handleNavigation(context, index);
      },
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 300),
          opacity: isSelected ? 0.0 : 1.0,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.6),
            size: 35,
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    switch (index) {
      case 0:
        if (currentRoute != '/event-list') {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const EventListScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
              settings: const RouteSettings(name: '/event-list'),
            ),
          );
        }
        break;

      case 1:
        if (currentRoute != '/home') {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
              settings: const RouteSettings(name: '/home'),
            ),
          );
        }
        break;

      case 2:
        if (currentRoute != '/chat') {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ChatScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
              settings: const RouteSettings(name: '/chat'),
            ),
          );
        }
        break;
    }
  }
}

class BottomNavClipper extends CustomClipper<Path> {
  final double indicatorPosition;
  final double cutoutWidth;

  BottomNavClipper({
    required this.indicatorPosition,
    required this.cutoutWidth,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final cutoutRadius = cutoutWidth / 2;
    final cutoutCenter = indicatorPosition;
    final cutoutDepth = 35.0;

    path.moveTo(0, 25);
    path.quadraticBezierTo(0, 0, 25, 0);
    path.lineTo(cutoutCenter - cutoutRadius - 20, 0);
    path.quadraticBezierTo(
      cutoutCenter - cutoutRadius - 8,
      0,
      cutoutCenter - cutoutRadius + 2,
      cutoutDepth * 0.35,
    );
    path.arcToPoint(
      Offset(cutoutCenter + cutoutRadius - 2, cutoutDepth * 0.35),
      radius: Radius.circular(cutoutRadius + 5),
      clockwise: false,
    );
    path.quadraticBezierTo(
      cutoutCenter + cutoutRadius + 8,
      0,
      cutoutCenter + cutoutRadius + 20,
      0,
    );
    path.lineTo(size.width - 25, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 25);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(BottomNavClipper oldClipper) {
    return oldClipper.indicatorPosition != indicatorPosition;
  }
}