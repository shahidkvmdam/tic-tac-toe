import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _games => _db.collection('games');
  CollectionReference get _queue => _db.collection('matchmaking');
  CollectionReference get _users => _db.collection('users');

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
}
