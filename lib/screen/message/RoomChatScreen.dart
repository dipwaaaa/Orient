import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:untitled/service/encryption_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:mime/mime.dart';
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
      print('Error initializing chat: $e');
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
      print('Error sending message: $e');
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
                  color: Color(0xFFFFBD09),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Color(0xFFFF7A01),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.blue,
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
          color: color.withOpacity(0.2),
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
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadFile(File(image.path), 'image');
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadFile(File(image.path), 'image');
      }
    } catch (e) {
      print('Error taking photo: $e');
      _showErrorSnackBar('Failed to take photo');
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        await _uploadFile(file, 'document');
      }
    } catch (e) {
      print('Error picking document: $e');
      _showErrorSnackBar('Failed to pick document');
    }
  }

  Future<void> _uploadFile(File file, String fileType) async {
    if (_chatId == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final fileName = file.path.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child(
          'chats/$_chatId/$fileType/${timestamp}_$fileName'
      );

      // Upload file
      final uploadTask = storageRef.putFile(file);

      // Show progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Send message with file
      await _sendMessage(
        fileUrl: downloadUrl,
        fileName: fileName,
        fileType: fileType,
      );

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      print('Error uploading file: $e');
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar('Failed to upload file');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _markMessagesAsRead() async {
    if (_chatId == null) return;

    try {
      final unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: _chatId)
          .where('receiverId', isEqualTo: widget.currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFDEF3FF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.username.isNotEmpty
                      ? widget.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.username,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: !_isInitialized
            ? Center(child: CircularProgressIndicator())
            : Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _chatId == null
                      ? Center(child: CircularProgressIndicator())
                      : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('messages')
                        .where('chatId', isEqualTo: _chatId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 60,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Start a conversation',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Messages are end-to-end encrypted',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Sort messages manually by timestamp
                      final messages = snapshot.data!.docs;
                      messages.sort((a, b) {
                        final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (aTime == null || bTime == null) return 0;
                        return aTime.compareTo(bTime);
                      });

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markMessagesAsRead();
                        _scrollToBottom();
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageData = messages[index].data() as Map<String, dynamic>;
                          final isMe = messageData['senderId'] == widget.currentUserId;
                          final timestamp = messageData['timestamp'] as Timestamp?;
                          final time = timestamp != null
                              ? DateFormat('HH:mm').format(timestamp.toDate())
                              : '';

                          // Check if message has file attachment
                          final hasFile = messageData.containsKey('fileUrl');

                          String decryptedMessage = '';
                          if (messageData.containsKey('encryptedMessage')) {
                            try {
                              final encryptedMsg = messageData['encryptedMessage'];
                              final iv = messageData['iv'];
                              if (encryptedMsg != null && iv != null) {
                                decryptedMessage = EncryptionService.decryptMessage(
                                  encryptedMsg,
                                  iv,
                                  _chatId!,
                                );
                              }
                            } catch (e) {
                              print('Error decrypting message: $e');
                              decryptedMessage = '[Failed to decrypt]';
                            }
                          }

                          // Check if we need to show date divider
                          bool showDateDivider = false;
                          String? dateLabel;

                          if (timestamp != null) {
                            if (index == 0) {
                              showDateDivider = true;
                              dateLabel = _getDateLabel(timestamp.toDate());
                            } else {
                              final prevMessageData = messages[index - 1].data() as Map<String, dynamic>;
                              final prevTimestamp = prevMessageData['timestamp'] as Timestamp?;

                              if (prevTimestamp != null) {
                                final currentDate = DateTime(
                                  timestamp.toDate().year,
                                  timestamp.toDate().month,
                                  timestamp.toDate().day,
                                );
                                final prevDate = DateTime(
                                  prevTimestamp.toDate().year,
                                  prevTimestamp.toDate().month,
                                  prevTimestamp.toDate().day,
                                );

                                if (currentDate != prevDate) {
                                  showDateDivider = true;
                                  dateLabel = _getDateLabel(timestamp.toDate());
                                }
                              }
                            }
                          }

                          return Column(
                            children: [
                              if (showDateDivider && dateLabel != null)
                                _buildDateDivider(dateLabel),
                              _buildMessageBubble(
                                message: decryptedMessage,
                                isMe: isMe,
                                time: time,
                                isRead: messageData['isRead'] ?? false,
                                screenWidth: screenWidth,
                                screenHeight: screenHeight,
                                fileUrl: hasFile ? messageData['fileUrl'] : null,
                                fileName: hasFile ? messageData['fileName'] : null,
                                fileType: hasFile ? messageData['fileType'] : null,
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
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFFFBD09),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Uploading file...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDateLabel(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(messageDate);
    }
  }

  Widget _buildDateDivider(String dateLabel) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB84D),
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
          maxWidth: screenWidth * 0.71,  // Tetap ada batas maksimal
          minWidth: 60,  // Lebar minimum untuk menampung waktu
        ),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFF6D1A7) : const Color(0xFFFFF4CC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicWidth(  // Tambahkan IntrinsicWidth
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,  // Tambahkan ini
            children: [
              if (hasFile) ...[
                GestureDetector(
                  onTap: () => _openFile(fileUrl, fileName ?? 'file', fileType ?? 'unknown'),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getFileIcon(fileType ?? 'unknown'),
                          size: 24,
                          color: Colors.black,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            fileName ?? 'File',
                            style: TextStyle(
                              color: Colors.black,
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
                  padding: EdgeInsets.only(bottom: 4),  // Kurangi padding
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              // Time and read status at bottom right
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
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
                      color: Colors.black.withOpacity(0.6),
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
        vertical: 10,
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
          SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(width: 1, color: Colors.black),
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
                color: _isUploading ? Colors.grey : Colors.black,
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