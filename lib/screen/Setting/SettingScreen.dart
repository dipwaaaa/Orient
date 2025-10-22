import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';
import 'ProfileScreen.dart';

class SettingScreen extends StatelessWidget {
  final AuthService authService;

  const SettingScreen({
    Key? key,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 17,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // My Profile Option
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(authService: authService),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(width: 1, color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 30, color: Colors.black),
                    SizedBox(width: 15),
                    Text(
                      'My Profile',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // Notification Option
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notification settings coming soon!')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(width: 1, color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications, size: 30, color: Colors.black),
                    SizedBox(width: 15),
                    Text(
                      'Notification',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}