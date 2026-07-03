import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class InvitationModel {
  final String invitationId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;
  final String? gameId; // Set when invitation is accepted

  const InvitationModel({
    required this.invitationId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    required this.createdAt,
    this.gameId,
  });

  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvitationModel(
      invitationId: doc.id,
      fromUid: data['fromUid'] ?? '',
      fromName: data['fromName'] ?? '',
      toUid: data['toUid'] ?? '',
      toName: data['toName'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gameId: data['gameId'] as String?,
    );
  }
}

class GameModel {
  final String gameId;
  final List<String> board;
  final String currentPlayer;
  final Map<String, dynamic> playerX;
  final Map<String, dynamic> playerO;
  final String status; // 'waiting' | 'playing' | 'finished'
  final String winner;
  final bool isDraw;
  final int xScore;
  final int oScore;
  final String rematchRequest; // '' | 'X' | 'O' — who requested rematch
  final List<String> spectators; // list of uids watching
  final DateTime createdAt;
  final String gameType; // 'quickmatch' | 'room'

  const GameModel({
    required this.gameId,
    required this.board,
    required this.currentPlayer,
    required this.playerX,
    required this.playerO,
    required this.status,
    required this.winner,
    required this.isDraw,
    required this.xScore,
    required this.oScore,
    required this.rematchRequest,
    required this.spectators,
    required this.createdAt,
    this.gameType = 'room',
  });

  factory GameModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameModel(
      gameId: doc.id,
      board: List<String>.from(data['board'] ?? List.filled(9, '')),
      currentPlayer: data['currentPlayer'] ?? 'X',
      playerX: Map<String, dynamic>.from(data['playerX'] ?? {}),
      playerO: Map<String, dynamic>.from(data['playerO'] ?? {}),
      status: data['status'] ?? 'waiting',
      winner: data['winner'] ?? '',
      isDraw: data['isDraw'] ?? false,
      xScore: data['xScore'] ?? 0,
      oScore: data['oScore'] ?? 0,
      rematchRequest: data['rematchRequest'] ?? '',
      spectators: List<String>.from(data['spectators'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gameType: data['gameType'] as String? ?? 'room',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'board': board,
      'currentPlayer': currentPlayer,
      'playerX': playerX,
      'playerO': playerO,
      'status': status,
      'winner': winner,
      'isDraw': isDraw,
      'xScore': xScore,
      'oScore': oScore,
      'rematchRequest': rematchRequest,
      'spectators': spectators,
      'createdAt': FieldValue.serverTimestamp(),
      'gameType': gameType,
    };
  }

  String get mySymbol {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (playerX['uid'] == uid) return 'X';
    if (playerO['uid'] == uid) return 'O';
    return '';
  }

  bool get isMyTurn => currentPlayer == mySymbol;
  bool get isSpectator {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return playerX['uid'] != uid && playerO['uid'] != uid;
  }

  String get opponentName {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (playerX['uid'] == uid) {
      return playerO['displayName'] ?? 'Opponent';
    }
    return playerX['displayName'] ?? 'Opponent';
  }
}

// Model for play requests between friends
class GameRequestModel {
  final String requestId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;
  final String? gameId; // Set when request is accepted

  const GameRequestModel({
    required this.requestId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    required this.createdAt,
    this.gameId,
  });

  factory GameRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameRequestModel(
      requestId: doc.id,
      fromUid: data['fromUid'] ?? '',
      fromName: data['fromName'] ?? '',
      toUid: data['toUid'] ?? '',
      toName: data['toName'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gameId: data['gameId'] as String?,
    );
  }
}

// Model for chat messages
class ChatMessageModel {
  final String messageId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessageModel({
    required this.messageId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      messageId: doc.id,
      fromUid: data['fromUid'] ?? '',
      fromName: data['fromName'] ?? '',
      toUid: data['toUid'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}

class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _games => _db.collection('games');
  CollectionReference get _queue => _db.collection('matchmaking');
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _invitations => _db.collection('invitations');
  CollectionReference get _gameRequests => _db.collection('gameRequests');
  CollectionReference get _messages => _db.collection('messages');

  Future<void> _recordWin(String uid, String displayName) async {
    await _users.doc(uid).set({
      'displayName': displayName,
      'wins': FieldValue.increment(1),
      'uid': uid,
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> leaderboardStream() {
    return _users
        .orderBy('wins', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList());
  }

  // Quick match — find or create a matchmaking slot
  // Returns gameId when matched, or throws on cancel/timeout.
  Future<String> joinMatchmaking() async {
    final uid = _currentUid;
    final displayName = _currentDisplayName;

    // 1. Look for an open slot from someone else
    final waiting = await _queue
        .where('status', isEqualTo: 'waiting')
        .where('uid', isNotEqualTo: uid)
        .limit(1)
        .get();

    if (waiting.docs.isNotEmpty) {
      // Pair with the waiting player using a transaction to avoid race conditions
      final slot = waiting.docs.first;
      final roomCode = _generateRoomCode();

      try {
        await _db.runTransaction((tx) async {
          final freshSlot = await tx.get(slot.reference);
          if (!freshSlot.exists) throw Exception('slot_gone');
          final slotData = freshSlot.data() as Map<String, dynamic>;
          if (slotData['status'] != 'waiting') throw Exception('slot_taken');

          final opponentUid = slotData['uid'] as String;
          final opponentName = slotData['displayName'] as String? ?? 'Player';

          tx.set(_games.doc(roomCode), {
            'board': List.filled(9, ''),
            'currentPlayer': 'X',
            'playerX': {'uid': opponentUid, 'displayName': opponentName},
            'playerO': {'uid': uid, 'displayName': displayName},
            'status': 'playing',
            'winner': '',
            'isDraw': false,
            'xScore': 0,
            'oScore': 0,
            'rematchRequest': '',
            'spectators': [],
            'createdAt': FieldValue.serverTimestamp(),
            'gameType': 'quickmatch',
          });

          tx.update(slot.reference, {'status': 'matched', 'gameId': roomCode});
        });
        return roomCode;
      } catch (e) {
        if (e.toString().contains('slot_gone') || e.toString().contains('slot_taken')) {
          // Slot was taken by someone else — fall through to create our own slot
        } else {
          rethrow;
        }
      }
    }

    // 2. No one waiting — create our own slot and wait
    final mySlot = await _queue.add({
      'uid': uid,
      'displayName': displayName,
      'status': 'waiting',
      'gameId': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Poll every second for up to 60 seconds
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final snap = await mySlot.get();
      if (!snap.exists) throw Exception('cancelled');
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] == 'matched' && (data['gameId'] as String).isNotEmpty) {
        return data['gameId'] as String;
      }
    }

    // Timeout — clean up
    await mySlot.delete();
    throw Exception('timeout');
  }

  // Cancel matchmaking — deletes our waiting slot
  Future<void> cancelMatchmaking() async {
    final uid = _currentUid;
    final snap = await _queue.where('uid', isEqualTo: uid).where('status', isEqualTo: 'waiting').get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String get _currentUid => _auth.currentUser?.uid ?? '';
  String get currentUid => _auth.currentUser?.uid ?? '';
  String get _currentDisplayName =>
      _auth.currentUser?.displayName ??
      _auth.currentUser?.phoneNumber ??
      'Player';

  // Create a new game room, returns the gameId (room code)
  Future<String> createGame() async {
    final roomCode = _generateRoomCode();

    await _games.doc(roomCode).set({
      'board': List.filled(9, ''),
      'currentPlayer': 'X',
      'playerX': {
        'uid': _currentUid,
        'displayName': _currentDisplayName,
      },
      'playerO': {},
      'status': 'waiting',
      'winner': '',
      'isDraw': false,
      'xScore': 0,
      'oScore': 0,
      'rematchRequest': '',
      'spectators': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return roomCode;
  }

  // Join an existing game room as Player O
  Future<Map<String, dynamic>> joinGame(String roomCode) async {
    final code = roomCode.trim().toUpperCase();
    final doc = await _games.doc(code).get();

    if (!doc.exists) {
      return {'success': false, 'error': 'Room not found'};
    }

    final data = doc.data() as Map<String, dynamic>;

    if (data['status'] != 'waiting') {
      return {'success': false, 'error': 'Game already started or finished'};
    }

    if (data['playerX']['uid'] == _currentUid) {
      return {'success': false, 'error': 'You created this room'};
    }

    await _games.doc(code).update({
      'playerO': {
        'uid': _currentUid,
        'displayName': _currentDisplayName,
      },
      'status': 'playing',
    });

    return {'success': true, 'gameId': code};
  }

  // Get a game by ID (returns null if not found)
  Future<GameModel?> getGame(String gameId) async {
    try {
      final doc = await _games.doc(gameId).get();
      if (!doc.exists) return null;
      return GameModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting game: $e');
      return null;
    }
  }

  // Play a move
  Future<void> playMove(String gameId, int index, GameModel game) async {
    if (!game.isMyTurn) return;
    if (game.board[index].isNotEmpty) return;
    if (game.status != 'playing') return;

    final newBoard = List<String>.from(game.board);
    newBoard[index] = game.currentPlayer;

    final winner = _findWinner(newBoard);
    final isDraw = winner.isEmpty && !newBoard.contains('');
    final nextPlayer = game.currentPlayer == 'X' ? 'O' : 'X';

    final newXScore = game.xScore + (winner == 'X' ? 1 : 0);
    final newOScore = game.oScore + (winner == 'O' ? 1 : 0);

    await _games.doc(gameId).update({
      'board': newBoard,
      'currentPlayer': (winner.isNotEmpty || isDraw) ? game.currentPlayer : nextPlayer,
      'winner': winner,
      'isDraw': isDraw,
      'status': (winner.isNotEmpty || isDraw) ? 'finished' : 'playing',
      'xScore': newXScore,
      'oScore': newOScore,
    });
    if (winner.isNotEmpty && game.gameType == 'quickmatch') {
      final winnerUid = winner == 'X'
          ? (game.playerX['uid'] as String? ?? '')
          : (game.playerO['uid'] as String? ?? '');
      final winnerName = winner == 'X'
          ? (game.playerX['displayName'] as String? ?? 'Player')
          : (game.playerO['displayName'] as String? ?? 'Player');
      if (winnerUid.isNotEmpty) {
        try { await _recordWin(winnerUid, winnerName); } catch (_) {}
      }
    }
  }

  // Request a rematch
  Future<void> requestRematch(String gameId, String mySymbol) async {
    await _games.doc(gameId).update({'rematchRequest': mySymbol});
  }

  // Accept rematch — reset board, clear request
  Future<void> acceptRematch(String gameId) async {
    await _games.doc(gameId).update({
      'board': List.filled(9, ''),
      'currentPlayer': 'X',
      'winner': '',
      'isDraw': false,
      'status': 'playing',
      'rematchRequest': '',
    });
  }

  // Decline rematch — just clear the request field
  Future<void> declineRematch(String gameId) async {
    await _games.doc(gameId).update({'rematchRequest': ''});
  }

  // Reset the board for a rematch (keeps same players and scores)
  Future<void> resetGame(String gameId) async {
    await _games.doc(gameId).update({
      'board': List.filled(9, ''),
      'currentPlayer': 'X',
      'winner': '',
      'isDraw': false,
      'status': 'playing',
      'rematchRequest': '',
    });
  }

  // Join as spectator
  Future<Map<String, dynamic>> joinAsSpectator(String roomCode) async {
    final code = roomCode.trim().toUpperCase();
    final doc = await _games.doc(code).get();
    if (!doc.exists) return {'success': false, 'error': 'Room not found'};
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'waiting';
    if (status == 'waiting') {
      return {'success': false, 'error': 'Game has not started yet'};
    }
    final uid = _currentUid;
    // Already a player? Route to game instead
    if (data['playerX']['uid'] == uid || (data['playerO'] as Map).isNotEmpty && data['playerO']['uid'] == uid) {
      return {'success': true, 'gameId': code, 'isPlayer': true};
    }
    await _games.doc(code).update({
      'spectators': FieldValue.arrayUnion([uid]),
    });
    return {'success': true, 'gameId': code, 'isPlayer': false};
  }

  // Find an active game the current user is part of (for reconnect)
  Future<String?> findActiveGame() async {
    final uid = _currentUid;
    // Check playerX
    final xQuery = await _games
        .where('playerX.uid', isEqualTo: uid)
        .where('status', whereIn: ['waiting', 'playing'])
        .limit(1)
        .get();
    if (xQuery.docs.isNotEmpty) return xQuery.docs.first.id;
    final oQuery = await _games
        .where('playerO.uid', isEqualTo: uid)
        .where('status', whereIn: ['waiting', 'playing'])
        .limit(1)
        .get();
    if (oQuery.docs.isNotEmpty) return oQuery.docs.first.id;
    return null;
  }

  // Delete / leave a game room
  Future<void> deleteGame(String gameId) async {
    await _games.doc(gameId).delete();
  }

  // Mark game as abandoned so the other player sees a message instead of a crash
  Future<void> abandonGame(String gameId) async {
    await _games.doc(gameId).update({
      'status': 'abandoned',
      'winner': '',
      'isDraw': false,
    });
  }

  // Chat — send a message
  Future<void> sendMessage(String gameId, String text) async {
    if (text.trim().isEmpty) return;
    await _games.doc(gameId).collection('messages').add({
      'uid': _currentUid,
      'name': _currentDisplayName,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Chat — real-time stream of messages
  Stream<List<Map<String, dynamic>>> messagesStream(String gameId) {
    return _games
        .doc(gameId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // Search users by display name (case-insensitive)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final trimmedQuery = query.trim();
    // For case-insensitive search, use lowercase pattern
    final lowerQuery = trimmedQuery.toLowerCase();

    // Fetch all users (limited) and filter in memory for case-insensitive search
    final snapshot = await _users.limit(50).get();

    // Filter results case-insensitively
    final filtered = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final displayName = (data['displayName'] ?? '').toString().toLowerCase();
      return displayName.contains(lowerQuery);
    }).take(10);

    // Check existing invitations for each user
    final currentUid = _currentUid;
    final results = await Future.wait(filtered.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final uid = doc.id;

      // Check for existing invitation with this user
      String? invitationStatus;
      bool isSentByMe = false;

      // Check if I sent to them
      final sentQuery = await _invitations
          .where('fromUid', isEqualTo: currentUid)
          .where('toUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (sentQuery.docs.isNotEmpty) {
        invitationStatus = (sentQuery.docs.first.data() as Map<String, dynamic>)['status'];
        isSentByMe = true;
      } else {
        // Check if they sent to me
        final receivedQuery = await _invitations
            .where('fromUid', isEqualTo: uid)
            .where('toUid', isEqualTo: currentUid)
            .limit(1)
            .get();

        if (receivedQuery.docs.isNotEmpty) {
          invitationStatus = (receivedQuery.docs.first.data() as Map<String, dynamic>)['status'];
          isSentByMe = false;
        }
      }

      return {
        'uid': uid,
        'displayName': data['displayName'] ?? '',
        'avatar': data['avatar'] ?? '',
        'invitationStatus': invitationStatus, // 'pending', 'accepted', 'declined', or null
        'isSentByMe': isSentByMe, // true if I sent, false if they sent
      };
    }).toList());

    return results;
  }

  // Send game invitation
  Future<void> sendInvitation(String toUid, String toName) async {
    final fromUid = _currentUid;

    // Fetch displayName from Firestore to ensure it's up to date
    final userDoc = await _users.doc(fromUid).get();
    final fromName = userDoc.exists
        ? (userDoc.data() as Map<String, dynamic>)['displayName'] ?? _currentDisplayName
        : _currentDisplayName;

    await _invitations.add({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept invitation and create game
  Future<String> acceptInvitation(String invitationId, String fromUid) async {
    // Create game room
    final roomCode = _generateRoomCode();
    
    // Fetch sender's displayName from Firestore
    final senderDoc = await _users.doc(fromUid).get();
    final senderName = senderDoc.exists
        ? (senderDoc.data() as Map<String, dynamic>)['displayName'] ?? 'Player'
        : 'Player';
    
    await _games.doc(roomCode).set({
      'board': List.filled(9, ''),
      'currentPlayer': 'X',
      'playerX': {
        'uid': fromUid,
        'name': senderName,
        'avatar': '',
      },
      'playerO': {
        'uid': _currentUid,
        'name': _currentDisplayName,
        'avatar': '',
      },
      'status': 'playing',
      'winner': '',
      'isDraw': false,
      'xScore': 0,
      'oScore': 0,
      'rematchRequest': '',
      'spectators': [],
      'createdAt': FieldValue.serverTimestamp(),
      'gameType': 'room',
    });
    
    // Update invitation with accepted status and gameId
    await _invitations.doc(invitationId).update({
      'status': 'accepted',
      'gameId': roomCode,
    });
    
    return roomCode;
  }

  // Stream for accepted sent invitations (sender watches for acceptance)
  Stream<List<Map<String, dynamic>>> acceptedInvitationsStream() {
    return _invitations
        .where('fromUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'invitationId': doc.id,
                'gameId': data['gameId'] ?? '',
                'toUid': data['toUid'] ?? '',
              };
            }).toList());
  }

  // Decline invitation
  Future<void> declineInvitation(String invitationId) async {
    await _invitations.doc(invitationId).update({'status': 'declined'});
  }

  // Delete invitation (cleanup after accepted)
  Future<void> deleteInvitation(String invitationId) async {
    try {
      await _invitations.doc(invitationId).delete();
    } catch (e) {
      debugPrint('Failed to delete invitation: $e');
    }
  }

  // Stream for incoming invitations
  Stream<List<InvitationModel>> incomingInvitationsStream() {
    return _invitations
        .where('toUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => InvitationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream for sent invitations (pending only)
  Stream<List<InvitationModel>> sentInvitationsStream() {
    return _invitations
        .where('fromUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => InvitationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream for all sent invitations (pending, accepted, declined)
  Stream<List<InvitationModel>> allSentInvitationsStream() {
    return _invitations
        .where('fromUid', isEqualTo: _currentUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => InvitationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream for accepted received invitations (people you accepted)
  Stream<List<InvitationModel>> acceptedReceivedInvitationsStream() {
    return _invitations
        .where('toUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => InvitationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream for accepted sent invitations (your requests that were accepted)
  Stream<List<InvitationModel>> acceptedSentInvitationsStream() {
    return _invitations
        .where('fromUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => InvitationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Real-time stream of a game
  Stream<GameModel?> gameStream(String gameId) {
    return _games.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GameModel.fromFirestore(doc);
    });
  }

  String _findWinner(List<String> board) {
    const winningLines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (final line in winningLines) {
      final first = board[line[0]];
      if (first.isNotEmpty &&
          first == board[line[1]] &&
          first == board[line[2]]) {
        return first;
      }
    }
    return '';
  }

  // ============================================
  // GAME REQUEST METHODS (Play with friends)
  // ============================================

  // Send a play request to a friend
  Future<void> sendGameRequest(String toUid, String toName) async {
    final fromUid = _currentUid;
    final userDoc = await _users.doc(fromUid).get();
    final fromName = userDoc.exists
        ? (userDoc.data() as Map<String, dynamic>)['displayName'] ?? _currentDisplayName
        : _currentDisplayName;

    await _gameRequests.add({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept a game request and create a game
  Future<String> acceptGameRequest(String requestId, String opponentUid) async {
    final fromUid = _currentUid;
    final userDoc = await _users.doc(fromUid).get();
    final fromName = userDoc.exists
        ? (userDoc.data() as Map<String, dynamic>)['displayName'] ?? _currentDisplayName
        : _currentDisplayName;

    // Create the game
    final gameRef = _games.doc();
    await gameRef.set({
      'board': List.filled(9, ''),
      'currentPlayer': 'X',
      'playerX': {'uid': opponentUid, 'displayName': 'Opponent'},
      'playerO': {'uid': fromUid, 'displayName': fromName},
      'status': 'playing',
      'winner': '',
      'isDraw': false,
      'xScore': 0,
      'oScore': 0,
      'rematchRequest': '',
      'spectators': [],
      'createdAt': FieldValue.serverTimestamp(),
      'gameType': 'friend',
    });

    // Update the request
    await _gameRequests.doc(requestId).update({
      'status': 'accepted',
      'gameId': gameRef.id,
    });

    return gameRef.id;
  }

  // Decline a game request
  Future<void> declineGameRequest(String requestId) async {
    await _gameRequests.doc(requestId).update({'status': 'declined'});
  }

  // Stream of pending incoming game requests
  Stream<List<GameRequestModel>> incomingGameRequestsStream() {
    return _gameRequests
        .where('toUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => GameRequestModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream of pending outgoing game requests
  Stream<List<GameRequestModel>> outgoingGameRequestsStream() {
    return _gameRequests
        .where('fromUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => GameRequestModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream of accepted outgoing game requests (to notify sender when recipient accepts)
  Stream<List<GameRequestModel>> acceptedOutgoingGameRequestsStream() {
    return _gameRequests
        .where('fromUid', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => GameRequestModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ============================================
  // CHAT MESSAGE METHODS
  // ============================================

  // Send a message to a friend (chat)
  Future<void> sendChatMessage(String toUid, String toName, String message) async {
    final fromUid = _currentUid;
    final userDoc = await _users.doc(fromUid).get();
    final fromName = userDoc.exists
        ? (userDoc.data() as Map<String, dynamic>)['displayName'] ?? _currentDisplayName
        : _currentDisplayName;

    // Create a chat room ID (sorted UIDs to ensure consistency)
    final chatRoomId = fromUid.compareTo(toUid) < 0
        ? '${fromUid}_$toUid'
        : '${toUid}_$fromUid';

    await _messages.add({
      'chatRoomId': chatRoomId,
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Stream of chat messages with a specific user
  Stream<List<Map<String, dynamic>>> chatMessagesStream(String otherUid) {
    // Get messages between current user and other user using a simpler query
    final currentUid = _currentUid;

    // Create a chat room ID (sorted UIDs to ensure consistency)
    final chatRoomId = currentUid.compareTo(otherUid) < 0
        ? '${currentUid}_$otherUid'
        : '${otherUid}_$currentUid';

    debugPrint('Chat stream: querying for chatRoomId=$chatRoomId, currentUid=$currentUid, otherUid=$otherUid');

    return _messages
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) {
          debugPrint('Chat stream: received ${snap.docs.length} messages');
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('  Message from: ${data['fromUid']}, message: ${data['message']}');
          }
          return snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .cast<Map<String, dynamic>>()
              .toList();
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String fromUid) async {
    final currentUid = _currentUid;

    // Create chat room ID
    final chatRoomId = currentUid.compareTo(fromUid) < 0
        ? '${currentUid}_$fromUid'
        : '${fromUid}_$currentUid';

    final unreadMessages = await _messages
        .where('chatRoomId', isEqualTo: chatRoomId)
        .where('fromUid', isEqualTo: fromUid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Stream of unread message senders (for highlighting)
  Stream<List<String>> unreadMessageSendersStream() {
    return _messages
        .where('toUid', isEqualTo: _currentUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final senders = snap.docs
              .map((d) => (d.data() as Map<String, dynamic>)['fromUid'] as String)
              .toSet()
              .toList();
          return senders;
        });
  }
}
