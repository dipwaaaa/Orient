import 'package:flutter/material.dart';
import 'dart:async';
import '../onboarding/onboarding_chatbot_screen.dart'; // UPDATE IMPORT INI
import '../../widget/Animated_Gradient_Background.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {

  late final PageController _pageController = PageController();
  Timer? _autoScrollTimer;

  int _currentPage = 0;

  static const List<PageData> _pages = [
    PageData(
      title: 'Welcome to Orient!',
      description: 'Trying to keep track of an event you\'re organizing? We\'ve got you covered!',
      imageUrl: 'assets/image/1.png',
      iconData: Icons.waving_hand,
      iconColor: Colors.orange,
    ),
    PageData(
      title: 'Multitask',
      description: 'Organize multiple events at once! Be it a wedding, a birthday, or a farewell party, we\'ll help you perfect it!',
      imageUrl: 'assets/image/2.png',
      iconData: Icons.task_alt,
      iconColor: Colors.green,
    ),
    PageData(
      title: 'Task Tracker',
      description: 'Cakes, venues, RSVPs... aaah, so many things to do! But don\'t you worry, we\'ll help you remember everything.',
      imageUrl: 'assets/image/3.png',
      iconData: Icons.track_changes,
      iconColor: Colors.blue,
    ),
    PageData(
      title: 'Budget Control',
      description: 'Don\'t go under or overboard with your money! Make sure to spend the right amount for the right things.',
      imageUrl: 'assets/image/4.png',
      iconData: Icons.account_balance_wallet,
      iconColor: Colors.purple,
    ),
    PageData(
      title: 'Guest and Vendor List',
      description: 'Who\'s coming? Who\'s selling? Who\'s renting? Keep every information organized just with a few clicks!',
      imageUrl: 'assets/image/5.png',
      iconData: Icons.people,
      iconColor: Colors.teal,
    ),
    PageData(
      title: 'Sync Up and Collab',
      description: 'Organizing alone is hard. If you need help, call up your friend, sync up your progress, and work together!',
      imageUrl: 'assets/image/6.png',
      iconData: Icons.sync,
      iconColor: Colors.indigo,
    )
  ];

  final Map<String, bool> _imageCache = {};

  static const Duration _autoScrollDuration = Duration(seconds: 4);
  static const Duration _animationDuration = Duration(milliseconds: 500);

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
    _pageController.dispose();
    _stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final imageSize = screenWidth * 0.75;
    final maxImageSize = screenHeight * 0.35;
    final finalImageSize = imageSize > maxImageSize ? maxImageSize : imageSize;
    final horizontalPadding = screenWidth * 0.07;
    final titleFontSize = screenWidth * 0.07;
    final descriptionFontSize = screenWidth * 0.04;
    final buttonPadding = screenWidth * 0.1;

    return Scaffold(
      body: AnimatedGradientBackground(
        duration: const Duration(seconds: 6),
        radius: 1.75,
        child: SafeArea(
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
                      child: _buildPage(
                        _pages[index],
                        screenWidth,
                        screenHeight,
                        finalImageSize,
                        horizontalPadding,
                        titleFontSize,
                        descriptionFontSize,
                      ),
                    );
                  },
                ),
              ),
              _buildPageIndicators(screenWidth),
              _buildGetStartedButton(buttonPadding, screenWidth),
              SizedBox(height: screenHeight * 0.025),
              _buildHomeIndicator(screenWidth),
              SizedBox(height: screenHeight * 0.01),
            ],
          ),
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

  Widget _buildPage(
      PageData pageData,
      double screenWidth,
      double screenHeight,
      double imageSize,
      double horizontalPadding,
      double titleFontSize,
      double descriptionFontSize,
      ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImageWidget(pageData, screenWidth),
          ),
          SizedBox(height: screenHeight * 0.05),

          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.1),
            child: Text(
              pageData.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize.clamp(20.0, 32.0),
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(height: screenHeight * 0.025),

          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.15),
            child: Text(
              pageData.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: descriptionFontSize.clamp(14.0, 18.0),
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

  Widget _buildImageWidget(PageData pageData, double screenWidth) {
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
        errorBuilder: (context, error, stackTrace) => _buildFallbackWidget(pageData, screenWidth),
      );
    }

    return _buildFallbackWidget(pageData, screenWidth);
  }

  Widget _buildFallbackWidget(PageData pageData, double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pageData.iconColor.withValues(alpha: 0.3),
            pageData.iconColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.05),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              pageData.iconData,
              size: screenWidth * 0.2,
              color: Colors.white,
            ),
          ),
          SizedBox(height: screenWidth * 0.05),
          Text(
            pageData.title.split(' ').first,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          final isActive = index == _currentPage;
          final indicatorSize = screenWidth * 0.02;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
            width: isActive ? indicatorSize * 2.5 : indicatorSize,
            height: indicatorSize,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFD9D9D9)
                  : const Color(0xFF9B9B9B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(indicatorSize / 2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGetStartedButton(double buttonPadding, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: buttonPadding),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _stopAutoScroll();
            // NAVIGATE KE ONBOARDING CHATBOT
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingChatbotScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFE100),
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 4,
          ),
          child: Text(
            "Let's Get Started!",
            style: TextStyle(
              fontSize: (screenWidth * 0.045).clamp(16.0, 20.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIndicator(double screenWidth) {
    return Container(
      width: screenWidth * 0.35,
      height: screenWidth * 0.0125,
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