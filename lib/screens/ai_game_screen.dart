import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/sound_service.dart';

class AiGameScreen extends StatefulWidget {
  const AiGameScreen({super.key});

  @override
  State<AiGameScreen> createState() => _AiGameScreenState();
}

class _AiGameScreenState extends State<AiGameScreen>
    with TickerProviderStateMixin {
  // ── Settings ──────────────────────────────────────────────
  AiDifficulty _difficulty = AiDifficulty.medium;
  int _tournamentTarget = 3; // best of 3 or best of 5
  int _turnTimeLimit = 10; // seconds per turn (0 = no limit)

  // ── Game state ────────────────────────────────────────────
  List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X'; // X = human, O = AI
  String _winner = '';
  bool _isDraw = false;
  bool _aiThinking = false;

  // ── Scores ────────────────────────────────────────────────
  int _humanScore = 0;
  int _aiScore = 0;
  bool get _tournamentOver =>
      _humanScore > _tournamentTarget ~/ 2 ||
      _aiScore > _tournamentTarget ~/ 2;

  // ── Timer ─────────────────────────────────────────────────
  int _timeLeft = 0;
  Timer? _timer;

  // ── Animations ────────────────────────────────────────────
  late ConfettiController _confettiController;
  late AnimationController _shakeController;
  late AnimationController _flashController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _flashAnimation;

  bool _settingsConfirmed = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  // ── Timer logic ───────────────────────────────────────────
  void _startTimer() {
    if (_turnTimeLimit == 0) return;
    _timer?.cancel();
    setState(() => _timeLeft = _turnTimeLimit);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _autoSkip();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (_turnTimeLimit > 0) setState(() => _timeLeft = 0);
  }

  void _autoSkip() {
    if (_winner.isNotEmpty || _isDraw || _currentPlayer != 'X') return;
    // Human timed out — AI gets the turn
    setState(() => _currentPlayer = 'O');
    _triggerAiMove();
  }

  // ── Move logic ────────────────────────────────────────────
  void _playMove(int index) {
    if (_board[index].isNotEmpty || _winner.isNotEmpty || _isDraw) return;
    if (_currentPlayer != 'X' || _aiThinking) return;
    HapticFeedback.lightImpact();
    SoundService.instance.playTap();
    _stopTimer();
    setState(() {
      _board[index] = 'X';
      _winner = _findWinner(_board);
      if (_winner.isNotEmpty) {
        _humanScore++;
        _confettiController.play();
        HapticFeedback.vibrate();
        SoundService.instance.playWin();
      } else if (!_board.contains('')) {
        _isDraw = true;
        SoundService.instance.playDraw();
      } else {
        _currentPlayer = 'O';
        _triggerAiMove();
      }
    });
  }

  void _triggerAiMove() {
    setState(() => _aiThinking = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final ai = AiService(_difficulty);
      final boardCopy = List<String>.from(_board);
      final move = ai.getBestMove(boardCopy, 'O');
      setState(() {
        _aiThinking = false;
        _board[move] = 'O';
        _winner = _findWinner(_board);
        if (_winner.isNotEmpty) {
          _aiScore++;
          _shakeController.forward(from: 0);
          _flashController
              .forward(from: 0)
              .then((_) => _flashController.reverse());
          HapticFeedback.heavyImpact();
          SoundService.instance.playLose();
        } else if (!_board.contains('')) {
          _isDraw = true;
          SoundService.instance.playDraw();
        } else {
          _currentPlayer = 'X';
          _startTimer();
        }
      });
    });
  }

  void _resetBoard() {
    _stopTimer();
    setState(() {
      _board = List.filled(9, '');
      _currentPlayer = 'X';
      _winner = '';
      _isDraw = false;
      _aiThinking = false;
    });
    _startTimer();
  }

  void _resetAll() {
    _stopTimer();
    setState(() {
      _board = List.filled(9, '');
      _currentPlayer = 'X';
      _winner = '';
      _isDraw = false;
      _aiThinking = false;
      _humanScore = 0;
      _aiScore = 0;
    });
    _startTimer();
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
          line.contains(index)) { return true; }
    }
    return false;
  }

  String get _statusText {
    if (_tournamentOver) {
      return _humanScore > _aiScore ? 'You won the tournament! 🏆' : 'AI won the tournament! 🤖';
    }
    if (_winner == 'X') return 'You win! 🎉';
    if (_winner == 'O') return 'AI wins! 🤖';
    if (_isDraw) return "It's a draw! 🤝";
    if (_aiThinking) return 'AI is thinking...';
    if (_turnTimeLimit > 0 && _timeLeft > 0) return 'Your turn — $_timeLeft s';
    return 'Your turn';
  }

  Color get _statusColor {
    if (_winner == 'X' || (_tournamentOver && _humanScore > _aiScore)) {
      return const Color(0xFF4ADE80);
    }
    if (_winner == 'O' || (_tournamentOver && _aiScore > _humanScore)) {
      return const Color(0xFFF87171);
    }
    if (_isDraw) return const Color(0xFFFBBF24);
    if (_turnTimeLimit > 0 && _timeLeft <= 3 && _timeLeft > 0) {
      return const Color(0xFFF87171);
    }
    return Colors.white;
  }

  // ── Settings screen ───────────────────────────────────────
  Widget _buildSettings() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: _bgDecoration,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text('vs AI',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Icon(Icons.smart_toy, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    Text('Choose your challenge',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 15)),
                    const SizedBox(height: 36),

                    // Difficulty
                    _SectionLabel('Difficulty'),
                    const SizedBox(height: 12),
                    Row(
                      children: AiDifficulty.values.map((d) {
                        final selected = _difficulty == d;
                        final label =
                            d.name[0].toUpperCase() + d.name.substring(1);
                        final color = d == AiDifficulty.easy
                            ? const Color(0xFF4ADE80)
                            : d == AiDifficulty.medium
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFF87171);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _difficulty = d),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? color
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(label,
                                      style: TextStyle(
                                          color:
                                              selected ? color : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Tournament
                    _SectionLabel('Tournament'),
                    const SizedBox(height: 12),
                    Row(
                      children: [3, 5].map((n) {
                        final selected = _tournamentTarget == n;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _tournamentTarget = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF6750A4)
                                        .withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF6750A4)
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Text('Best of $n',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Timer
                    _SectionLabel('Turn Timer'),
                    const SizedBox(height: 12),
                    Row(
                      children: [0, 10, 15, 30].map((t) {
                        final selected = _turnTimeLimit == t;
                        final label = t == 0 ? 'Off' : '${t}s';
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _turnTimeLimit = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF38BDF8)
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Text(label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() => _settingsConfirmed = true);
                          _startTimer();
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Game',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Game screen ───────────────────────────────────────────
  Widget _buildGame() {
    final gameOver = _winner.isNotEmpty || _isDraw;
    final tournamentDone = _tournamentOver;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = sin(_shakeAnimation.value * pi * 8) * 12;
              return Transform.translate(
                  offset: Offset(offset, 0), child: child);
            },
            child: Container(
              width: double.infinity,
              decoration: _bgDecoration,
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
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                onPressed: () {
                                  _stopTimer();
                                  setState(() {
                                    _settingsConfirmed = false;
                                    _humanScore = 0;
                                    _aiScore = 0;
                                    _board = List.filled(9, '');
                                    _winner = '';
                                    _isDraw = false;
                                    _currentPlayer = 'X';
                                    _aiThinking = false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('vs AI',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                    Text(
                                      '${_difficulty.name[0].toUpperCase()}${_difficulty.name.substring(1)} · Best of $_tournamentTarget',
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
                          const SizedBox(height: 20),

                          // Score board
                          Row(
                            children: [
                              Expanded(
                                  child: _ScoreTile(
                                      label: 'You',
                                      score: _humanScore,
                                      color: const Color(0xFF38BDF8))),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(':',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.4),
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900)),
                              ),
                              Expanded(
                                  child: _ScoreTile(
                                      label: 'AI',
                                      score: _aiScore,
                                      color: const Color(0xFFF472B6))),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Tournament progress
                          _TournamentBar(
                            humanScore: _humanScore,
                            aiScore: _aiScore,
                            target: _tournamentTarget,
                          ),
                          const SizedBox(height: 16),

                          // Timer bar
                          if (_turnTimeLimit > 0 &&
                              !gameOver &&
                              !tournamentDone &&
                              _currentPlayer == 'X')
                            _TimerBar(
                              timeLeft: _timeLeft,
                              total: _turnTimeLimit,
                            ),
                          if (_turnTimeLimit > 0 &&
                              !gameOver &&
                              !tournamentDone &&
                              _currentPlayer == 'X')
                            const SizedBox(height: 12),

                          // Status
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _statusText,
                              key: ValueKey(_statusText),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Board
                          AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 9,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemBuilder: (context, index) {
                                final winning =
                                    _winner.isNotEmpty && _isWinningCell(index);
                                return _BoardCell(
                                  value: _board[index],
                                  isWinning: winning,
                                  onTap: (!gameOver &&
                                          !tournamentDone &&
                                          !_aiThinking)
                                      ? () => _playMove(index)
                                      : null,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Action buttons
                          if (tournamentDone) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _resetAll,
                                icon: const Icon(Icons.replay),
                                label: const Text('Play Again'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _stopTimer();
                                  setState(() {
                                    _settingsConfirmed = false;
                                    _humanScore = 0;
                                    _aiScore = 0;
                                    _board = List.filled(9, '');
                                    _winner = '';
                                    _isDraw = false;
                                    _currentPlayer = 'X';
                                    _aiThinking = false;
                                  });
                                },
                                icon: const Icon(Icons.settings,
                                    color: Colors.white),
                                label: const Text('Change Settings',
                                    style: TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.3))),
                              ),
                            ),
                          ] else if (gameOver) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _resetBoard,
                                    icon: const Icon(Icons.replay),
                                    label: const Text('Next Round'),
                                  ),
                                ),
                              ],
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
          // Red flash on lose
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) => IgnorePointer(
              child: Container(
                  color: Colors.red.withValues(alpha: _flashAnimation.value)),
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

  BoxDecoration get _bgDecoration => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _settingsConfirmed ? _buildGame() : _buildSettings();
  }
}

// ── Helper widgets ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1)),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile(
      {required this.label, required this.score, required this.color});
  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text('$score',
                key: ValueKey(score),
                style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _TournamentBar extends StatelessWidget {
  const _TournamentBar(
      {required this.humanScore,
      required this.aiScore,
      required this.target});
  final int humanScore;
  final int aiScore;
  final int target;

  @override
  Widget build(BuildContext context) {
    final needed = (target ~/ 2) + 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Human dots
        ...List.generate(needed, (i) => _Dot(filled: i < humanScore, color: const Color(0xFF38BDF8))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('Best of $target',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        ),
        // AI dots
        ...List.generate(needed, (i) => _Dot(filled: i < aiScore, color: const Color(0xFFF472B6))),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled, required this.color});
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: filled ? color : Colors.white.withValues(alpha: 0.2)),
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.timeLeft, required this.total});
  final int timeLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? timeLeft / total : 0.0;
    final color = timeLeft <= 3
        ? const Color(0xFFF87171)
        : timeLeft <= total / 2
            ? const Color(0xFFFBBF24)
            : const Color(0xFF4ADE80);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Time left',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            Text('${timeLeft}s',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell(
      {required this.value, required this.isWinning, required this.onTap});
  final String value;
  final bool isWinning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        value == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isWinning
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: value.isEmpty ? 0.08 : 0.14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isWinning
                ? color.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.14),
            width: isWinning ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isWinning
                  ? color.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.16),
              blurRadius: isWinning ? 20 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                  color: value.isEmpty ? Colors.transparent : color,
                  fontSize: 56,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}
