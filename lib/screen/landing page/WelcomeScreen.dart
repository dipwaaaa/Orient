import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const FigmaToCodeApp());
}

class FigmaToCodeApp extends StatelessWidget {
  const FigmaToCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 32, 47),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;

  int _currentPage = 0;

  final List<PageData> _pages = [
    PageData(
      title: 'Welcome to Orient!',
      description: 'Trying to keep track of an event you\'re organizing? We\'ve got you covered!',
      imageUrl: 'https://i.postimg.cc/9X8tG7M7/welcome-orient.png',
    ),
    PageData(
      title: 'Multitask',
      description: 'Organize multiple events at once! Be it a wedding, a birthday, or a farewell party, we\'ll help you perfect it!',
      imageUrl: 'https://i.postimg.cc/ZqKvQJ8P/multitask.png',
    ),
    PageData(
      title: 'Task Tracker',
      description: 'Cakes, venues, RSVPs... aaah, so many things to do! But don\'t you worry, we\'ll help you remember everything.',
      imageUrl: 'https://i.postimg.cc/Y9pzCK4R/task-tracker.png',
    ),
    PageData(
      title: 'Budget Control',
      description: 'Don\'t go under or overboard with your money! Make sure to spend the right amount for the right things.',
      imageUrl: 'https://i.postimg.cc/6pBdKJ5Q/budget-control.png',
    ),
    PageData(
      title: 'Guest and Vendor List',
      description: 'Who\'s coming? Who\'s selling? Who\'s renting? Keep every information organized just with a few clicks!',
      imageUrl: 'https://i.postimg.cc/cLzGzTNN/guest-vendor.png',
    ),
    PageData(
      title: 'Sync Up and Collab',
      description: 'Organizing alone is hard. If you need help, call up your friend, sync up your progress, and work together!',
      imageUrl: 'https://i.postimg.cc/T1pMBCZJ/sync-collab.png',
    )
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _pages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  void _restartAutoScroll() {
    _stopAutoScroll();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    _stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: 393,
        height: 852,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            _buildStatusBar(),
            Positioned(
              left: 0,
              top: 60,
              right: 0,
              bottom: 150,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentPage = index;
                    });
                    if (!_isAutoScrolling) {
                      _restartAutoScroll();
                    }
                  }
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _stopAutoScroll();
                      Timer(const Duration(seconds: 5), () {
                        if (mounted) {
                          _startAutoScroll();
                        }
                      });
                    },
                    child: _buildPage(_pages[index]),
                  );
                },
              ),
            ),
            _buildPageIndicators(),
            _buildGetStartedButton(),
            _buildHomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned(
      left: 0,
      top: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final dx = 0.6 * (1 - 2 * _controller.value);
          final dy = 0.6 * (2 * _controller.value - 1);
          return Container(
            width: 393,
            height: 852,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(dx, dy),
                radius: 1.75,
                colors: const [
                  Color(0xFFFF6A00),
                  Color(0xFFFFE100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
      left: 0,
      top: 0,
      child: Container(
        width: 393,
        padding: const EdgeInsets.only(
          top: 16,
          left: 52,
          right: 32,
          bottom: 16,
        ),
      ),
    );
  }

  Widget _buildPage(PageData pageData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image container
          Container(
            width: 337,
            height: 337,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(pageData.imageUrl),
                fit: BoxFit.contain,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 40),


          Container(
            constraints: const BoxConstraints(
              maxHeight: 80,
            ),
            child: Text(
              pageData.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            constraints: const BoxConstraints(
              maxHeight: 100,
            ),
            child: Text(
              pageData.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 130,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == _currentPage ? 20 : 8,
              height: 8, // Slightly taller
              decoration: ShapeDecoration(
                color: index == _currentPage
                    ? const Color(0xFFD9D9D9)
                    : const Color(0xFF9B9B9B).withOpacity(0.6),
                shape: index == _currentPage
                    ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                    : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 60,
      child: Center(
        child: GestureDetector(
          onTap: () {
            _stopAutoScroll();
            print('Get Started tapped!');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: ShapeDecoration(
              color: const Color(0xFFFFE100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              'Let\'s Get Started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
                height: 1.29,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIndicator() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 8,
      child: Center(
        child: Container(
          width: 134,
          height: 5,
          decoration: ShapeDecoration(
            color: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ),
    );
  }
}

class PageData {
  final String title;
  final String description;
  final String imageUrl;

  const PageData({
    required this.title,
    required this.description,
    required this.imageUrl,
  });
}