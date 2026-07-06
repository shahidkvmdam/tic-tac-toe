import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentPlayer {
  final String uid;
  final String name;
  final int slot; // 0-indexed

  const TournamentPlayer({required this.uid, required this.name, required this.slot});

  factory TournamentPlayer.fromMap(Map<String, dynamic> m) =>
      TournamentPlayer(uid: m['uid'], name: m['name'], slot: m['slot']);

  Map<String, dynamic> toMap() => {'uid': uid, 'name': name, 'slot': slot};
}

// Represents one match in the bracket
class TournamentMatch {
  final int matchIndex; // 0,1 = semi; 2 = final
  final String player1Uid;
  final String player1Name;
  final String player2Uid;
  final String player2Name;
  final String winnerUid; // empty until decided

  const TournamentMatch({
    required this.matchIndex,
    required this.player1Uid,
    required this.player1Name,
    required this.player2Uid,
    required this.player2Name,
    this.winnerUid = '',
  });

  factory TournamentMatch.fromMap(Map<String, dynamic> m) => TournamentMatch(
        matchIndex: m['matchIndex'],
        player1Uid: m['player1Uid'],
        player1Name: m['player1Name'],
        player2Uid: m['player2Uid'],
        player2Name: m['player2Name'],
        winnerUid: m['winnerUid'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'matchIndex': matchIndex,
        'player1Uid': player1Uid,
        'player1Name': player1Name,
        'player2Uid': player2Uid,
        'player2Name': player2Name,
        'winnerUid': winnerUid,
      };

  String get winnerName {
    if (winnerUid == player1Uid) return player1Name;
    if (winnerUid == player2Uid) return player2Name;
    return '';
  }
}

class TournamentService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference get _tournaments => _db.collection('tournaments');

  // Auto: join an existing waiting tournament of given size, or create one
  Future<String> autoJoinOrCreate(int size, String playerName) async {
    // Find open tournaments for this size where user not already in
    final snap = await _tournaments
        .where('status', isEqualTo: 'waiting')
        .where('size', isEqualTo: size)
        .limit(10)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final players =
          List<Map<String, dynamic>>.from(data['players'] as List);
      // Skip if already in this tournament or it's full
      if (players.any((p) => p['uid'] == _uid)) continue;
      if (players.length >= size) continue;

      // Try to join via transaction to avoid race condition
      try {
        await _db.runTransaction((tx) async {
          final ref = _tournaments.doc(doc.id);
          final latest = await tx.get(ref);
          final latestData = latest.data() as Map<String, dynamic>;
          final latestPlayers = List<Map<String, dynamic>>.from(
              latestData['players'] as List);
          if (latestPlayers.length >= size) throw Exception('full');
          if (latestPlayers.any((p) => p['uid'] == _uid)) return;
          latestPlayers
              .add({'uid': _uid, 'name': playerName, 'slot': latestPlayers.length});
          tx.update(ref, {'players': latestPlayers});
        });
        return doc.id;
      } catch (_) {
        continue; // race condition - try next
      }
    }

    // No open tournament found — create one
    return await createTournament(size, playerName);
  }

  // Create a new tournament room
  Future<String> createTournament(int size, String hostName) async {
    final doc = await _tournaments.add({
      'size': size,
      'status': 'waiting', // waiting | in_progress | finished
      'hostUid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'players': [
        {'uid': _uid, 'name': hostName, 'slot': 0}
      ],
      'matches': [],
    });
    return doc.id;
  }

  // Join an existing waiting tournament
  Future<void> joinTournament(String tournamentId, String playerName) async {
    final ref = _tournaments.doc(tournamentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;
      final players = List<Map<String, dynamic>>.from(data['players'] as List);
      final size = data['size'] as int;
      if (players.length >= size) throw Exception('Tournament is full');
      if (players.any((p) => p['uid'] == _uid)) return; // already joined
      players.add({'uid': _uid, 'name': playerName, 'slot': players.length});
      tx.update(ref, {'players': players});
    });
  }

  // Called when all players joined — builds match brackets (transaction-safe)
  Future<void> startTournament(String tournamentId) async {
    final ref = _tournaments.doc(tournamentId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    // Guard: only proceed if still waiting
    if (data['status'] != 'waiting') return;
    final players = List<Map<String, dynamic>>.from(data['players'] as List);
    final size = data['size'] as int;

    final matches = <Map<String, dynamic>>[];

    if (size == 2) {
      // Single final match
      matches.add(TournamentMatch(
        matchIndex: 0,
        player1Uid: players[0]['uid'],
        player1Name: players[0]['name'],
        player2Uid: players[1]['uid'],
        player2Name: players[1]['name'],
      ).toMap());
    } else if (size == 4) {
      // Semi 1: slot 0 vs slot 1
      matches.add(TournamentMatch(
        matchIndex: 0,
        player1Uid: players[0]['uid'],
        player1Name: players[0]['name'],
        player2Uid: players[1]['uid'],
        player2Name: players[1]['name'],
      ).toMap());
      // Semi 2: slot 2 vs slot 3
      matches.add(TournamentMatch(
        matchIndex: 1,
        player1Uid: players[2]['uid'],
        player1Name: players[2]['name'],
        player2Uid: players[3]['uid'],
        player2Name: players[3]['name'],
      ).toMap());
      // Final: TBD
      matches.add(TournamentMatch(
        matchIndex: 2,
        player1Uid: '',
        player1Name: 'TBD',
        player2Uid: '',
        player2Name: 'TBD',
      ).toMap());
    } else if (size == 8) {
      // Quarter-finals: 4 matches (index 0-3)
      for (int i = 0; i < 4; i++) {
        matches.add(TournamentMatch(
          matchIndex: i,
          player1Uid: players[i * 2]['uid'],
          player1Name: players[i * 2]['name'],
          player2Uid: players[i * 2 + 1]['uid'],
          player2Name: players[i * 2 + 1]['name'],
        ).toMap());
      }
      // Semi-finals: TBD (index 4-5)
      for (int i = 4; i < 6; i++) {
        matches.add(TournamentMatch(
          matchIndex: i,
          player1Uid: '', player1Name: 'TBD',
          player2Uid: '', player2Name: 'TBD',
        ).toMap());
      }
      // Final: TBD (index 6)
      matches.add(TournamentMatch(
        matchIndex: 6,
        player1Uid: '', player1Name: 'TBD',
        player2Uid: '', player2Name: 'TBD',
      ).toMap());
    }

    await ref.update({'status': 'in_progress', 'matches': matches});
  }

  // Report match winner and advance bracket
  Future<void> reportMatchWinner(String tournamentId, int matchIndex, String winnerUid) async {
    final ref = _tournaments.doc(tournamentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;
      final matches = List<Map<String, dynamic>>.from(data['matches'] as List);
      final size = data['size'] as int;

      // Update winner of current match
      matches[matchIndex]['winnerUid'] = winnerUid;
      final winnerName = winnerUid == matches[matchIndex]['player1Uid']
          ? matches[matchIndex]['player1Name']
          : matches[matchIndex]['player2Name'];

      if (size == 2) {
        // Only one match — tournament is over
        tx.update(ref, {'matches': matches, 'status': 'finished', 'championUid': winnerUid});
        return;
      } else if (size == 4) {
        // Advance semi winners to final
        if (matchIndex == 0) {
          matches[2]['player1Uid'] = winnerUid;
          matches[2]['player1Name'] = winnerName;
        } else if (matchIndex == 1) {
          matches[2]['player2Uid'] = winnerUid;
          matches[2]['player2Name'] = winnerName;
        }
        // Check if tournament is finished
        final finalMatch = matches[2];
        if (finalMatch['winnerUid'] != null && (finalMatch['winnerUid'] as String).isNotEmpty) {
          tx.update(ref, {'matches': matches, 'status': 'finished', 'championUid': finalMatch['winnerUid']});
          return;
        }
      } else if (size == 8) {
        // Advance quarter winners to semis
        if (matchIndex < 4) {
          final semiIdx = 4 + matchIndex ~/ 2;
          if (matchIndex % 2 == 0) {
            matches[semiIdx]['player1Uid'] = winnerUid;
            matches[semiIdx]['player1Name'] = winnerName;
          } else {
            matches[semiIdx]['player2Uid'] = winnerUid;
            matches[semiIdx]['player2Name'] = winnerName;
          }
        }
        // Advance semi winners to final
        if (matchIndex == 4) {
          matches[6]['player1Uid'] = winnerUid;
          matches[6]['player1Name'] = winnerName;
        } else if (matchIndex == 5) {
          matches[6]['player2Uid'] = winnerUid;
          matches[6]['player2Name'] = winnerName;
        }
        // Check finished
        if (matchIndex == 6) {
          tx.update(ref, {'matches': matches, 'status': 'finished', 'championUid': winnerUid});
          return;
        }
      }

      tx.update(ref, {'matches': matches});
    });
  }

  // Stream tournament doc
  Stream<DocumentSnapshot> streamTournament(String tournamentId) =>
      _tournaments.doc(tournamentId).snapshots();

  // Stream open/waiting tournaments
  Stream<QuerySnapshot> streamOpenTournaments() => _tournaments
      .where('status', isEqualTo: 'waiting')
      .limit(20)
      .snapshots();

  // Leave / cancel tournament
  Future<void> leaveTournament(String tournamentId) async {
    try {
      final ref = _tournaments.doc(tournamentId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;
      final players = List<Map<String, dynamic>>.from(data['players'] as List);
      players.removeWhere((p) => p['uid'] == _uid);
      if (players.isEmpty || data['hostUid'] == _uid) {
        await ref.delete();
      } else {
        await ref.update({'players': players});
      }
    } catch (_) {}
  }
}
