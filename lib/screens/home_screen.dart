import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/avatar_service.dart';
import '../services/billing_service.dart';
import '../services/game_service.dart';
import '../utils/theme_utils.dart';
import 'lobby_screen.dart';
import 'username_screen.dart';
import 'ai_game_screen.dart';
import 'leaderboard_screen.dart';
import 'donate_screen.dart';
import 'sent_requests_screen.dart';
import 'tournament_lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPlayGameExpanded = false;
  final GameService _gameService = GameService();
  final BillingService _billingService = BillingService.instance;
  StreamSubscription? _unreadMessagesSub;
  StreamSubscription? _incomingInvitationsSub;
  StreamSubscription? _incomingGameRequestsSub;
  StreamSubscription<List<String>>? _badgesSub;
  int _unreadMessageCount = 0;
  int _incomingInvitationCount = 0;
  int _incomingGameRequestCount = 0;
  List<String> _badges = [];

  int get _totalBadgeCount => _unreadMessageCount + _incomingInvitationCount + _incomingGameRequestCount;

  @override
  void initState() {
    super.initState();
    _unreadMessagesSub = _gameService.unreadMessageSendersStream().listen(
      (senders) {
        if (mounted) {
          setState(() => _unreadMessageCount = senders.length);
        }
      },
      onError: (e) => debugPrint('Unread messages stream error: $e'),
    );
    _incomingInvitationsSub = _gameService.incomingInvitationsStream().listen(
      (invitations) {
        if (mounted) {
          setState(() => _incomingInvitationCount = invitations.length);
        }
      },
      onError: (e) => debugPrint('Incoming invitations stream error: $e'),
    );
    _incomingGameRequestsSub = _gameService.incomingGameRequestsStream().listen(
      (requests) {
        if (mounted) {
          setState(() => _incomingGameRequestCount = requests.length);
        }
      },
      onError: (e) => debugPrint('Incoming game requests stream error: $e'),
    );

    final uid = _billingService.currentUser?.uid;
    if (uid != null) {
      _badgesSub = _billingService.userBadgesStream(uid).listen(
        (badges) {
          if (mounted) {
            setState(() => _badges = badges);
          }
        },
        onError: (e) => debugPrint('Badges stream error: $e'),
      );
    }
  }

  @override
  void dispose() {
    _unreadMessagesSub?.cancel();
    _incomingInvitationsSub?.cancel();
    _incomingGameRequestsSub?.cancel();
    _badgesSub?.cancel();
    super.dispose();
  }

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
        decoration: appBackground(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Top bar ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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

                  // ── Profile section ──────────────────────
                  GestureDetector(
                    onTap: () => _showAvatarOptions(context),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                          ),
                          child: ClipOval(
                            child: AvatarService.instance.hasCustomImage
                                ? Image.file(File(AvatarService.instance.imagePath!),
                                    width: 80, height: 80, fit: BoxFit.cover)
                                : Center(child: Text(AvatarService.instance.selected,
                                    style: const TextStyle(fontSize: 38))),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6750A4),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Game name — faded
                  Text(
                    'TIC TAC TOE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Player name — big & stylish
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFA78BFA), Color(0xFF60A5FA)],
                    ).createShader(bounds),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  if (_badges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: _badges.map((badge) => _BadgeChip(badge: badge)).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Game mode cards ──────────────────────
                  Stack(
                    children: [
                      _ModeCard(
                        icon: Icons.gamepad,
                        title: 'Chat and Play',
                        subtitle: 'Friends, invitations, and messages',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SentRequestsScreen())),
                      ),
                      if (_totalBadgeCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              _totalBadgeCount > 9 ? '9+' : '$_totalBadgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ModeCard(
                    icon: Icons.sports_esports,
                    title: 'Play Game',
                    subtitle: 'Online, Local, or vs AI',
                    onTap: () => setState(() => _isPlayGameExpanded = !_isPlayGameExpanded),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _isPlayGameExpanded
                        ? Column(
                            children: [
                              const SizedBox(height: 10),
                              _ModeCard(
                                icon: Icons.wifi,
                                title: 'Play Online',
                                subtitle: 'Quick match with strangers or play with friends',
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const LobbyScreen())),
                              ),
                              const SizedBox(height: 10),
                              _ModeCard(
                                icon: Icons.people,
                                title: 'Play Locally',
                                subtitle: 'Two players on the same device',
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const _LocalGameWrapper())),
                              ),
                              const SizedBox(height: 10),
                              _ModeCard(
                                icon: Icons.emoji_events,
                                title: 'Tournament',
                                subtitle: '4 or 8 players · Bracket · Multiplayer',
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TournamentLobbyScreen())),
                              ),
                              const SizedBox(height: 10),
                              _ModeCard(
                                icon: Icons.smart_toy,
                                title: 'vs AI',
                                subtitle: 'Easy / Medium / Hard · Tournament · Timed',
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AiGameScreen())),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),
                  _ModeCard(
                    icon: Icons.leaderboard,
                    title: 'Leaderboard',
                    subtitle: 'Top players ranked by online wins',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                  ),
                  const SizedBox(height: 10),
                  _ModeCard(
                    icon: Icons.favorite,
                    title: 'Support Us',
                    subtitle: 'Help keep the app ad-free',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DonateScreen())),
                  ),

                  const SizedBox(height: 12),

                  // ── Bottom action row ────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileAction(
                          icon: const Icon(Icons.edit, color: Colors.white70, size: 22),
                          label: 'Username',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const UsernameScreen(isEditing: true))),
                        ),
                        VerticalDivider(width: 1, color: Colors.white.withValues(alpha: 0.15), thickness: 1, indent: 8, endIndent: 8),
                        _ProfileAction(
                          icon: Text(AvatarService.instance.selected, style: const TextStyle(fontSize: 22)),
                          label: 'Avatar',
                          onTap: () => _showAvatarOptions(context),
                        ),
                        VerticalDivider(width: 1, color: Colors.white.withValues(alpha: 0.15), thickness: 1, indent: 8, endIndent: 8),
                        _ProfileAction(
                          icon: const Icon(Icons.logout, color: Colors.white70, size: 22),
                          label: 'Logout',
                          onTap: () async => await authService.logout(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAvatarOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final picker = ImagePicker();
                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (file != null) {
                  await AvatarService.instance.setCustomImage(file.path);
                  if (mounted) setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Text('😀', style: TextStyle(fontSize: 24)),
              title: const Text('Choose Emoji', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAvatarPicker(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Choose your avatar',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
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
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String badge;

  const _BadgeChip({required this.badge});

  Color get _color {
    switch (badge) {
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            badge[0].toUpperCase() + badge.substring(1),
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.icon, required this.label, required this.onTap});
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
            ],
          ),
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
