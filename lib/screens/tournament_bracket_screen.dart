import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/tournament_service.dart';
import '../utils/theme_utils.dart';
import '../widgets/user_avatar.dart';
import 'tournament_game_screen.dart';

class TournamentBracketScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentBracketScreen({super.key, required this.tournamentId});

  @override
  State<TournamentBracketScreen> createState() =>
      _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  final _service = TournamentService();
  bool _navigatedToGame = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Find what match the current user should be playing right now
  TournamentMatch? _getMyCurrentMatch(List<TournamentMatch> matches) {
    for (final m in matches) {
      // Match has both players assigned, not yet finished
      if (m.player1Uid.isEmpty || m.player2Uid.isEmpty) continue;
      if (m.winnerUid.isNotEmpty) continue;
      if (m.player1Uid == _uid || m.player2Uid == _uid) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: appBackground(context),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _service.streamTournament(widget.tournamentId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF6D28D9)));
              }

              final data = snap.data!.data() as Map<String, dynamic>?;
              if (data == null) {
                return const Center(
                    child: Text('Tournament ended.',
                        style: TextStyle(color: Colors.white)));
              }

              final status = data['status'] as String;
              final size = data['size'] as int;
              final matchMaps = List<Map<String, dynamic>>.from(
                  data['matches'] as List);
              final matches =
                  matchMaps.map(TournamentMatch.fromMap).toList();
              final championUid = data['championUid'] as String? ?? '';

              final myMatch = _getMyCurrentMatch(matches);

              // Auto-navigate to game when my match is ready
              if (myMatch != null && !_navigatedToGame) {
                _navigatedToGame = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TournamentGameScreen(
                      tournamentId: widget.tournamentId,
                      match: myMatch,
                      myUid: _uid,
                      tournamentSize: size,
                    ),
                  )).then((_) {
                    if (mounted) setState(() => _navigatedToGame = false);
                  });
                });
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            'Bracket',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (status == 'finished' && championUid.isNotEmpty)
                            _ChampionBanner(
                              matches: matches,
                              championUid: championUid,
                              myUid: _uid,
                            ),

                          if (status != 'finished' && myMatch != null)
                            _MyMatchBanner(match: myMatch, myUid: _uid),

                          if (status != 'finished' && myMatch == null)
                            _WaitingBanner(matches: matches, myUid: _uid),

                          const SizedBox(height: 24),

                          if (size == 2)
                            _Bracket2(matches: matches, myUid: _uid)
                          else if (size == 4)
                            _Bracket4(matches: matches, myUid: _uid)
                          else
                            _Bracket8(matches: matches, myUid: _uid),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Champion banner ──────────────────────────────────────────────────────────
class _ChampionBanner extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String championUid;
  final String myUid;

  const _ChampionBanner(
      {required this.matches,
      required this.championUid,
      required this.myUid});

  @override
  Widget build(BuildContext context) {
    final finalMatch = matches.last;
    final champName = finalMatch.winnerName;
    final isMe = championUid == myUid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.3),
            const Color(0xFFF59E0B).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
            width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 48),
          const SizedBox(height: 8),
          Text(
            isMe ? 'You are the Champion! 🏆' : '$champName is the Champion! 🏆',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── My match banner ──────────────────────────────────────────────────────────
class _MyMatchBanner extends StatelessWidget {
  final TournamentMatch match;
  final String myUid;

  const _MyMatchBanner({required this.match, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isPlayer1 = match.player1Uid == myUid;
    final opponentName = isPlayer1 ? match.player2Name : match.player1Name;
    final opponentUid = isPlayer1 ? match.player2Uid : match.player1Uid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          UserAvatar(
            uid: opponentUid,
            name: opponentName,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your match is ready!',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('vs $opponentName',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: Color(0xFFA78BFA), size: 16),
        ],
      ),
    );
  }
}

// ── Waiting banner ───────────────────────────────────────────────────────────
class _WaitingBanner extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String myUid;

  const _WaitingBanner({required this.matches, required this.myUid});

  @override
  Widget build(BuildContext context) {
    // Check if player has already been eliminated
    final playedMatches = matches.where((m) =>
        m.winnerUid.isNotEmpty &&
        (m.player1Uid == myUid || m.player2Uid == myUid));
    final eliminated = playedMatches.any((m) => m.winnerUid != myUid);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!eliminated) ...[
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF6D28D9))),
            const SizedBox(width: 12),
            Text(
              'Waiting for other matches...',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ] else ...[
            const Icon(Icons.sentiment_dissatisfied,
                color: Colors.white38, size: 20),
            const SizedBox(width: 10),
            Text(
              'You\'ve been eliminated. Watch the bracket!',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 2-Player bracket ─────────────────────────────────────────────────────────
class _Bracket2 extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String myUid;

  const _Bracket2({required this.matches, required this.myUid});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RoundLabel('Final'),
        const SizedBox(height: 10),
        _MatchCard(match: matches[0], myUid: myUid, isFinal: true),
      ],
    );
  }
}

// ── 4-Player bracket ─────────────────────────────────────────────────────────
class _Bracket4 extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String myUid;

  const _Bracket4({required this.matches, required this.myUid});

  @override
  Widget build(BuildContext context) {
    if (matches.length < 3) return const SizedBox.shrink();
    final semi1 = matches[0];
    final semi2 = matches[1];
    final final_ = matches[2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RoundLabel('Semi-Finals'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MatchCard(match: semi1, myUid: myUid)),
            const SizedBox(width: 10),
            Expanded(child: _MatchCard(match: semi2, myUid: myUid)),
          ],
        ),
        const SizedBox(height: 20),
        const _RoundLabel('Final'),
        const SizedBox(height: 10),
        _MatchCard(match: final_, myUid: myUid, isFinal: true),
      ],
    );
  }
}

// ── 8-Player bracket ─────────────────────────────────────────────────────────
class _Bracket8 extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String myUid;

  const _Bracket8({required this.matches, required this.myUid});

  @override
  Widget build(BuildContext context) {
    if (matches.length < 7) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RoundLabel('Quarter-Finals'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MatchCard(match: matches[0], myUid: myUid)),
            const SizedBox(width: 8),
            Expanded(child: _MatchCard(match: matches[1], myUid: myUid)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MatchCard(match: matches[2], myUid: myUid)),
            const SizedBox(width: 8),
            Expanded(child: _MatchCard(match: matches[3], myUid: myUid)),
          ],
        ),
        const SizedBox(height: 20),
        const _RoundLabel('Semi-Finals'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MatchCard(match: matches[4], myUid: myUid)),
            const SizedBox(width: 10),
            Expanded(child: _MatchCard(match: matches[5], myUid: myUid)),
          ],
        ),
        const SizedBox(height: 20),
        const _RoundLabel('Final'),
        const SizedBox(height: 10),
        _MatchCard(match: matches[6], myUid: myUid, isFinal: true),
      ],
    );
  }
}

// ── Round label ──────────────────────────────────────────────────────────────
class _RoundLabel extends StatelessWidget {
  final String label;
  const _RoundLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1),
    );
  }
}

// ── Match card ───────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final String myUid;
  final bool isFinal;

  const _MatchCard(
      {required this.match, required this.myUid, this.isFinal = false});

  @override
  Widget build(BuildContext context) {
    final isMyMatch = match.player1Uid == myUid || match.player2Uid == myUid;
    final isDone = match.winnerUid.isNotEmpty;
    final isPending = match.player1Uid.isEmpty || match.player2Uid.isEmpty;

    Color borderColor = Colors.white.withValues(alpha: 0.1);
    if (isMyMatch && !isDone && !isPending) {
      borderColor = const Color(0xFF6D28D9).withValues(alpha: 0.7);
    } else if (isFinal) {
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFinal
            ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          _PlayerRow(
            name: match.player1Name.isEmpty ? 'TBD' : match.player1Name,
            uid: match.player1Uid.isEmpty ? null : match.player1Uid,
            isWinner: isDone && match.winnerUid == match.player1Uid,
            isMe: match.player1Uid == myUid,
            isPending: match.player1Uid.isEmpty,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('vs',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          _PlayerRow(
            name: match.player2Name.isEmpty ? 'TBD' : match.player2Name,
            uid: match.player2Uid.isEmpty ? null : match.player2Uid,
            isWinner: isDone && match.winnerUid == match.player2Uid,
            isMe: match.player2Uid == myUid,
            isPending: match.player2Uid.isEmpty,
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final String? uid;
  final bool isWinner;
  final bool isMe;
  final bool isPending;

  const _PlayerRow({
    required this.name,
    this.uid,
    required this.isWinner,
    required this.isMe,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!isPending && uid != null && uid!.isNotEmpty)
          UserAvatar(
            uid: uid!,
            name: name,
            size: 24,
            iconSize: 12,
          )
        else
          const Icon(Icons.person, color: Colors.white24, size: 24),
        const SizedBox(width: 6),
        if (isWinner)
          const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 14)
        else
          const SizedBox(width: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isPending
                  ? Colors.white30
                  : (isWinner
                      ? const Color(0xFFF59E0B)
                      : (isMe ? const Color(0xFFA78BFA) : Colors.white70)),
              fontWeight:
                  (isWinner || isMe) ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
