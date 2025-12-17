import 'package:flutter/material.dart';


class AppResponsive {
  static late double screenWidth;
  static late double screenHeight;
  static late MediaQueryData _mediaQueryData;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
  }
  static double responsivePadding() => screenWidth * 0.044;

  static double responsivePaddingCustom(double multiplier) =>
      screenWidth * multiplier;

  static double responsivePaddingBreakpoint() {
    if (screenWidth < 350) return 12;
    if (screenWidth < 600) return 16;
    if (screenWidth < 900) return 20;
    return 24;
  }


  static double responsiveMargin() => screenWidth * 0.033;

  static double responsiveFont(double baseFontSize) {
    double scaleFactorWidth = screenWidth / 414;
    double scaleFactorHeight = screenHeight / 896;
    double scaleFactor = (scaleFactorWidth + scaleFactorHeight) / 2;
    return baseFontSize * scaleFactor;
  }

  static double headerFontSize() => responsiveFont(24);

  static double largeTitleFontSize() => responsiveFont(20);

  static double subtitleFontSize() => responsiveFont(16);

  static double bodyFontSize() => responsiveFont(14);

  static double smallFontSize() => responsiveFont(12);

  static double extraSmallFontSize() => responsiveFont(10);


  static double avatarRadius() => screenWidth * 0.088;

  static double notificationIconSize() => screenWidth * 0.069;

  static double borderRadiusLarge() => screenWidth * 0.069;

  static double borderRadiusMedium() => screenWidth * 0.044;

  static double borderRadiusSmall() => screenWidth * 0.022;

  static double responsiveSize(double multiplier) => screenWidth * multiplier;

  static double responsiveIconSize(double baseSize) =>
      responsiveFont(baseSize);

  static double fabSize() => 60.0;

  static double appBarHeight() => kToolbarHeight;

  static double spacingSmall() => screenWidth * 0.022;

  static double spacingMedium() => screenWidth * 0.033;

  static double spacingLarge() => screenWidth * 0.044;

  static double spacingExtraLarge() => screenWidth * 0.055;

  static double spacingCustom(double multiplier) => screenWidth * multiplier;

  static double getWidth(double percentage) =>
      screenWidth * (percentage / 100);

  static double getHeight(double percentage) =>
      screenHeight * (percentage / 100);

  static double responsiveWidth(double baseWidth) =>
      screenWidth * (baseWidth / 100);

  static double responsiveHeight(double baseHeight) =>
      screenHeight * (baseHeight / 100);

  static EdgeInsets responsivePaddingAll(double basePadding) {
    double scaleFactor = screenWidth / 414;
    return EdgeInsets.all(basePadding * scaleFactor);
  }

  static EdgeInsets responsivePaddingSymmetric({
    required double horizontal,
    required double vertical,
  }) {
    double scaleFactor = screenWidth / 414;
    return EdgeInsets.symmetric(
      horizontal: horizontal * scaleFactor,
      vertical: vertical * scaleFactor,
    );
  }

  static EdgeInsets responsivePaddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    double scaleFactor = screenWidth / 414;
    return EdgeInsets.only(
      left: left * scaleFactor,
      top: top * scaleFactor,
      right: right * scaleFactor,
      bottom: bottom * scaleFactor,
    );
  }


  static BorderRadius responsiveBorderRadiusAll(double baseRadius) {
    return BorderRadius.circular(responsiveSize(baseRadius / 414));
  }

  static BorderRadius cardBorderRadius() =>
      BorderRadius.circular(borderRadiusLarge());

  static BorderRadius buttonBorderRadius() =>
      BorderRadius.circular(borderRadiusMedium());


  static BoxShadow responsiveBoxShadow({
    Color color = Colors.black,
    double blurRadius = 8,
    double spreadRadius = 0,
    Offset offset = const Offset(0, 4),
    double opacity = 0.1,
  }) {
    double scaleFactor = screenWidth / 414;
    return BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blurRadius * scaleFactor,
      spreadRadius: spreadRadius * scaleFactor,
      offset: Offset(offset.dx * scaleFactor, offset.dy * scaleFactor),
    );
  }

  static List<BoxShadow> cardShadow() => [
    responsiveBoxShadow(
      color: Colors.black,
      blurRadius: 8,
      offset: const Offset(0, 4),
      opacity: 0.1,
    ),
  ];


  static TextStyle responsiveTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
    Color color = Colors.black,
    String fontFamily = 'SF Pro',
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: responsiveFont(fontSize),
      fontWeight: fontWeight,
      color: color,
      fontFamily: fontFamily,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle headerStyle({
    Color color = Colors.black,
    String fontFamily = 'SF Pro',
  }) =>
      responsiveTextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle subtitleStyle({
    Color color = Colors.black87,
    String fontFamily = 'SF Pro',
  }) =>
      responsiveTextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle bodyStyle({
    Color color = Colors.black,
    String fontFamily = 'SF Pro',
  }) =>
      responsiveTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        fontFamily: fontFamily,
      );


  static bool isMobile() => screenWidth < 600;

  static bool isTablet() => screenWidth >= 600 && screenWidth < 1200;

  static bool isDesktop() => screenWidth >= 1200;

  static bool isPortrait() =>
      _mediaQueryData.orientation == Orientation.portrait;

  static bool isLandscape() =>
      _mediaQueryData.orientation == Orientation.landscape;

  static double getAspectRatio() => screenWidth / screenHeight;


  static double getContainerWidth({
    required double mobileWidth,
    double? tabletWidth,
    double? desktopWidth,
  }) {
    if (isDesktop()) return desktopWidth ?? screenWidth * 0.8;
    if (isTablet()) return tabletWidth ?? screenWidth * 0.85;
    return screenWidth * (mobileWidth / 100);
  }

  static SizedBox responsiveHeightSizedBox(double baseHeight) =>
      SizedBox(height: responsiveHeight(baseHeight));

  static SizedBox responsiveWidthSizedBox(double baseWidth) =>
      SizedBox(width: responsiveWidth(baseWidth));

  static void printDeviceInfo() {
    debugPrint('Device Info');
    debugPrint('Screen Width: $screenWidth');
    debugPrint('Screen Height: $screenHeight');
    debugPrint('Device Type: ${isMobile() ? 'Mobile' : isTablet() ? 'Tablet' : 'Desktop'}');
    debugPrint('Orientation: ${isPortrait() ? 'Portrait' : 'Landscape'}');
    debugPrint('Aspect Ratio: ${getAspectRatio()}');
  }
}