import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/avatar_service.dart';
import '../services/game_service.dart';
import '../utils/theme_utils.dart';
import '../screens/full_screen_image_screen.dart';

class ChatScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;

  const ChatScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GameService _gameService = GameService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  late Stream<List<ChatMessageModel>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = _gameService.chatMessagesStream(widget.friendUid);
    // Delay markAsRead to avoid triggering stream re-emission during initial build
    Future.delayed(const Duration(seconds: 1), _markAsRead);
  }

  Future<void> _markAsRead() async {
    await _gameService.markMessagesAsRead(widget.friendUid);
  }

  Future<void> _sendImage(String source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      final imageUrl = await _gameService.uploadChatImage(widget.friendUid, picked.path);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _gameService.sendChatMessage(
          widget.friendUid,
          widget.friendName,
          '',
          imageUrl: imageUrl,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                _sendImage('gallery');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                _sendImage('camera');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _scrollController.animateTo(
      maxExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _gameService.sendChatMessage(widget.friendUid, widget.friendName, message);
      _messageController.clear();
    } catch (e) {
      final errorStr = e.toString();
      // Restore the message text since it wasn't sent
      _messageController.text = message;
      if (mounted) {
        String userMessage;
        if (errorStr.contains('blocked by this user') || errorStr.contains('permission-denied')) {
          userMessage = '${widget.friendName} is not available to chat.';
        } else if (errorStr.contains('You have blocked')) {
          userMessage = 'You have blocked ${widget.friendName}. Unblock to send messages.';
        } else {
          userMessage = 'Failed to send message. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: appBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    StreamBuilder<Map<String, dynamic>>(
                      stream: AvatarService.instance.avatarStream(widget.friendUid),
                      builder: (context, snapshot) {
                        final data = snapshot.data ?? {};
                        final imageUrl = data['avatarUrl']?.toString();
                        final avatarEmoji = data['avatarEmoji']?.toString() ?? '';
                        final fallbackEmoji = data['avatar']?.toString() ?? '';
                        final emoji = avatarEmoji.isNotEmpty
                            ? avatarEmoji
                            : (fallbackEmoji.isNotEmpty ? fallbackEmoji : '😀');
                        return GestureDetector(
                          onTap: () => showFullScreenImage(
                            context,
                            imageUrl: imageUrl,
                            emoji: emoji,
                            title: widget.friendName,
                          ),
                          child: AvatarService.buildAvatar(
                            imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
                            emoji: emoji,
                            size: 44,
                            iconSize: 22,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.friendName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      debugPrint('ChatScreen stream error for ${widget.friendUid}: ${snapshot.error}');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    
                    final messages = snapshot.data ?? [];
                    debugPrint('ChatScreen: received ${messages.length} messages for ${widget.friendUid}');
                    
                    // Auto-scroll to bottom when new messages arrive
                    // Multiple calls ensure images are visible after they load
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
                    Future.delayed(const Duration(milliseconds: 800), _scrollToBottom);
                    
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start chatting with ${widget.friendName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.fromUid == _gameService.currentUid;
                        return _buildMessageBubble(message, isMe);
                      },
                    );
                  },
                ),
              ),

              // Input field
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSending ? null : _showImagePickerOptions,
                      icon: const Icon(Icons.image, color: Colors.white70),
                    ),
                    IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    if (message.isImage) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => showFullScreenImage(
            context,
            imageUrl: message.imageUrl,
            title: 'Image',
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF6D28D9).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(4) : null,
                bottomLeft: !isMe ? const Radius.circular(4) : null,
              ),
            ),
            width: MediaQuery.of(context).size.width * 0.65,
            height: 220,
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    // Image finished loading; scroll again to make sure it's visible
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    return child;
                  }
                  return const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Icon(Icons.broken_image, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF6D28D9).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : null,
            bottomLeft: !isMe ? const Radius.circular(4) : null,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.message,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
