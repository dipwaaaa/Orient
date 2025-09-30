import 'package:flutter/material.dart';
import 'dart:async';
import '../../widget/Animated_Gradient_Background.dart';

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
      home: const ChatbotScreen(),
    );
  }
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: _messageController.text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _messageController.clear();

    // Simulate bot response
    _simulateBotResponse();
  }

  void _simulateBotResponse() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Thanks for your message! How can I help you today?",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedGradientBackground(
        duration: const Duration(seconds: 4),
        radius: 2.00,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(screenWidth, screenHeight),
              Expanded(child: _buildChatArea(screenWidth, screenHeight)),
              _buildMessageInput(screenWidth, screenHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight) {
    final headerPadding = screenWidth * 0.05; // 5% of screen width
    final avatarSize = screenWidth * 0.125; // 12.5% of screen width
    final namesFontSize = screenWidth * 0.06; // 6% of screen width
    final statusFontSize = screenWidth * 0.035; // 3.5% of screen width

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: headerPadding,
              vertical: screenHeight * 0.02
          ),
          child: Row(
            children: [
              _buildBotAvatar(avatarSize),
              SizedBox(width: screenWidth * 0.045),
              _buildBotInfo(namesFontSize, statusFontSize),
              const Spacer(),
            ],
          ),
        ),
        Container(
          height: screenHeight * 0.003,
          color: Colors.black,
        ),
      ],
    );
  }

  Widget _buildBotAvatar(double avatarSize) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: const BoxDecoration(
        color: Color(0xFFDEF3FF),
        shape: BoxShape.circle,
      ),
      child: Image.asset('assets/image/AvatarKimmy.png'),
    );
  }

  Widget _buildBotInfo(double namesFontSize, double statusFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kinny',
          style: TextStyle(
            color: Colors.black,
            fontSize: namesFontSize.clamp(20.0, 28.0),
            fontWeight: FontWeight.w500,
            height: 0.88,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Online',
          style: TextStyle(
            color: Colors.black54,
            fontSize: statusFontSize.clamp(12.0, 16.0),
            fontWeight: FontWeight.w500,
            height: 1.57,
          ),
        ),
      ],
    );
  }

  Widget _buildChatArea(double screenWidth, double screenHeight) {
    if (_messages.isEmpty) {
      final emptyIconSize = screenWidth * 0.16; // 16% of screen width
      final emptyTextSize = screenWidth * 0.04; // 4% of screen width

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: emptyIconSize,
              color: Colors.black26,
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'Start a conversation with Kinny',
              style: TextStyle(
                color: Colors.black54,
                fontSize: emptyTextSize.clamp(14.0, 18.0),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index], screenWidth);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, double screenWidth) {
    final bubblePadding = screenWidth * 0.04; // 4% of screen width
    final messageFontSize = screenWidth * 0.04; // 4% of screen width
    final borderRadius = screenWidth * 0.05; // 5% of screen width

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
        padding: EdgeInsets.symmetric(
          horizontal: bubblePadding,
          vertical: screenWidth * 0.03,
        ),
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFFFF6A00)
              : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black,
            fontSize: messageFontSize.clamp(14.0, 18.0),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput(double screenWidth, double screenHeight) {
    final inputPadding = screenWidth * 0.04; // 4% of screen width
    final borderRadius = screenWidth * 0.025; // 2.5% of screen width
    final hintFontSize = screenWidth * 0.035; // 3.5% of screen width
    final sendButtonSize = screenWidth * 0.1; // 10% of screen width
    final sendIconSize = screenWidth * 0.05; // 5% of screen width

    return Container(
      padding: EdgeInsets.all(inputPadding),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.black,
                    width: screenWidth * 0.005
                ),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: hintFontSize.clamp(14.0, 16.0),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your message',
                  hintStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: hintFontSize.clamp(12.0, 16.0),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.01,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: sendButtonSize,
              height: sendButtonSize,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6A00),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send,
                color: Colors.white,
                size: sendIconSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}