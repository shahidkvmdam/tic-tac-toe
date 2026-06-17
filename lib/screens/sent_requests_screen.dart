import 'dart:async';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../utils/theme_utils.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _sentSubscription?.cancel();
    _acceptedReceivedSubscription?.cancel();
    _incomingSubscription?.cancel();

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
    final hasAnyInvitations = _sentInvitations.isNotEmpty ||
        _acceptedReceived.isNotEmpty ||
        _incomingInvitations.isNotEmpty;

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
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : !hasAnyInvitations
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_outlined,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No requests',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Send or accept invitations to play with friends',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Section: Incoming Requests (people sent to you)
                              if (_incomingInvitations.isNotEmpty) ...[
                                Text(
                                  'Incoming Requests',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._incomingInvitations.map((invitation) => _buildIncomingCard(invitation)),
                                const SizedBox(height: 24),
                              ],

                              // Section: Sent Requests (you sent to others)
                              if (_sentInvitations.isNotEmpty) ...[
                                Text(
                                  'Sent Requests',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._sentInvitations.map((invitation) => _buildInvitationCard(
                                  invitation: invitation,
                                  isSentByMe: true,
                                  isHighlighted: widget.highlightAcceptedIds.contains(invitation.invitationId) && invitation.status == 'accepted',
                                )),
                                const SizedBox(height: 24),
                              ],

                              // Section: Accepted Requests (you accepted from others)
                              if (_acceptedReceived.isNotEmpty) ...[
                                Text(
                                  'People You Accepted',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._acceptedReceived.map((invitation) => _buildInvitationCard(
                                  invitation: invitation,
                                  isSentByMe: false,
                                  isHighlighted: false,
                                )),
                              ],
                            ],
                          ),
              ),
            ],
          ),
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
