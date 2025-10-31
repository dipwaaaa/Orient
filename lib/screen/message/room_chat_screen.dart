import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:untitled/service/encryption_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class RoomChatScreen extends StatefulWidget {
  final String username;
  final String currentUsername;
  final String currentUserId;
  final String receiverUserId;

  const RoomChatScreen({
    super.key,
    required this.username,
    required this.currentUsername,
    required this.currentUserId,
    required this.receiverUserId,
  });

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  String? _chatId;
  bool _isInitialized = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  String _generateChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _initializeChat() async {
    _chatId = _generateChatId(widget.currentUserId, widget.receiverUserId);

    try {
      final chatDoc = await _firestore.collection('chats').doc(_chatId).get();

      if (!chatDoc.exists) {
        await _firestore.collection('chats').doc(_chatId).set({
          'chatId': _chatId,
          'participants': [widget.currentUserId, widget.receiverUserId],
          'participantDetails': {
            widget.currentUserId: {
              'username': widget.currentUsername,
            },
            widget.receiverUserId: {
              'username': widget.username,
            },
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage({String? fileUrl, String? fileName, String? fileType}) async {
    if ((_messageController.text.trim().isEmpty && fileUrl == null) || _chatId == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final messageRef = _firestore.collection('messages').doc();
      Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'chatId': _chatId,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Jika ada file attachment
      if (fileUrl != null) {
        messageData['fileUrl'] = fileUrl;
        messageData['fileName'] = fileName ?? 'file';
        messageData['fileType'] = fileType ?? 'unknown';

        // Enkripsi caption jika ada
        if (messageText.isNotEmpty) {
          final encryptedData = EncryptionService.encryptMessage(messageText, _chatId!);
          messageData['encryptedMessage'] = encryptedData['encryptedMessage'];
          messageData['iv'] = encryptedData['iv'];
        }
      } else {
        // Pesan text biasa
        final encryptedData = EncryptionService.encryptMessage(messageText, _chatId!);
        messageData['encryptedMessage'] = encryptedData['encryptedMessage'];
        messageData['iv'] = encryptedData['iv'];
      }

      await messageRef.set(messageData);

      // Update last message
      String lastMessagePreview = fileUrl != null
          ? '📎 ${fileName ?? 'File'}'
          : messageText;
      final encryptedLastMessage = EncryptionService.encryptLastMessage(lastMessagePreview, _chatId!);

      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': encryptedLastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': widget.currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Color(0xFFFF9800),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Color(0xFFFF9800),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Color(0xFFFF9800),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro',
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _uploadFile(File(image.path), 'image');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _uploadFile(File(image.path), 'image');
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo')),
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        await _uploadFile(File(result.files.single.path!), 'document');
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick document')),
      );
    }
  }

  Future<void> _uploadFile(File file, String fileType) async {
    if (_chatId == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final fileName = file.path.split('/').last;
      final storageRef = _storage.ref().child('chat_attachments/$_chatId/$fileName');

      await storageRef.putFile(file);
      final fileUrl = await storageRef.getDownloadURL();

      await _sendMessage(
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
      );
    } catch (e) {
      debugPrint('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Avatar TANPA background warna
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Center(
                child: Text(
                  widget.username[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: !_isInitialized
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('chatId', isEqualTo: _chatId)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageData = messageDoc.data() as Map<String, dynamic>;

                    final isMe = messageData['senderId'] == widget.currentUserId;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final isRead = messageData['isRead'] ?? false;

                    // Dekripsi pesan
                    String messageText = '';
                    if (messageData['encryptedMessage'] != null && messageData['iv'] != null) {
                      messageText = EncryptionService.decryptMessage(
                        messageData['encryptedMessage'],
                        messageData['iv'],
                        _chatId!,
                      );
                    }

                    final fileUrl = messageData['fileUrl'];
                    final fileName = messageData['fileName'];
                    final fileType = messageData['fileType'];

                    // Format waktu
                    String timeString = '';
                    if (timestamp != null) {
                      final dateTime = timestamp.toDate();
                      timeString = DateFormat('HH:mm').format(dateTime);
                    }

                    // Tampilkan date label jika perlu
                    bool showDateLabel = false;
                    String dateLabel = '';
                    if (index == 0 || (index > 0 && timestamp != null)) {
                      final currentDate = timestamp?.toDate();
                      final previousTimestamp = index > 0
                          ? (messages[index - 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?
                          : null;
                      final previousDate = previousTimestamp?.toDate();

                      if (currentDate != null &&
                          (previousDate == null ||
                              currentDate.day != previousDate.day ||
                              currentDate.month != previousDate.month ||
                              currentDate.year != previousDate.year)) {
                        showDateLabel = true;
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final yesterday = today.subtract(Duration(days: 1));
                        final messageDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

                        if (messageDate == today) {
                          dateLabel = 'Today';
                        } else if (messageDate == yesterday) {
                          dateLabel = 'Yesterday';
                        } else {
                          dateLabel = DateFormat('MMMM d, yyyy').format(currentDate);
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (showDateLabel) _buildDateLabel(dateLabel),
                        _buildMessageBubble(
                          message: messageText,
                          isMe: isMe,
                          time: timeString,
                          isRead: isRead,
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          fileUrl: fileUrl,
                          fileName: fileName,
                          fileType: fileType,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(screenWidth, screenHeight),
        ],
      ),
    );
  }

  Widget _buildDateLabel(String dateLabel) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 16),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Color(0xFFFF9800),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dateLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMe,
    required String time,
    required bool isRead,
    required double screenWidth,
    required double screenHeight,
    String? fileUrl,
    String? fileName,
    String? fileType,
  }) {
    final hasFile = fileUrl != null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.71,
          minWidth: 60,
        ),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          // Bubble pengirim: #FFF6D2A7, penerima: kuning pastel
          color: isMe ? Color(0xFFF6D2A7) : Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasFile) ...[
                GestureDetector(
                  onTap: () => _openFile(fileUrl, fileName ?? 'file', fileType ?? 'unknown'),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getFileIcon(fileType ?? 'unknown'),
                          size: 24,
                          color: Colors.black87,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            fileName ?? 'File',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (message.isNotEmpty) SizedBox(height: 8),
              ],
              if (message.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  if (isMe) ...[
                    SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 12,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    if (fileType == 'image') {
      return Icons.image;
    } else if (fileType == 'document') {
      return Icons.description;
    }
    return Icons.attach_file;
  }

  void _openFile(String fileUrl, String fileName, String fileType) async {
    try {
      final Uri url = Uri.parse(fileUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file')),
      );
    }
  }

  Widget _buildMessageInput(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.attach_file,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: _isUploading ? null : _showAttachmentOptions,
            ),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(width: 1, color: Colors.black), // Border HITAM
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                textAlignVertical: TextAlignVertical.center,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isUploading,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 12),
          GestureDetector(
            onTap: _isUploading ? null : () => _sendMessage(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isUploading ? Colors.grey : Colors.black, // Tombol HITAM
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}