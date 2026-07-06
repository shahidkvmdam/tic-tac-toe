import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sound_service.dart';
import '../services/tournament_service.dart';
import '../utils/theme_utils.dart';

class TournamentGameScreen extends StatefulWidget {
  final String tournamentId;
  final TournamentMatch match;
  final String myUid;
  final int tournamentSize;

  const TournamentGameScreen({
    super.key,
    required this.tournamentId,
    required this.match,
    required this.myUid,
    required this.tournamentSize,
  });

  @override
  State<TournamentGameScreen> createState() => _TournamentGameScreenState();
}

class _TournamentGameScreenState extends State<TournamentGameScreen>
    with TickerProviderStateMixin {
  final _service = TournamentService();
  final _db = FirebaseFirestore.instance;

  // I am X if I am player1, O if player2
  late final String _mySymbol;
  late final String _opponentSymbol;
  late final String _opponentName;

  // Board stored in Firestore sub-document
  late final DocumentReference _gameRef;
  StreamSubscription? _gameSub;

  List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X';
  String _winner = '';
  bool _isDraw = false;
  bool _reportedWinner = false;
  bool _navigatedBack = false;

  // Best of 3
  int _winsX = 0;
  int _winsO = 0;
  int _gameNumber = 1;
  bool _resettingBoard = false;
  // Effective wins including the current unsaved game result
  int _effectiveWinsX = 0;
  int _effectiveWinsO = 0;

  late ConfettiController _confettiController;
  late AnimationController _shakeController;
  late AnimationController _flashController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    final isPlayer1 = widget.match.player1Uid == widget.myUid;
    _mySymbol = isPlayer1 ? 'X' : 'O';
    _opponentSymbol = isPlayer1 ? 'O' : 'X';
    _opponentName = isPlayer1
        ? widget.match.player2Name
        : widget.match.player1Name;

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _flashAnimation = Tween<double>(begin: 0.0, end: 0.35).animate(
        CurvedAnimation(parent: _flashController, curve: Curves.easeInOut));

    // Each match has its own game document inside the tournament
    _gameRef = _db
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('games')
        .doc('match_${widget.match.matchIndex}');

    _initGame();
    _listenGame();
  }

  Future<void> _initGame() async {
    // Player1 (X) initializes the board
    if (_mySymbol == 'X') {
      await _gameRef.set({
        'board': List.filled(9, ''),
        'currentPlayer': 'X',
        'winner': '',
        'isDraw': false,
        'winsX': 0,
        'winsO': 0,
        'gameNumber': 1,
      }, SetOptions(merge: true));
    }
  }

  void _listenGame() {
    _gameSub = _gameRef.snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data() as Map<String, dynamic>;
      setState(() {
        _board = List<String>.from(data['board'] as List);
        _currentPlayer = data['currentPlayer'] as String;
        _winner = data['winner'] as String? ?? '';
        _isDraw = data['isDraw'] as bool? ?? false;
        _winsX = data['winsX'] as int? ?? 0;
        _winsO = data['winsO'] as int? ?? 0;
        _gameNumber = data['gameNumber'] as int? ?? 1;
        // Effective wins = stored wins + this game's result (not yet saved to Firestore)
        _effectiveWinsX = _winsX + (_winner == 'X' ? 1 : 0);
        _effectiveWinsO = _winsO + (_winner == 'O' ? 1 : 0);
      });

      if (_winner.isNotEmpty || _isDraw) {
        _handleGameEnd();
      }
    });
  }

  void _handleGameEnd() {
    if (_resettingBoard) return;

    final newWinsX = _winsX + (_winner == 'X' ? 1 : 0);
    final newWinsO = _winsO + (_winner == 'O' ? 1 : 0);
    final matchWinner = newWinsX >= 2 ? 'X' : (newWinsO >= 2 ? 'O' : '');
    final iWonThisGame = _winner == _mySymbol;
    final iLostThisGame = _winner == _opponentSymbol;

    if (iWonThisGame) {
      if (matchWinner == _mySymbol) {
        _confettiController.play();
      }
      SoundService.instance.playWin();
      HapticFeedback.vibrate();
    } else if (iLostThisGame) {
      _shakeController.forward(from: 0);
      _flashController.forward(from: 0).then((_) => _flashController.reverse());
      HapticFeedback.heavyImpact();
      SoundService.instance.playLose();
    } else {
      SoundService.instance.playDraw();
    }

    // Only player1 (X) drives state transitions
    if (_mySymbol != 'X') return;
    if (_reportedWinner) return;

    if (matchWinner.isNotEmpty) {
      // Match decided
      _reportedWinner = true;
      final winnerUid = matchWinner == 'X'
          ? widget.match.player1Uid
          : widget.match.player2Uid;
      _service.reportMatchWinner(
          widget.tournamentId, widget.match.matchIndex, winnerUid);
    } else {
      // Next game — reset board after short delay
      // On draw: keep same gameNumber and scores (replay)
      // On win: increment gameNumber and update scores
      final isDraw = _isDraw;
      final savedWinsX = newWinsX;
      final savedWinsO = newWinsO;
      final savedGameNumber = _gameNumber;
      _resettingBoard = true;
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        // Guard: only reset if still showing a finished game (not already reset)
        final snap = await _gameRef.get();
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        final currentWinner = d['winner'] as String? ?? '';
        final currentDraw = d['isDraw'] as bool? ?? false;
        if (currentWinner.isEmpty && !currentDraw) {
          // Already reset by another client
          if (mounted) setState(() => _resettingBoard = false);
          return;
        }
        await _gameRef.update({
          'board': List.filled(9, ''),
          'currentPlayer': 'X',
          'winner': '',
          'isDraw': false,
          'winsX': isDraw ? (d['winsX'] as int? ?? 0) : savedWinsX,
          'winsO': isDraw ? (d['winsO'] as int? ?? 0) : savedWinsO,
          'gameNumber': isDraw ? (d['gameNumber'] as int? ?? 1) : savedGameNumber + 1,
        });
        if (mounted) setState(() => _resettingBoard = false);
      });
    }
  }

  Future<void> _playMove(int index) async {
    if (_board[index].isNotEmpty || _winner.isNotEmpty || _isDraw) return;
    if (_currentPlayer != _mySymbol) return;
    if (_resettingBoard) return;

    HapticFeedback.lightImpact();
    SoundService.instance.playTap();

    final newBoard = List<String>.from(_board);
    newBoard[index] = _mySymbol;
    final winner = _findWinner(newBoard);
    final isDraw = winner.isEmpty && !newBoard.contains('');

    await _gameRef.update({
      'board': newBoard,
      'currentPlayer': _opponentSymbol,
      'winner': winner,
      'isDraw': isDraw,
    });
  }

  String _findWinner(List<String> board) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final f = board[line[0]];
      if (f.isNotEmpty && f == board[line[1]] && f == board[line[2]]) {
        return f;
      }
    }
    return '';
  }

  bool _isWinningCell(int index) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final f = _board[line[0]];
      if (f.isNotEmpty &&
          f == _board[line[1]] &&
          f == _board[line[2]] &&
          line.contains(index)) return true;
    }
    return false;
  }

  bool get _isFinalMatch => _roundLabel == 'Final';
  int get _myWins => _mySymbol == 'X' ? _effectiveWinsX : _effectiveWinsO;
  int get _oppWins => _mySymbol == 'X' ? _effectiveWinsO : _effectiveWinsX;
  bool get _matchOver => _myWins >= 2 || _oppWins >= 2;

  String get _statusText {
    if (_matchOver) {
      if (_myWins >= 2) {
        return _isFinalMatch ? 'You are the Champion! 🏆' : 'You win the match! 🎉 Moving to next round...';
      } else {
        return _isFinalMatch ? '$_opponentName is the Champion! 🏆' : '$_opponentName wins the match.';
      }
    }
    if (_winner == _mySymbol) return 'You won game $_gameNumber! Next game starting...';
    if (_winner == _opponentSymbol) return '$_opponentName won game $_gameNumber. Next game starting...';
    if (_isDraw) return 'Draw! Replaying game $_gameNumber...';
    if (_currentPlayer == _mySymbol) return 'Your turn';
    return "$_opponentName's turn...";
  }

  Color get _statusColor {
    if (_matchOver && _myWins >= 2) return const Color(0xFF4ADE80);
    if (_matchOver && _oppWins >= 2) return const Color(0xFFF87171);
    if (_winner == _mySymbol) return const Color(0xFF4ADE80);
    if (_winner == _opponentSymbol) return const Color(0xFFF87171);
    if (_isDraw) return const Color(0xFFFBBF24);
    return Colors.white;
  }

  bool get _gameOver => _winner.isNotEmpty || _isDraw;
  bool get _currentGameOver => _gameOver && !_resettingBoard;

  @override
  void dispose() {
    _gameSub?.cancel();
    _confettiController.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (ctx, child) {
              final offset = sin(_shakeAnimation.value * pi * 8) * 12;
              return Transform.translate(
                  offset: Offset(offset, 0), child: child);
            },
            child: Container(
              width: double.infinity,
              decoration: appBackground(context),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Top bar
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      _roundLabel,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                    Text(
                                      'You ($_mySymbol) vs $_opponentName ($_opponentSymbol)',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Score + game number
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ScorePip(wins: _myWins, label: 'You'),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Game $_gameNumber of 3',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              _ScorePip(wins: _oppWins, label: _opponentName),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Status
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _statusText,
                              key: ValueKey(_statusText),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Board
                          AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: 9,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemBuilder: (ctx, index) {
                                final winning = _winner.isNotEmpty &&
                                    _isWinningCell(index);
                                return _BoardCell(
                                  value: _board[index],
                                  isWinning: winning,
                                  onTap: (!_gameOver &&
                                          _currentPlayer == _mySymbol)
                                      ? () => _playMove(index)
                                      : null,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (_matchOver) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: () {
                                  if (!_navigatedBack) {
                                    _navigatedBack = true;
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back to Bracket',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Red flash on loss
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (ctx, child) => IgnorePointer(
              child: Container(
                  color:
                      Colors.red.withValues(alpha: _flashAnimation.value)),
            ),
          ),

          // Confetti on win
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
              colors: const [
                Color(0xFF38BDF8), Color(0xFFF472B6),
                Color(0xFF4ADE80), Color(0xFFFBBF24), Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _roundLabel {
    final idx = widget.match.matchIndex;
    final size = widget.tournamentSize;
    // 2-player: only match 0 = Final
    if (size == 2) return 'Final';
    // 4-player: 0,1 = Semi, 2 = Final
    if (size == 4) {
      if (idx == 2) return 'Final';
      return 'Semi-Final';
    }
    // 8-player: 0-3 = Quarter, 4-5 = Semi, 6 = Final
    if (idx == 6) return 'Final';
    if (idx == 4 || idx == 5) return 'Semi-Final';
    return 'Quarter-Final';
  }
}

// ── Score pip (win dots) ─────────────────────────────────────────────────────
class _ScorePip extends StatelessWidget {
  final int wins;
  final String label;
  const _ScorePip({required this.wins, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          children: List.generate(2, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < wins
                  ? const Color(0xFF4ADE80)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          )),
        ),
      ],
    );
  }
}

// ── Board cell ───────────────────────────────────────────────────────────────
class _BoardCell extends StatelessWidget {
  final String value;
  final bool isWinning;
  final VoidCallback? onTap;

  const _BoardCell(
      {required this.value, required this.isWinning, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = value == 'X'
        ? const Color(0xFF38BDF8)
        : value == 'O'
            ? const Color(0xFFF472B6)
            : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isWinning
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWinning ? color : Colors.white.withValues(alpha: 0.15),
            width: isWinning ? 2 : 1,
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
