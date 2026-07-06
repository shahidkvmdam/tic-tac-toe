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
      });

      if (_winner.isNotEmpty || _isDraw) {
        _handleGameEnd();
      }
    });
  }

  void _handleGameEnd() {
    if (_reportedWinner) return;

    if (_winner == _mySymbol) {
      _confettiController.play();
      SoundService.instance.playWin();
      HapticFeedback.vibrate();
    } else if (_winner == _opponentSymbol) {
      _shakeController.forward(from: 0);
      _flashController
          .forward(from: 0)
          .then((_) => _flashController.reverse());
      HapticFeedback.heavyImpact();
      SoundService.instance.playLose();
    } else {
      SoundService.instance.playDraw();
    }
  }

  Future<void> _reportWinner(String winnerUid) async {
    if (_reportedWinner) return;
    _reportedWinner = true;
    // Only player1 (X) reports to avoid double writes
    if (_mySymbol != 'X') return;
    await _service.reportMatchWinner(
        widget.tournamentId, widget.match.matchIndex, winnerUid);
  }

  Future<void> _playMove(int index) async {
    if (_board[index].isNotEmpty || _winner.isNotEmpty || _isDraw) return;
    if (_currentPlayer != _mySymbol) return;

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

    if (winner.isNotEmpty) {
      final winnerUid = winner == widget.match.player1Uid[0]
          ? widget.match.player1Uid
          : widget.match.player2Uid;
      // Determine winner UID from symbol
      final wUid = winner == 'X'
          ? widget.match.player1Uid
          : widget.match.player2Uid;
      await _reportWinner(wUid);
    } else if (isDraw) {
      // On draw, player1 (X) wins by default (or re-play — here we give X the win)
      await _reportWinner(widget.match.player1Uid);
    }
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

  String get _statusText {
    if (_winner == _mySymbol) {
      return _isFinalMatch
          ? 'You are the Champion! 🏆'
          : 'You win! 🎉 Moving to next round...';
    }
    if (_winner == _opponentSymbol) {
      return _isFinalMatch
          ? '$_opponentName is the Champion! 🏆'
          : '$_opponentName wins this match.';
    }
    if (_isDraw) return 'Draw — advancing Player 1...';
    if (_currentPlayer == _mySymbol) return 'Your turn';
    return "$_opponentName's turn...";
  }

  Color get _statusColor {
    if (_winner == _mySymbol) return const Color(0xFF4ADE80);
    if (_winner == _opponentSymbol) return const Color(0xFFF87171);
    if (_isDraw) return const Color(0xFFFBBF24);
    return Colors.white;
  }

  bool get _gameOver => _winner.isNotEmpty || _isDraw;

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

                          if (_gameOver) ...[
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
