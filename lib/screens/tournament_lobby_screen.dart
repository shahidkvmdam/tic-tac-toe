import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/tournament_service.dart';
import '../utils/theme_utils.dart';
import 'tournament_bracket_screen.dart';

class TournamentLobbyScreen extends StatefulWidget {
  const TournamentLobbyScreen({super.key});

  @override
  State<TournamentLobbyScreen> createState() => _TournamentLobbyScreenState();
}

class _TournamentLobbyScreenState extends State<TournamentLobbyScreen> {
  final _service = TournamentService();
  final _auth = AuthService();
  bool _isLoading = false;

  String get _displayName => FirebaseAuth.instance.currentUser?.displayName ?? 'Player';

  Future<void> _enter(int size) async {
    setState(() => _isLoading = true);
    try {
      final id = await _service.autoJoinOrCreate(size, _displayName);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TournamentWaitingScreen(tournamentId: id, size: size),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: appBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Tournament',
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events,
                            color: Color(0xFFF59E0B), size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'Choose Tournament Size',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'App will automatically find or create\na tournament for you.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: _SizeCard(
                                players: 2,
                                icon: Icons.person,
                                color: const Color(0xFF10B981),
                                description: 'Direct\nFinal',
                                onTap: _isLoading ? null : () => _enter(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SizeCard(
                                players: 4,
                                icon: Icons.group,
                                color: const Color(0xFF6D28D9),
                                description: 'Semi-Final\n+ Final',
                                onTap: _isLoading ? null : () => _enter(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SizeCard(
                                players: 8,
                                icon: Icons.groups,
                                color: const Color(0xFFF59E0B),
                                description: 'Quarter\n+ Semi + Final',
                                onTap: _isLoading ? null : () => _enter(8),
                              ),
                            ),
                          ],
                        ),
                        if (_isLoading) ...[
                          const SizedBox(height: 32),
                          const CircularProgressIndicator(
                              color: Color(0xFF6D28D9)),
                          const SizedBox(height: 12),
                          Text(
                            'Finding tournament...',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Size selection card ──────────────────────────────────────────────────────
class _SizeCard extends StatelessWidget {
  final int players;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback? onTap;

  const _SizeCard(
      {required this.players,
      required this.icon,
      required this.color,
      required this.description,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? color : Colors.white30, size: 40),
            const SizedBox(height: 12),
            Text(
              '$players Players',
              style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tournament Waiting Room
// ═══════════════════════════════════════════════════════════════════════════
class TournamentWaitingScreen extends StatefulWidget {
  final String tournamentId;
  final int size;

  const TournamentWaitingScreen(
      {super.key, required this.tournamentId, required this.size});

  @override
  State<TournamentWaitingScreen> createState() =>
      _TournamentWaitingScreenState();
}

class _TournamentWaitingScreenState extends State<TournamentWaitingScreen> {
  final _service = TournamentService();
  final _auth = AuthService();
  bool _navigated = false;
  bool _autoStartCalled = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) await _service.leaveTournament(widget.tournamentId);
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: appBackground(context),
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _service.streamTournament(widget.tournamentId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6D28D9)));
                }

                final data = snap.data!.data() as Map<String, dynamic>?;
                if (data == null) {
                  return const Center(
                      child: Text('Tournament was cancelled.',
                          style: TextStyle(color: Colors.white)));
                }

                final status = data['status'] as String;
                final players = List<Map<String, dynamic>>.from(
                    data['players'] as List);
                final isFull = players.length >= widget.size;

                // Auto-start when full — every client tries, Firestore
                // transaction inside startTournament prevents duplicate starts
                if (isFull && status == 'waiting' && !_autoStartCalled) {
                  _autoStartCalled = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    try {
                      await _service.startTournament(widget.tournamentId);
                    } catch (e) {
                      debugPrint('startTournament error: $e');
                      if (mounted) setState(() => _autoStartCalled = false);
                    }
                  });
                }

                // Auto-navigate when tournament starts
                if (status == 'in_progress' && !_navigated) {
                  _navigated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => TournamentBracketScreen(
                          tournamentId: widget.tournamentId),
                    ));
                  });
                }

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () async {
                              await _service
                                  .leaveTournament(widget.tournamentId);
                              if (mounted) Navigator.of(context).pop();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Waiting Room',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          // Copy room ID
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white70),
                            tooltip: 'Copy room ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: widget.tournamentId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Room ID copied!')),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(
                        '${players.length} / ${widget.size} players joined',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Player slots
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.5,
                          ),
                          itemCount: widget.size,
                          itemBuilder: (context, i) {
                            final filled = i < players.length;
                            final name =
                                filled ? players[i]['name'] as String : null;
                            final isMe =
                                filled && players[i]['uid'] == _uid;
                            return _PlayerSlot(
                              slot: i + 1,
                              name: name,
                              isMe: isMe,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bracket preview
                      _BracketPreview(
                          players: players, size: widget.size),

                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF6D28D9)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isFull
                                  ? 'Starting tournament...'
                                  : 'Waiting for players (${players.length}/${widget.size})...',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Player slot widget ───────────────────────────────────────────────────────
class _PlayerSlot extends StatelessWidget {
  final int slot;
  final String? name;
  final bool isMe;

  const _PlayerSlot({required this.slot, this.name, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final filled = name != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: filled
            ? (isMe
                ? const Color(0xFF6D28D9).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1))
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled
              ? (isMe
                  ? const Color(0xFF6D28D9)
                  : Colors.white.withValues(alpha: 0.2))
              : Colors.white.withValues(alpha: 0.08),
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            filled ? Icons.person : Icons.person_outline,
            color: filled
                ? (isMe ? const Color(0xFFA78BFA) : Colors.white70)
                : Colors.white24,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filled ? (isMe ? '${name!} (You)' : name!) : 'Player $slot',
              style: TextStyle(
                color: filled
                    ? (isMe ? const Color(0xFFA78BFA) : Colors.white)
                    : Colors.white30,
                fontWeight:
                    filled ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bracket preview ──────────────────────────────────────────────────────────
class _BracketPreview extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final int size;

  const _BracketPreview({required this.players, required this.size});

  @override
  Widget build(BuildContext context) {
    String text = '';
    if (size == 2) {
      final p = (i) => i < players.length ? players[i]['name'] as String : 'Player ${i + 1}';
      text = '${p(0)} vs ${p(1)}  →  Final';
    } else if (size == 4) {
      final p = (i) => i < players.length ? players[i]['name'] as String : 'Player ${i + 1}';
      text = '${p(0)} vs ${p(1)}  •  ${p(2)} vs ${p(3)}  →  Final';
    } else {
      text = 'Quarters → Semis → Final';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
