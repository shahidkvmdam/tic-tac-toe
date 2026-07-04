import 'dart:async';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../utils/theme_utils.dart';
import '../screens/online_game_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/user_search_screen.dart';

class SentRequestsScreen extends StatefulWidget {
  final List<String> highlightAcceptedIds;

  const SentRequestsScreen({
    super.key,
    this.highlightAcceptedIds = const [],
  });

  @override
  State<SentRequestsScreen> createState() => _SentRequestsScreenState();
}

class _SentRequestsScreenState extends State<SentRequestsScreen> {
  final GameService _gameService = GameService();
  List<InvitationModel> _sentInvitations = [];
  List<InvitationModel> _acceptedReceived = [];
  List<InvitationModel> _incomingInvitations = [];
  StreamSubscription? _sentSubscription;
  StreamSubscription? _acceptedReceivedSubscription;
  StreamSubscription? _incomingSubscription;

  // Game requests and messages
  List<GameRequestModel> _incomingGameRequests = [];
  List<GameRequestModel> _outgoingGameRequests = [];
  List<String> _unreadMessageSenders = [];
  final Set<String> _processedAcceptedRequestIds = {};
  StreamSubscription? _incomingGameRequestSubscription;
  StreamSubscription? _outgoingGameRequestSubscription;
  StreamSubscription? _acceptedGameRequestSubscription;
  StreamSubscription? _unreadMessagesSubscription;
  StreamSubscription? _blockedUsersSubscription;
  bool _isLoading = true;
  List<String> _blockedUids = [];

  // Tab selection: 'friends', 'sent', 'requests'
  String _selectedTab = 'friends';

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _sentSubscription?.cancel();
    _acceptedReceivedSubscription?.cancel();
    _incomingSubscription?.cancel();
    _incomingGameRequestSubscription?.cancel();
    _outgoingGameRequestSubscription?.cancel();
    _unreadMessagesSubscription?.cancel();
    _blockedUsersSubscription?.cancel();

    if (_gameService.currentUid.isNotEmpty) {
      // Listen to sent invitations
      _sentSubscription = _gameService.allSentInvitationsStream().listen(
        (invitations) {
          if (mounted) {
            setState(() {
              _sentInvitations = invitations;
              _isLoading = false;
            });
          }
        },
        onError: (e) {
          debugPrint('Sent invitations stream error: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );

      // Listen to accepted received invitations (people you accepted)
      _acceptedReceivedSubscription = _gameService.acceptedReceivedInvitationsStream().listen(
        (invitations) {
          if (mounted) {
            setState(() {
              _acceptedReceived = invitations;
              _isLoading = false;
            });
          }
        },
        onError: (e) {
          debugPrint('Accepted received stream error: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );

      // Listen to pending incoming invitations
      _incomingSubscription = _gameService.incomingInvitationsStream().listen(
        (invitations) {
          if (mounted) {
            setState(() {
              _incomingInvitations = invitations;
              _isLoading = false;
            });
          }
        },
        onError: (e) {
          debugPrint('Incoming invitations stream error: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );

      // Listen to incoming game requests
      _incomingGameRequestSubscription = _gameService.incomingGameRequestsStream().listen(
        (requests) {
          if (mounted) {
            setState(() => _incomingGameRequests = requests);
          }
        },
        onError: (e) => debugPrint('Incoming game requests error: $e'),
      );

      // Listen to outgoing game requests
      _outgoingGameRequestSubscription = _gameService.outgoingGameRequestsStream().listen(
        (requests) {
          if (mounted) {
            setState(() => _outgoingGameRequests = requests);
          }
        },
        onError: (e) => debugPrint('Outgoing game requests error: $e'),
      );

      // Listen to ACCEPTED outgoing game requests (to navigate to game when recipient accepts)
      // Wait a moment before listening to avoid processing old requests immediately
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _acceptedGameRequestSubscription = _gameService.acceptedOutgoingGameRequestsStream().listen(
          (acceptedRequests) async {
            debugPrint('Accepted outgoing requests received: ${acceptedRequests.length}');
            for (final request in acceptedRequests) {
              debugPrint('Checking request ${request.requestId} - processed: ${_processedAcceptedRequestIds.contains(request.requestId)}, gameId: ${request.gameId}');
              // Only navigate if this is a newly accepted request (not already processed)
              if (!_processedAcceptedRequestIds.contains(request.requestId)) {
                if (request.gameId != null && request.gameId!.isNotEmpty) {
                  // Verify the game still exists before navigating
                  final game = await _gameService.getGame(request.gameId!);
                  if (game == null) {
                    debugPrint('Game ${request.gameId} no longer exists, skipping navigation');
                    _processedAcceptedRequestIds.add(request.requestId);
                    continue;
                  }
                  
                  debugPrint('Game request accepted! Navigating to game: ${request.gameId}');
                  _processedAcceptedRequestIds.add(request.requestId);
                  // Navigate to the game
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => OnlineGameScreen(gameId: request.gameId!, returnToSentRequests: true),
                      ),
                    );
                  }
                  break; // Only navigate to the first new accepted request
                }
              }
            }
          },
          onError: (e) => debugPrint('Accepted game requests error: $e'),
        );
      });

      // Listen to unread messages
      _unreadMessagesSubscription = _gameService.unreadMessageSendersStream().listen(
        (senders) {
          if (mounted) {
            setState(() => _unreadMessageSenders = senders);
          }
        },
        onError: (e) => debugPrint('Unread messages error: $e'),
      );

      // Listen to blocked users
      _blockedUsersSubscription = _gameService.blockedUidsStream().listen(
        (uids) {
          if (mounted) {
            setState(() => _blockedUids = uids);
          }
        },
        onError: (e) => debugPrint('Blocked users stream error: $e'),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptInvitation(InvitationModel invitation) async {
    try {
      await _gameService.acceptInvitation(
        invitation.invitationId,
        invitation.fromUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(String invitationId) async {
    try {
      await _gameService.declineInvitation(invitationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _sentSubscription?.cancel();
    _acceptedReceivedSubscription?.cancel();
    _incomingSubscription?.cancel();
    _incomingGameRequestSubscription?.cancel();
    _outgoingGameRequestSubscription?.cancel();
    _acceptedGameRequestSubscription?.cancel();
    _unreadMessagesSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    super.dispose();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get filtered lists based on selected tab
    final filteredList = _getFilteredList();

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
                    const Expanded(
                      child: Text(
                        'Requests',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_search, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UserSearchScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Tab buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildTabButton('friends', 'Friends', Icons.people,
                        badgeCount: _unreadMessageSenders.length),
                    const SizedBox(width: 8),
                    _buildTabButton('sent', 'Sent', Icons.send),
                    const SizedBox(width: 8),
                    _buildTabButton('requests', 'Requests', Icons.mail,
                        badgeCount: _incomingInvitations.length + _incomingGameRequests.length),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : filteredList.isEmpty
                        ? _buildEmptyState()
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: filteredList,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _getFilteredList() {
    switch (_selectedTab) {
      case 'friends':
        // Friends = accepted sent + accepted received with Play buttons
        final acceptedSent = _sentInvitations
            .where((inv) => inv.status == 'accepted')
            .map((inv) => _buildFriendCard(
                  invitation: inv,
                  isSentByMe: true,
                  isHighlighted: widget.highlightAcceptedIds.contains(inv.invitationId),
                ));
        final acceptedReceived = _acceptedReceived
            .map((inv) => _buildFriendCard(
                  invitation: inv,
                  isSentByMe: false,
                  isHighlighted: false,
                ));
        return [...acceptedSent, ...acceptedReceived];

      case 'sent':
        // Sent = pending sent invitations
        return _sentInvitations
            .where((inv) => inv.status == 'pending')
            .map((inv) => _buildInvitationCard(
                  invitation: inv,
                  isSentByMe: true,
                  isHighlighted: false,
                ))
            .toList();

      case 'requests':
        // Requests = pending incoming invitations
        return _incomingInvitations
            .map((inv) => _buildIncomingCard(inv))
            .toList();

      default:
        return [];
    }
  }

  // Check if there's a pending game request from a friend
  bool _hasPendingGameRequest(String friendUid) {
    return _incomingGameRequests.any((req) => req.fromUid == friendUid && req.status == 'pending');
  }

  // Check if there's a pending outgoing game request to a friend
  bool _hasPendingOutgoingGameRequest(String friendUid) {
    return _outgoingGameRequests.any((req) => req.toUid == friendUid && req.status == 'pending');
  }

  // Get pending game request from friend
  GameRequestModel? _getPendingGameRequest(String friendUid) {
    return _incomingGameRequests
        .firstWhere((req) => req.fromUid == friendUid && req.status == 'pending', orElse: () => null as GameRequestModel);
  }

  // Check if there are unread messages from friend
  bool _hasUnreadMessages(String friendUid) {
    return _unreadMessageSenders.contains(friendUid);
  }

  Widget _buildEmptyState() {
    String message;
    String subMessage;
    IconData icon;

    switch (_selectedTab) {
      case 'friends':
        message = 'No friends yet';
        subMessage = 'Accepted invitations will appear here';
        icon = Icons.people_outline;
        break;
      case 'sent':
        message = 'No pending requests';
        subMessage = 'Sent invitations will appear here';
        icon = Icons.send_outlined;
        break;
      case 'requests':
        message = 'No incoming requests';
        subMessage = 'When someone sends you a request, it will appear here';
        icon = Icons.mail_outline;
        break;
      default:
        message = 'No data';
        subMessage = '';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label, IconData icon, {int badgeCount = 0}) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6D28D9).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6D28D9)
                  : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF6D28D9) : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6D28D9) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Send play request to a friend
  Future<void> _sendGameRequest(String toUid, String toName) async {
    try {
      await _gameService.sendGameRequest(toUid, toName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Play request sent to $toName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send play request: $e')),
        );
      }
    }
  }

  // Accept a game request and navigate to game
  Future<void> _acceptGameRequest(GameRequestModel request) async {
    try {
      final gameId = await _gameService.acceptGameRequest(request.requestId, request.fromUid);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnlineGameScreen(gameId: gameId, returnToSentRequests: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e')),
        );
      }
    }
  }

  // Decline a game request
  Future<void> _declineGameRequest(String requestId) async {
    try {
      await _gameService.declineGameRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Play request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    }
  }

  // Navigate to chat screen
  void _openChat(String friendUid, String friendName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friendUid: friendUid,
          friendName: friendName,
        ),
      ),
    );
  }

  // Show block/unblock popup on long press
  void _showFriendOptions(String friendUid, String friendName) {
    final isBlocked = _blockedUids.contains(friendUid);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              friendName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                isBlocked ? Icons.lock_open : Icons.block,
                color: isBlocked ? Colors.green : Colors.red,
              ),
              title: Text(
                isBlocked ? 'Unblock' : 'Block',
                style: TextStyle(color: isBlocked ? Colors.green : Colors.red),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                if (isBlocked) {
                  _unblockFriend(friendUid, friendName);
                } else {
                  _blockFriend(friendUid, friendName);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Friend', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                // Find the invitation for this friend
                final inv = _sentInvitations.cast<InvitationModel?>().firstWhere(
                  (inv) => inv != null && inv.toUid == friendUid,
                  orElse: () => _acceptedReceived.cast<InvitationModel?>().firstWhere(
                    (inv) => inv != null && inv.fromUid == friendUid,
                    orElse: () => null,
                  ),
                );
                if (inv != null) {
                  final isSentByMe = inv.fromUid == _gameService.currentUid;
                  _deleteFriend(inv, isSentByMe, friendName);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blockFriend(String friendUid, String friendName) async {
    try {
      await _gameService.blockUser(friendUid, friendName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendName blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block: $e')),
        );
      }
    }
  }

  Future<void> _unblockFriend(String friendUid, String friendName) async {
    try {
      await _gameService.unblockUser(friendUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendName unblocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e')),
        );
      }
    }
  }

  // Delete a friend (remove the invitation)
  Future<void> _deleteFriend(InvitationModel invitation, bool isSentByMe, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Remove Friend',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove $friendName from your friends?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _gameService.deleteInvitation(invitation.invitationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$friendName removed from friends')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove friend: $e')),
          );
        }
      }
    }
  }

  Widget _buildFriendCard({
    required InvitationModel invitation,
    required bool isSentByMe,
    bool isHighlighted = false,
  }) {
    // Get friend info
    final friendUid = isSentByMe ? invitation.toUid : invitation.fromUid;
    final friendName = isSentByMe
        ? (invitation.toName.isNotEmpty ? invitation.toName : 'Unknown Player')
        : (invitation.fromName.isNotEmpty ? invitation.fromName : 'Unknown Player');

    // Check states
    final hasIncomingGameRequest = _hasPendingGameRequest(friendUid);
    final hasOutgoingGameRequest = _hasPendingOutgoingGameRequest(friendUid);
    final hasUnreadMessages = _hasUnreadMessages(friendUid);

    // Get the pending game request if exists
    final pendingRequest = hasIncomingGameRequest ? _getPendingGameRequest(friendUid) : null;

    // Determine highlight color
    final highlightColor = hasIncomingGameRequest ? Colors.green : const Color(0xFF6D28D9);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? highlightColor.withValues(alpha: 0.25)
            : hasUnreadMessages
                ? const Color(0xFF6D28D9).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? highlightColor.withValues(alpha: 0.8)
              : hasUnreadMessages
                  ? const Color(0xFF6D28D9).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.15),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        // Click name to open chat
        onTap: () => _openChat(friendUid, friendName),
        // Long press to show block/unblock options
        onLongPress: () => _showFriendOptions(friendUid, friendName),
        leading: Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasIncomingGameRequest
                    ? Colors.green.withValues(alpha: 0.3)
                    : hasUnreadMessages
                        ? const Color(0xFF6D28D9).withValues(alpha: 0.3)
                        : const Color(0xFF6D28D9).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasUnreadMessages ? Icons.mark_email_unread : Icons.person,
                color: hasIncomingGameRequest
                    ? Colors.green
                    : hasUnreadMessages
                        ? const Color(0xFF6D28D9)
                        : const Color(0xFF6D28D9),
              ),
            ),
            // Unread messages indicator
            if (hasUnreadMessages)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friendName,
          style: TextStyle(
            color: _blockedUids.contains(friendUid)
                ? Colors.red
                : hasIncomingGameRequest || isHighlighted ? highlightColor : Colors.white,
            fontWeight: hasUnreadMessages || isHighlighted ? FontWeight.w900 : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (_blockedUids.contains(friendUid))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Blocked',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (hasUnreadMessages)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'New message!',
                  style: TextStyle(
                    color: Color(0xFF6D28D9),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        // Play button on the right
        trailing: hasIncomingGameRequest
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accept button
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _acceptGameRequest(pendingRequest!),
                  ),
                  // Decline button
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _declineGameRequest(pendingRequest!.requestId),
                  ),
                ],
              )
            : hasOutgoingGameRequest
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Waiting...',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play button
                      ElevatedButton.icon(
                        onPressed: () => _sendGameRequest(friendUid, friendName),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Play'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete friend button
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteFriend(invitation, isSentByMe, friendName),
                        tooltip: 'Remove friend',
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildIncomingCard(InvitationModel invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          invitation.fromName.isNotEmpty ? invitation.fromName : 'Unknown Player',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'wants to play with you',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF10B981)),
              onPressed: () => _acceptInvitation(invitation),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _declineInvitation(invitation.invitationId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationCard({
    required InvitationModel invitation,
    required bool isSentByMe,
    bool isHighlighted = false,
  }) {
    // For sent by me: show toName (the person I invited)
    // For received/accepted: show fromName (the person who invited me)
    final displayName = isSentByMe
        ? (invitation.toName.isNotEmpty ? invitation.toName : 'Unknown Player')
        : (invitation.fromName.isNotEmpty ? invitation.fromName : 'Unknown Player');

    final statusText = isSentByMe
        ? _getStatusText(invitation.status)
        : 'You Accepted';

    final statusColor = isSentByMe
        ? _getStatusColor(invitation.status)
        : Colors.green;

    final icon = isSentByMe
        ? (invitation.status == 'accepted'
            ? Icons.check_circle
            : invitation.status == 'pending'
                ? Icons.schedule
                : Icons.cancel)
        : Icons.check_circle;

    // Highlighted card has brighter background and border
    final cardColor = isHighlighted
        ? Colors.green.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.08);
    final borderColor = isHighlighted
        ? Colors.green.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.green.withValues(alpha: 0.3)
                : statusColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isHighlighted ? Colors.green : statusColor,
          ),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: isHighlighted ? Colors.green : Colors.white,
            fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.bold,
            fontSize: isHighlighted ? 17 : 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Colors.green.withValues(alpha: 0.3)
                    : statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: isHighlighted ? Colors.green : statusColor,
                  fontSize: isHighlighted ? 13 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.white54,
          ),
          onPressed: () async {
            await _gameService.deleteInvitation(invitation.invitationId);
          },
        ),
      ),
    );
  }
}
