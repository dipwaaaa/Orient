import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/service/auth_service.dart';
import 'package:untitled/service/encryption_service.dart';
import 'package:untitled/widget/NavigationBar.dart';
import 'package:untitled/widget/ProfileMenu.dart';
import 'RoomChatScreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _username = 'User';
  int _currentIndex = 2;
  List<ChatItem> _chatList = [];
  List<ChatItem> _filteredChatList = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredChatList = _chatList;
      } else {
        _filteredChatList = _chatList.where((chat) {
          return chat.username.toLowerCase().contains(query) ||
              chat.lastMessage.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _loadChats() {
    final user = _authService.currentUser;
    if (user == null) return;

    _authService.firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _chatList = snapshot.docs.map((doc) {
          final data = doc.data();
          final chatId = doc.id;
          final participants = data['participants'] as List<dynamic>;
          final participantDetails = data['participantDetails'] as Map<String, dynamic>;

          // Cari username lawan bicara
          final otherUserId = participants.firstWhere(
                (id) => id != user.uid,
            orElse: () => '',
          );

          final otherUserData = participantDetails[otherUserId] as Map<String, dynamic>?;
          final otherUsername = otherUserData?['username'] ?? 'Unknown';

          // Dekripsi last message
          String lastMessage = data['lastMessage'] ?? '';
          if (lastMessage.isNotEmpty) {
            try {
              lastMessage = EncryptionService.decryptLastMessage(lastMessage, chatId);
            } catch (e) {
              lastMessage = '[Encrypted]';
            }
          }

          // Format waktu
          final lastMessageTime = data['lastMessageTime'] as Timestamp?;
          String time = '';
          if (lastMessageTime != null) {
            final messageDate = lastMessageTime.toDate();
            final now = DateTime.now();

            if (messageDate.year == now.year &&
                messageDate.month == now.month &&
                messageDate.day == now.day) {
              time = DateFormat('HH:mm').format(messageDate);
            } else {
              time = DateFormat('dd/MM/yy').format(messageDate);
            }
          }

          return ChatItem(
            username: otherUsername,
            lastMessage: lastMessage,
            time: time,
            chatId: chatId,
          );
        }).toList();
        _filteredChatList = _chatList;
      });
    });
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
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
            username = _generateRandomUsername();
            // Simpan username baru ke Firestore
            await _authService.firestore
                .collection('users')
                .doc(user.uid)
                .set({
              'username': username,
              'email': user.email,
              'uid': user.uid,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          setState(() {
            _username = username;
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  String _generateRandomUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String username = 'user_';

    for (int i = 0; i < 8; i++) {
      username += chars[(random + i) % chars.length];
    }

    return username;
  }

  void _showAddChatDialog() {
    final TextEditingController controller = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.055),
          ),
          child: Container(
            width: screenWidth * 0.9,
            padding: EdgeInsets.all(screenWidth * 0.055),
            decoration: BoxDecoration(
              color: const Color(0xB2FFBD09),
              borderRadius: BorderRadius.circular(screenWidth * 0.055),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Email/Username',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.044,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFAAAAAA),
                    ),
                    borderRadius: BorderRadius.circular(screenWidth * 0.022),
                  ),
                  child: TextField(
                    controller: controller,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.044,
                        vertical: screenHeight * 0.015,
                      ),
                      isDense: true,
                      hintText: 'Enter email or username...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: screenWidth * 0.038,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.025),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: screenWidth * 0.038,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.022),
                    GestureDetector(
                      onTap: () async {
                        final input = controller.text.trim();
                        if (input.isNotEmpty) {
                          Navigator.pop(context);
                          await _findAndNavigateToUser(input);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.066,
                          vertical: screenHeight * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(screenWidth * 0.055),
                        ),
                        child: Text(
                          'Start Chat',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFFFBD09),
                            fontSize: screenWidth * 0.038,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _findAndNavigateToUser(String usernameOrEmail) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      QuerySnapshot userQuery;

      if (usernameOrEmail.contains('@')) {
        userQuery = await _authService.firestore
            .collection('users')
            .where('email', isEqualTo: usernameOrEmail)
            .limit(1)
            .get();
      } else {
        userQuery = await _authService.firestore
            .collection('users')
            .where('username', isEqualTo: usernameOrEmail)
            .limit(1)
            .get();
      }

      // Hide loading
      Navigator.pop(context);

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      final receiverUserId = userQuery.docs.first.id;
      final receiverUsername = userData['username'] ?? 'Unknown';

      if (receiverUserId == _authService.currentUser?.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You cannot chat with yourself'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomChatScreen(
            username: receiverUsername,
            currentUsername: _username,
            currentUserId: _authService.currentUser!.uid,
            receiverUserId: receiverUserId,
          ),
        ),
      );
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Error finding user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToRoomChat(String username, String chatId) async {
    try {
      final userQuery = await _authService.firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not found')),
        );
        return;
      }

      final receiverUserId = userQuery.docs.first.id;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomChatScreen(
            username: username,
            currentUsername: _username,
            currentUserId: _authService.currentUser!.uid,
            receiverUserId: receiverUserId,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening chat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              flex: 0,
              child: _buildHeader(screenWidth, screenHeight),
            ),
            Flexible(
              flex: 0,
              child: _buildSearchBar(screenWidth, screenHeight),
            ),
            Expanded(
              child: _filteredChatList.isEmpty
                  ? Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'No messages yet\nTap + to start a new chat'
                      : 'No chats found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: screenWidth * 0.044,
                    fontFamily: 'SF Pro',
                  ),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.044,
                  vertical: screenHeight * 0.01,
                ),
                itemCount: _filteredChatList.length,
                itemBuilder: (context, index) {
                  return _buildChatListItem(
                    _filteredChatList[index],
                    screenWidth,
                    screenHeight,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onIndexChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      floatingActionButton: Container(
        width: screenWidth * 0.12,
        height: screenWidth * 0.12,
        decoration: BoxDecoration(
          color: const Color(0xFFFFBD09),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: screenWidth * 0.022,
              offset: Offset(0, screenHeight * 0.005),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.add, color: Colors.black, size: screenWidth * 0.066),
          onPressed: _showAddChatDialog,
        ),
      ),
    );
  }

  Widget _buildChatListItem(ChatItem chat, double screenWidth, double screenHeight) {
    return GestureDetector(
      onTap: () => _navigateToRoomChat(chat.username, chat.chatId),
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.01),
        padding: EdgeInsets.all(screenWidth * 0.019),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFE100), const Color(0xFFFDEF85)],
          ),
          borderRadius: BorderRadius.circular(screenWidth * 0.022),
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.11,
              height: screenWidth * 0.11,
              decoration: BoxDecoration(
                color: const Color(0xFFDEF3FF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  chat.username.isNotEmpty
                      ? chat.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.049,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.022),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.username,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: screenWidth * 0.036,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            height: 1.69,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.022),
                      Text(
                        chat.time,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: screenWidth * 0.022,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w300,
                          height: 2.75,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    chat.lastMessage.isEmpty
                        ? 'No messages yet'
                        : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.7),
                      fontSize: screenWidth * 0.027,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w300,
                      height: 2.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.044),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hi, $_username!',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.069,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  'What event are you planning today?',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.036,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(screenWidth * 0.022),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(screenWidth * 0.069),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: screenWidth * 0.089,
                  height: screenWidth * 0.089,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: screenWidth * 0.069,
                  ),
                ),
                SizedBox(width: screenWidth * 0.022),
                GestureDetector(
                  onTap: () {
                    ProfileMenu.show(context, _authService, _username);
                  },
                  child: Container(
                    width: screenWidth * 0.088,
                    height: screenWidth * 0.088,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFDEF3FF),
                    ),
                    child: ClipOval(
                      child: _authService.currentUser?.photoURL != null
                          ? Image.network(
                        _authService.currentUser!.photoURL!,
                        fit: BoxFit.cover,
                      )
                          : Image.asset(
                        'assets/image/AvatarKimmy.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(double screenWidth, double screenHeight) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.044),
      height: screenHeight * 0.050,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color(0xFFFF7A01),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.014),
      ),
      child: Row(
        children: [
          SizedBox(width: screenWidth * 0.033),
          Icon(
            Icons.search,
            color: Colors.black.withOpacity(0.6),
            size: screenWidth * 0.058,
          ),
          SizedBox(width: screenWidth * 0.022),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: screenWidth * 0.041,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: screenHeight * 0.017),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatItem {
  final String username;
  final String lastMessage;
  final String time;
  final String chatId;

  ChatItem({
    required this.username,
    required this.lastMessage,
    required this.time,
    required this.chatId,
  });
}