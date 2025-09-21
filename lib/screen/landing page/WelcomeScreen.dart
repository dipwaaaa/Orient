import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

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
    with SingleTickerProviderStateMixin {

  late final AnimationController _gradientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final PageController _pageController = PageController();
  Timer? _autoScrollTimer;

  int _currentPage = 0;

  static const List<PageData> _pages = [
    PageData(
      title: 'Welcome to Orient!',
      description: 'Trying to keep track of an event you\'re organizing? We\'ve got you covered!',
      imageUrl: 'assets/1.png',
      iconData: Icons.waving_hand,
      iconColor: Colors.orange,
    ),
    PageData(
      title: 'Multitask',
      description: 'Organize multiple events at once! Be it a wedding, a birthday, or a farewell party, we\'ll help you perfect it!',
      imageUrl: 'assets/2.png',
      iconData: Icons.task_alt,
      iconColor: Colors.green,
    ),
    PageData(
      title: 'Task Tracker',
      description: 'Cakes, venues, RSVPs... aaah, so many things to do! But don\'t you worry, we\'ll help you remember everything.',
      imageUrl: 'assets/3.png',
      iconData: Icons.track_changes,
      iconColor: Colors.blue,
    ),
    PageData(
      title: 'Budget Control',
      description: 'Don\'t go under or overboard with your money! Make sure to spend the right amount for the right things.',
      imageUrl: 'assets/4.png',
      iconData: Icons.account_balance_wallet,
      iconColor: Colors.purple,
    ),
    PageData(
      title: 'Guest and Vendor List',
      description: 'Who\'s coming? Who\'s selling? Who\'s renting? Keep every information organized just with a few clicks!',
      imageUrl: 'assets/5.png',
      iconData: Icons.people,
      iconColor: Colors.teal,
    ),
    PageData(
      title: 'Sync Up and Collab',
      description: 'Organizing alone is hard. If you need help, call up your friend, sync up your progress, and work together!',
      imageUrl: 'assets/6.png',
      iconData: Icons.sync,
      iconColor: Colors.indigo,
    )
  ];

  final Map<String, bool> _imageCache = {};

  static const Duration _autoScrollDuration = Duration(seconds: 4);
  static const Duration _animationDuration = Duration(milliseconds: 500);
  static const double _imageSize = 300;
  static const double _horizontalPadding = 28;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _preloadImages();
  }

  void _preloadImages() async {
    for (final page in _pages) {
      try {
        await DefaultAssetBundle.of(context).load(page.imageUrl);
        _imageCache[page.imageUrl] = true;
      } catch (e) {
        _imageCache[page.imageUrl] = false;
      }
    }
    if (mounted) setState(() {});
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollDuration, (timer) {
      if (!mounted) return;

      final nextPage = (_currentPage + 1) % _pages.length;
      _updatePage(nextPage);
    });
  }

  void _updatePage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: _animationDuration,
      curve: Curves.easeInOut,
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _restartAutoScroll() {
    _stopAutoScroll();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _pageController.dispose();
    _stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        if (!mounted) return;
                        setState(() => _currentPage = index);
                        _restartAutoScroll();
                      },
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: _handlePageTap,
                          child: _buildPage(_pages[index]),
                        );
                      },
                    ),
                  ),
                  _buildPageIndicators(),
                  _buildGetStartedButton(),
                  const SizedBox(height: 20),
                  _buildHomeIndicator(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePageTap() {
    _stopAutoScroll();
    Timer(const Duration(seconds: 5), () {
      if (mounted) _startAutoScroll();
    });
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          final value = _gradientController.value;
          final dx = 0.6 * (1 - 2 * value);
          final dy = 0.6 * (2 * value - 1);

          return Container(
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

  Widget _buildPage(PageData pageData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: _imageSize,
            height: _imageSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImageWidget(pageData),
          ),
          const SizedBox(height: 40),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: Text(
              pageData.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 20),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: Text(
              pageData.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
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

  Widget _buildImageWidget(PageData pageData) {
    final imageExists = _imageCache[pageData.imageUrl];

    if (imageExists == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (imageExists) {
      return Image.asset(
        pageData.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackWidget(pageData),
      );
    }

    return _buildFallbackWidget(pageData);
  }

  Widget _buildFallbackWidget(PageData pageData) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pageData.iconColor.withOpacity(0.3),
            pageData.iconColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              pageData.iconData,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            pageData.title.split(' ').first,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFD9D9D9)
                  : const Color(0xFF9B9B9B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _stopAutoScroll();
            debugPrint('Get Started tapped!');
            // TODO: Add navigation to next screen
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFE100),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 4,
          ),
          child: const Text(
            'Let\'s Get Started!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIndicator() {
    return Container(
      width: 134,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

class PageData {
  final String title;
  final String description;
  final String imageUrl;
  final IconData iconData;
  final Color iconColor;

  const PageData({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.iconData,
    required this.iconColor,
  });
}