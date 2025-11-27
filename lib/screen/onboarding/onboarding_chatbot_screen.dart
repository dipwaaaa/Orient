import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../widget/Animated_Gradient_Background.dart';
import '../home/home_screen.dart';

class OnboardingChatbotScreen extends StatefulWidget {
  const OnboardingChatbotScreen({super.key});

  @override
  State<OnboardingChatbotScreen> createState() => _OnboardingChatbotScreenState();
}

class _OnboardingChatbotScreenState extends State<OnboardingChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  int _currentStep = 0;

  String? _eventType;
  String? _eventName;
  DateTime? _eventDate;

  final List<String> _eventTypes = [
    'Wedding',
    'Birthday',
    'Corporate Event',
    'Conference',
    'Workshop',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _startOnboarding();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startOnboarding() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _addBotMessage(
        'Hai! Saya Kinny, asisten event organizer Anda\n\n'
            'Saya akan membantu Anda setup event pertama. '
            'Mari kita mulai dengan pertanyaan sederhana!'
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    _showEventTypeOptions();
  }

  void _showEventTypeOptions() {
    setState(() {
      _currentStep = 1;
    });
    _addBotMessage('Jenis event apa yang ingin Anda rencanakan?');
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleEventTypeSelection(String type) async {
    setState(() {
      _eventType = type;
      _isSending = true;
    });

    _addUserMessage(type);
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _currentStep = 2;
      _isSending = false;
    });

    _addBotMessage(
        'Bagus! $type ya\n\n'
            'Apa nama event Anda? (Contoh: "Wedding John & Jane")'
    );
  }

  Future<void> _handleEventNameSubmit() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _eventName = _messageController.text.trim();
      _isSending = true;
    });

    _addUserMessage(_eventName!);
    _messageController.clear();
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _currentStep = 3;
      _isSending = false;
    });

    _addBotMessage(
        'Sempurna! "$_eventName"\n\n'
            'Kapan event Anda akan berlangsung? '
            'Pilih tanggal di bawah ini:'
    );
  }

  Future<void> _handleDateSelection(DateTime date) async {
    setState(() {
      _eventDate = date;
      _isSending = true;
    });

    final formattedDate = '${date.day}/${date.month}/${date.year}';
    _addUserMessage(formattedDate);
    await Future.delayed(const Duration(milliseconds: 800));

    final daysUntil = date.difference(DateTime.now()).inDays;

    _addBotMessage(
        'Terima kasih!\n\n'
            'Event Anda "$_eventName" dijadwalkan pada $formattedDate '
            '($daysUntil hari lagi).\n\n'
            'Saya akan membantu Anda mengelola semua aspek event ini!'
    );

    await Future.delayed(const Duration(milliseconds: 1500));

    _addBotMessage(
        'Setup selesai!\n\n'
            'Sekarang Anda bisa mulai menambahkan task, budget, vendor, dan tamu. '
            'Mari kita mulai!'
    );

    await _saveEventToFirestore();
  }

  Future<void> _saveEventToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final eventRef = _firestore.collection('events').doc();

      await eventRef.set({
        'eventId': eventRef.id,
        'eventName': _eventName,
        'eventType': _eventType,
        'eventDate': Timestamp.fromDate(_eventDate!),
        'description': '',
        'ownerId': user.uid,
        'collaborators': [],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'hasCompletedOnboarding': true,
        'firstEventId': eventRef.id,
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error saving event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
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
              if (_isSending) _buildTypingIndicator(screenWidth),
              _buildInputArea(screenWidth, screenHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight) {
    final headerPadding = screenWidth * 0.05;
    final avatarSize = screenWidth * 0.125;
    final namesFontSize = screenWidth * 0.06;
    final statusFontSize = screenWidth * 0.035;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: headerPadding,
            vertical: screenHeight * 0.02,
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
      final emptyIconSize = screenWidth * 0.16;
      final emptyTextSize = screenWidth * 0.04;

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
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index], screenWidth);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, double screenWidth) {
    final bubblePadding = screenWidth * 0.04;
    final messageFontSize = screenWidth * 0.04;
    final borderRadius = screenWidth * 0.05;

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
          color: message.isUser ? const Color(0xFF000000) : Color(0xFFFFBD09),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildTypingIndicator(double screenWidth) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.03),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(double screenWidth, double screenHeight) {
    if (_currentStep == 1) {
      return Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _eventTypes.map((type) {
            return ElevatedButton(
              onPressed: _isSending ? null : () => _handleEventTypeSelection(type),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(type),
            );
          }).toList(),
        ),
      );
    }

    if (_currentStep == 2) {
      final inputPadding = screenWidth * 0.04;
      final borderRadius = screenWidth * 0.025;
      final hintFontSize = screenWidth * 0.035;
      final sendButtonSize = screenWidth * 0.1;
      final sendIconSize = screenWidth * 0.05;

      return Container(
        padding: EdgeInsets.all(inputPadding),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black,
                    width: screenWidth * 0.005,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !_isSending,
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
                  onSubmitted: (_) => _handleEventNameSubmit(),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            GestureDetector(
              onTap: _isSending ? null : _handleEventNameSubmit,
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

    if (_currentStep == 3) {
      return Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSending ? null : _showDatePicker,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.calendar_today),
                SizedBox(width: 8),
                Text('Pilih Tanggal Event'),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF6A00),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _handleDateSelection(picked);
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}