import 'package:flutter/material.dart';
import '../services/game_service.dart';

class SpectatorScreen extends StatelessWidget {
  const SpectatorScreen({super.key, required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final gameService = GameService();
    return StreamBuilder<GameModel?>(
      stream: gameService.gameStream(gameId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShell(context, child: const Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildShell(context, child: _buildGone(context));
        }
        return _buildGame(context, snapshot.data!, gameService);
      },
    );
  }

  Widget _buildGame(BuildContext context, GameModel game, GameService gameService) {
    final xName = game.playerX['displayName'] ?? 'Player X';
    final oName = game.playerO['displayName'] ?? 'Player O';

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
                    // Top bar
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text('Spectating', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text('${game.spectators.length}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Players
                    Row(
                      children: [
                        Expanded(child: _PlayerTile(name: xName, symbol: 'X', isActive: game.currentPlayer == 'X' && game.status == 'playing')),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('vs', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                        ),
                        Expanded(child: _PlayerTile(name: oName, symbol: 'O', isActive: game.currentPlayer == 'O' && game.status == 'playing')),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Scores
                    Row(
                      children: [
                        Expanded(child: _ScorePill(score: game.xScore, color: const Color(0xFF38BDF8))),
                        const SizedBox(width: 8),
                        Expanded(child: _ScorePill(score: game.oScore, color: const Color(0xFFF472B6))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusText(game),
                        key: ValueKey(_statusText(game)),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _statusColor(game)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Board (read-only)
                    AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 9,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final winning = _isWinningCell(game.board, index);
                          final value = game.board[index];
                          final color = value == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: winning
                                  ? color.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: value.isEmpty ? 0.06 : 0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: winning ? color.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.12),
                                width: winning ? 2.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(value,
                                  style: TextStyle(
                                    color: value.isEmpty ? Colors.transparent : color,
                                    fontSize: 56, fontWeight: FontWeight.w900,
                                  )),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Room code
                    Text('Room: $gameId',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12, letterSpacing: 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(GameModel game) {
    if (game.winner.isNotEmpty) {
      final name = game.winner == 'X'
          ? (game.playerX['displayName'] ?? 'X')
          : (game.playerO['displayName'] ?? 'O');
      return '$name wins!';
    }
    if (game.isDraw) return "It's a draw!";
    if (game.status == 'waiting') return 'Waiting for players...';
    final name = game.currentPlayer == 'X'
        ? (game.playerX['displayName'] ?? 'X')
        : (game.playerO['displayName'] ?? 'O');
    return "$name's turn";
  }

  Color _statusColor(GameModel game) {
    if (game.winner.isNotEmpty) return const Color(0xFF4ADE80);
    if (game.isDraw) return const Color(0xFFFBBF24);
    return Colors.white70;
  }

  bool _isWinningCell(List<String> board, int index) {
    const lines = [
      [0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]
    ];
    for (final line in lines) {
      final f = board[line[0]];
      if (f.isNotEmpty && f == board[line[1]] && f == board[line[2]] && line.contains(index)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildGone(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        const Text('Game ended', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
      ],
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    return Scaffold(
      body: Container(decoration: _bgDecoration, child: SafeArea(child: child)),
    );
  }

  BoxDecoration get _bgDecoration => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
    ),
  );
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.name, required this.symbol, required this.isActive});
  final String name;
  final String symbol;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = symbol == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(symbol, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text('$score', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
