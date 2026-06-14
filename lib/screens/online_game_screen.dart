import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';
import '../utils/theme_utils.dart';
import 'lobby_screen.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  late ConfettiController _confettiController;
  late AnimationController _shakeController;
  late AnimationController _flashController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _flashAnimation;
  String _lastWinner = '';
  String _lastRematchRequest = '';
  bool _lastDraw = false;
  bool _chatOpen = false; // ignore: prefer_final_fields
  int _unreadCount = 0;
  int _lastSeenMessageCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _msgSubscription;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );
    _msgSubscription = _gameService.messagesStream(widget.gameId).listen((msgs) {
      if (!mounted) return;
      final myUid = _gameService.currentUid;
      final opponentMsgs = msgs.where((m) => m['uid'] != myUid).length;
      if (_chatOpen) {
        _lastSeenMessageCount = opponentMsgs;
      } else if (opponentMsgs > _lastSeenMessageCount) {
        final newUnread = opponentMsgs - _lastSeenMessageCount;
        if (newUnread > _unreadCount) {
          SoundService.instance.playMessage();
          setState(() => _unreadCount = newUnread);
        }
      }
    });
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
    _confettiController.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _playLoseAnimation() {
    _shakeController.forward(from: 0);
    _flashController.forward(from: 0).then((_) => _flashController.reverse());
  }

  void _onCellTap(GameModel game, int index) {
    if (!game.isMyTurn) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for your turn!'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    SoundService.instance.playTap();
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
      try {
        await _gameService.abandonGame(widget.gameId);
      } catch (_) {
        // Permission error or network issue — still navigate away
      }
      if (mounted) Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LobbyScreen()));
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

  Future<void> _showRematchDialog(GameModel game) async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Rematch Request', style: TextStyle(color: Colors.white)),
        content: Text(
          '${game.opponentName} wants a rematch!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _gameService.acceptRematch(widget.gameId);
    } else if (accepted == false) {
      await _gameService.declineRematch(widget.gameId);
    }
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
        if (snapshot.data!.status == 'abandoned') {
          return _buildAbandoned();
        }

        final game = snapshot.data!;
        // Fire win/lose animation once per result
        if (game.winner.isNotEmpty && _lastWinner != game.winner) {
          _lastWinner = game.winner;
          if (!game.isSpectator) {
            if (game.winner == game.mySymbol) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _confettiController.play();
                HapticFeedback.vibrate();
                SoundService.instance.playWin();
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _playLoseAnimation();
                HapticFeedback.heavyImpact();
                SoundService.instance.playLose();
              });
            }
          }
        } else if (game.winner.isEmpty) {
          _lastWinner = '';
        }
        if (game.isDraw && !_lastDraw) {
          _lastDraw = true;
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => SoundService.instance.playDraw());
        } else if (!game.isDraw) {
          _lastDraw = false;
        }
        // Show rematch request popup to the opponent
        if (!game.isSpectator &&
            game.rematchRequest.isNotEmpty &&
            game.rematchRequest != game.mySymbol &&
            _lastRematchRequest != game.rematchRequest) {
          _lastRematchRequest = game.rematchRequest;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showRematchDialog(game));
        } else if (game.rematchRequest.isEmpty) {
          _lastRematchRequest = '';
        }
        return _buildGame(game);
      },
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      body: Container(
        decoration: appBackground(context),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAbandoned() {
    return Scaffold(
      body: Container(
        decoration: appBackground(context),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Opponent left the game',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('The other player has disconnected.',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () async {
                  try { await _gameService.deleteGame(widget.gameId); } catch (_) {}
                  if (mounted) Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LobbyScreen()));
                },
                child: const Text('Back to Lobby'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomDeleted() {
    return Scaffold(
      body: Container(
        decoration: appBackground(context),
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
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LobbyScreen())),
                child: const Text('Back to Lobby'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(GameModel game) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _leaveGame(game);
      },
      child: Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = sin(_shakeAnimation.value * pi * 8) * 12;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
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
                        // Mute toggle
                        StatefulBuilder(
                          builder: (ctx, setSt) => IconButton(
                            tooltip: SoundService.instance.enabled ? 'Mute' : 'Unmute',
                            icon: Icon(
                              SoundService.instance.enabled ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () async {
                              await SoundService.instance.setEnabled(!SoundService.instance.enabled);
                              setSt(() {});
                            },
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

                      // Spectator badge
                      if (game.isSpectator) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility, size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              Text('Spectating', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Rematch / Home buttons shown after game ends
                      if (game.status == 'finished' && !game.isSpectator) ...[
                        // If I already requested and waiting
                        if (game.rematchRequest == game.mySymbol)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text('Waiting for opponent to accept rematch...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _gameService.requestRematch(widget.gameId, game.mySymbol),
                              icon: const Icon(Icons.replay),
                              label: const Text('Rematch'),
                            ),
                          ),
                      ],
                      // Chat button
                      if (game.status != 'waiting') ...[
                        const SizedBox(height: 16),
                        Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _chatOpen = !_chatOpen;
                                        if (_chatOpen) {
                                          _unreadCount = 0;
                                        }
                                      });
                                    },
                                    icon: Icon(_chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline, color: Colors.white70, size: 18),
                                    label: Text(_chatOpen ? 'Close Chat' : 'Open Chat', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: _unreadCount > 0
                                          ? const Color(0xFFA78BFA)
                                          : Colors.white.withValues(alpha: 0.2)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                if (_unreadCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$_unreadCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        if (_chatOpen)
                          _ChatPanel(
                            gameId: widget.gameId,
                            gameService: _gameService,
                            chatController: _chatController,
                            scrollController: _chatScrollController,
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
            ), // close AnimatedBuilder child (Container)
          ), // close AnimatedBuilder
          // Red flash overlay — shown when user loses
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.red.withValues(alpha: _flashAnimation.value),
                ),
              );
            },
          ),
          // Confetti overlay — only shown when user wins
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
                Color(0xFF38BDF8),
                Color(0xFFF472B6),
                Color(0xFF4ADE80),
                Color(0xFFFBBF24),
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    ), // close Scaffold
    ); // close PopScope
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

    return Row(
      children: [
        Expanded(
          child: _ScoreTile(
            score: myScore,
            symbol: mySymbol,
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
            score: oppScore,
            symbol: mySymbol == 'X' ? 'O' : 'X',
          ),
        ),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.score,
    required this.symbol,
  });

  final int score;
  final String symbol;

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

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.gameId,
    required this.gameService,
    required this.chatController,
    required this.scrollController,
  });

  final String gameId;
  final GameService gameService;
  final TextEditingController chatController;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final myUid = gameService.currentUid;
    return Container(
      height: 240,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: gameService.messagesStream(gameId),
              builder: (context, snap) {
                final msgs = snap.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scrollController.hasClients) {
                    scrollController.jumpTo(scrollController.position.maxScrollExtent);
                  }
                });
                if (msgs.isEmpty) {
                  return Center(
                    child: Text('No messages yet',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    final isMe = msg['uid'] == myUid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        constraints: const BoxConstraints(maxWidth: 220),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(msg['name'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                            Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                    ),
                    onSubmitted: (v) {
                      gameService.sendMessage(gameId, v);
                      chatController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white70, size: 20),
                  onPressed: () {
                    gameService.sendMessage(gameId, chatController.text);
                    chatController.clear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
