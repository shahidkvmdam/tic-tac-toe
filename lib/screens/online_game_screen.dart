import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final GameService _gameService = GameService();

  void _onCellTap(GameModel game, int index) {
    if (!game.isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for your turn!'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    _gameService.playMove(widget.gameId, index, game);
  }

  Future<void> _leaveGame(GameModel? game) async {
    final isHost = game?.mySymbol == 'X';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Leave Game', style: TextStyle(color: Colors.white)),
        content: Text(
          isHost
              ? 'Are you sure you want to leave? The room will be deleted.'
              : 'Are you sure you want to leave?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (isHost) await _gameService.deleteGame(widget.gameId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.gameId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room code copied!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _statusText(GameModel game) {
    if (game.status == 'waiting') {
      return 'Waiting for opponent...';
    }
    if (game.winner.isNotEmpty) {
      final mySymbol = game.mySymbol;
      if (game.winner == mySymbol) return 'You win! 🎉';
      return 'You lose! 😔';
    }
    if (game.isDraw) return "It's a draw! 🤝";
    if (game.isMyTurn) return 'Your turn (${game.mySymbol})';
    return "${game.opponentName}'s turn...";
  }

  Color _statusColor(GameModel game) {
    if (game.winner.isNotEmpty) {
      return game.winner == game.mySymbol
          ? const Color(0xFF4ADE80)
          : const Color(0xFFF87171);
    }
    if (game.isDraw) return const Color(0xFFFBBF24);
    if (game.isMyTurn) return const Color(0xFF38BDF8);
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameModel?>(
      stream: _gameService.gameStream(widget.gameId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildRoomDeleted();
        }

        final game = snapshot.data!;
        return _buildGame(game);
      },
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      body: Container(
        decoration: _bgDecoration,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRoomDeleted() {
    return Scaffold(
      body: Container(
        decoration: _bgDecoration,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Room no longer exists',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('The host may have left the game.',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(GameModel game) {
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top bar
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.exit_to_app,
                              color: Colors.white),
                          onPressed: () => _leaveGame(game),
                        ),
                        const Expanded(
                          child: Text(
                            'Online Game',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Room code chip
                        GestureDetector(
                          onTap: _copyRoomCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.gameId,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy,
                                    size: 13,
                                    color:
                                        Colors.white.withValues(alpha: 0.6)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Player info row
                    _PlayerRow(game: game),
                    const SizedBox(height: 16),

                    // Score board
                    if (game.status != 'waiting')
                      _OnlineScoreBoard(game: game),

                    const SizedBox(height: 16),

                    // Status text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusText(game),
                        key: ValueKey(_statusText(game)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(game),
                        ),
                      ),
                    ),

                    // Waiting indicator
                    if (game.status == 'waiting') ...[
                      const SizedBox(height: 16),
                      _WaitingCard(gameId: widget.gameId,
                          onCopy: _copyRoomCode),
                    ],

                    if (game.status != 'waiting') ...[
                      const SizedBox(height: 24),
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
                            final isWinningCell =
                                _isWinningCell(game.board, index);
                            return _OnlineBoardCell(
                              value: game.board[index],
                              isWinningCell: isWinningCell,
                              isMyTurn: game.isMyTurn,
                              onTap: game.status == 'playing'
                                  ? () => _onCellTap(game, index)
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Rematch / Back buttons shown after game ends
                      if (game.status == 'finished') ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _gameService.resetGame(widget.gameId),
                                icon: const Icon(Icons.replay),
                                label: const Text('Rematch'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  if (game.mySymbol == 'X') {
                                    await _gameService.deleteGame(widget.gameId);
                                  }
                                  if (mounted) Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.home,
                                    color: Colors.white),
                                label: const Text('Home',
                                    style:
                                        TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isWinningCell(List<String> board, int index) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final f = board[line[0]];
      if (f.isNotEmpty &&
          f == board[line[1]] &&
          f == board[line[2]] &&
          line.contains(index)) {
        return true;
      }
    }
    return false;
  }

  BoxDecoration get _bgDecoration => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
        ),
      );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.game});
  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final mySymbol = game.mySymbol;
    final myName = mySymbol == 'X'
        ? (game.playerX['displayName'] ?? 'You')
        : (game.playerO['displayName'] ?? 'You');
    final oppName = mySymbol == 'X'
        ? (game.playerO['displayName'] ?? 'Waiting...')
        : (game.playerX['displayName'] ?? 'Waiting...');
    final myTurn = game.isMyTurn && game.status == 'playing';
    final oppTurn = !game.isMyTurn && game.status == 'playing';

    return Row(
      children: [
        Expanded(
          child: _PlayerCard(
            name: myName,
            symbol: mySymbol,
            label: 'You',
            isActive: myTurn,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('VS',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        Expanded(
          child: _PlayerCard(
            name: oppName,
            symbol: mySymbol == 'X' ? 'O' : 'X',
            label: 'Opponent',
            isActive: oppTurn,
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.name,
    required this.symbol,
    required this.label,
    required this.isActive,
  });

  final String name;
  final String symbol;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final symbolColor =
        symbol == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? symbolColor.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? symbolColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(symbol,
              style: TextStyle(
                  color: symbolColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.gameId, required this.onCopy});
  final String gameId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            'Share this room code with your friend',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gameId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.copy,
                      color: Colors.white.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap code to copy',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OnlineBoardCell extends StatelessWidget {
  const _OnlineBoardCell({
    required this.value,
    required this.isWinningCell,
    required this.isMyTurn,
    required this.onTap,
  });

  final String value;
  final bool isWinningCell;
  final bool isMyTurn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final symbolColor =
        value == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isWinningCell
              ? symbolColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: value.isEmpty ? 0.08 : 0.14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isWinningCell
                ? symbolColor.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.14),
            width: isWinningCell ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isWinningCell
                  ? symbolColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.16),
              blurRadius: isWinningCell ? 20 : 16,
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
                color: value.isEmpty ? Colors.transparent : symbolColor,
                fontSize: 56,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineScoreBoard extends StatelessWidget {
  const _OnlineScoreBoard({required this.game});
  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final mySymbol = game.mySymbol;
    final myScore = mySymbol == 'X' ? game.xScore : game.oScore;
    final oppScore = mySymbol == 'X' ? game.oScore : game.xScore;
    final myName = mySymbol == 'X'
        ? (game.playerX['displayName'] ?? 'You')
        : (game.playerO['displayName'] ?? 'You');
    final oppName = game.opponentName;

    return Row(
      children: [
        Expanded(
          child: _ScoreTile(
            name: myName,
            score: myScore,
            symbol: mySymbol,
            isMe: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            ':',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: _ScoreTile(
            name: oppName,
            score: oppScore,
            symbol: mySymbol == 'X' ? 'O' : 'X',
            isMe: false,
          ),
        ),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.name,
    required this.score,
    required this.symbol,
    required this.isMe,
  });

  final String name;
  final int score;
  final String symbol;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final symbolColor =
        symbol == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            isMe ? 'You' : 'Opponent',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '$score',
              key: ValueKey(score),
              style: TextStyle(
                color: symbolColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
