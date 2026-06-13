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
    // Check playerO
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
