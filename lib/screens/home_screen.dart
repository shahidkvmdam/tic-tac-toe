import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/avatar_service.dart';
import 'lobby_screen.dart';
import 'username_screen.dart';
import 'ai_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final displayName = authService.currentUser?.displayName ??
        authService.currentUser?.phoneNumber ??
        'Player';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top settings bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Sound toggle
                        StatefulBuilder(
                          builder: (ctx, setSt) => IconButton(
                            tooltip: SoundService.instance.enabled ? 'Mute sounds' : 'Enable sounds',
                            icon: Icon(
                              SoundService.instance.enabled ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white70,
                            ),
                            onPressed: () async {
                              await SoundService.instance.setEnabled(!SoundService.instance.enabled);
                              setSt(() {});
                            },
                          ),
                        ),
                        // Theme toggle
                        IconButton(
                          tooltip: themeService.isDark ? 'Light mode' : 'Dark mode',
                          icon: Icon(
                            themeService.isDark ? Icons.light_mode : Icons.dark_mode,
                            color: Colors.white70,
                          ),
                          onPressed: () => themeService.toggle(),
                        ),
                      ],
                    ),
                    // Avatar
                    GestureDetector(
                      onTap: () => _showAvatarPicker(context),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                            ),
                            child: Center(
                              child: Text(
                                AvatarService.instance.selected,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6750A4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.edit, size: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tic Tac Toe',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome, $displayName',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _ModeCard(
                      icon: Icons.people,
                      title: 'Play Locally',
                      subtitle: 'Two players on the same device',
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const _LocalGameWrapper(),
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      icon: Icons.smart_toy,
                      title: 'vs AI',
                      subtitle: 'Easy / Medium / Hard · Tournament · Timed',
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AiGameScreen(),
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      icon: Icons.wifi,
                      title: 'Play Online',
                      subtitle: 'Create or join a room with a friend',
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const LobbyScreen(),
                        ));
                      },
                    ),
                    const SizedBox(height: 40),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              const UsernameScreen(isEditing: true),
                        ));
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text('Edit Username',
                          style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showAvatarPicker(context),
                      icon: Text(AvatarService.instance.selected,
                          style: const TextStyle(fontSize: 18)),
                      label: const Text('Change Avatar', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await authService.logout();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
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

  void _showAvatarPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Choose your avatar',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6, crossAxisSpacing: 10, mainAxisSpacing: 10,
                ),
                itemCount: AvatarService.avatars.length,
                itemBuilder: (_, i) {
                  final emoji = AvatarService.avatars[i];
                  final isSelected = AvatarService.instance.selected == emoji;
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await AvatarService.instance.setAvatar(emoji);
                      setSt(() {});
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6750A4).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6750A4) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.white.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _LocalGameWrapper extends StatefulWidget {
  const _LocalGameWrapper();

  @override
  State<_LocalGameWrapper> createState() => _LocalGameWrapperState();
}

class _LocalGameWrapperState extends State<_LocalGameWrapper> {
  final List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X';
  String _winner = '';
  bool _isDraw = false;
  int _xScore = 0;
  int _oScore = 0;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _statusText {
    if (_winner.isNotEmpty) return 'Player $_winner wins!';
    if (_isDraw) return 'It\'s a draw!';
    return 'Player $_currentPlayer\'s turn';
  }

  void _playMove(int index) {
    if (_board[index].isNotEmpty || _winner.isNotEmpty || _isDraw) return;
    HapticFeedback.lightImpact();
    SoundService.instance.playTap();
    setState(() {
      _board[index] = _currentPlayer;
      _winner = _findWinner();
      if (_winner.isNotEmpty) {
        if (_winner == 'X') { _xScore++; } else { _oScore++; }
        _confettiController.play();
        HapticFeedback.vibrate();
        SoundService.instance.playWin();
      } else if (!_board.contains('')) {
        _isDraw = true;
        SoundService.instance.playDraw();
      } else {
        _currentPlayer = _currentPlayer == 'X' ? 'O' : 'X';
      }
    });
  }

  String _findWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final f = _board[line[0]];
      if (f.isNotEmpty && f == _board[line[1]] && f == _board[line[2]]) return f;
    }
    return '';
  }

  void _resetBoard() {
    setState(() {
      for (var i = 0; i < 9; i++) { _board[i] = ''; }
      _currentPlayer = 'X';
      _winner = '';
      _isDraw = false;
    });
  }

  void _resetScores() {
    setState(() { _xScore = 0; _oScore = 0; });
    _resetBoard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            'Local Game',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        StatefulBuilder(
                          builder: (ctx, setSt) => IconButton(
                            tooltip: SoundService.instance.enabled ? 'Mute' : 'Unmute',
                            icon: Icon(
                              SoundService.instance.enabled ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white70,
                            ),
                            onPressed: () async {
                              await SoundService.instance.setEnabled(!SoundService.instance.enabled);
                              setSt(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _ScoreCard(player: 'X', score: _xScore)),
                        const SizedBox(width: 12),
                        Expanded(child: _ScoreCard(player: 'O', score: _oScore)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 9,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) => _BoardCell(
                          value: _board[index],
                          onTap: () => _playMove(index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _resetBoard,
                            child: const Text('New Round'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resetScores,
                            child: const Text('Reset Score'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
          ),
          // Confetti overlay
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
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.player, required this.score});
  final String player;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Text('Player $player',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Text('$score',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = value == 'X' ? const Color(0xFF38BDF8) : const Color(0xFFF472B6);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: value.isEmpty ? 0.08 : 0.16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
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
                color: color,
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
