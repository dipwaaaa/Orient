import 'package:flutter/material.dart';

/// Utility class untuk responsive design
/// Gunakan ini agar tidak perlu menulis MediaQuery di setiap file
class AppResponsive {
  static late double screenWidth;
  static late double screenHeight;

  /// Initialize AppResponsive di main.dart atau app.dart
  static void init(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
  }

  // Responsive padding berdasarkan screenWidth
  static double responsivePadding() => screenWidth * 0.044;

  // Responsive sizing untuk icon/button
  static double avatarRadius() => screenWidth * 0.088;
  static double notificationIconSize() => screenWidth * 0.069;
  static double borderRadiusLarge() => screenWidth * 0.069;

  // Responsive font sizes
  static double headerFontSize() => screenWidth * 0.069;
  static double subtitleFontSize() => screenWidth * 0.036;
  static double bodyFontSize() => screenWidth * 0.038;

  // Responsive spacing
  static double spacingSmall() => screenWidth * 0.022;
  static double spacingMedium() => screenWidth * 0.033;
  static double spacingLarge() => screenWidth * 0.044;
}