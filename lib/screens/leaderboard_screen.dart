import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../utils/theme_utils.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameService = GameService();

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: appBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
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
                        'Leaderboard',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Top 3 podium header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
                  ).createShader(bounds),
                  child: const Text(
                    '🏆 Top Players',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: gameService.leaderboardStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    final players = snap.data ?? [];
                    if (players.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🎮', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(
                              'No games played yet!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Win online games to appear here.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i];
                        final name = p['displayName'] as String? ?? 'Player';
                        final wins = (p['wins'] as num?)?.toInt() ?? 0;
                        final rank = i + 1;

                        Color rankColor;
                        String rankEmoji;
                        if (rank == 1) { rankColor = const Color(0xFFFBBF24); rankEmoji = '🥇'; }
                        else if (rank == 2) { rankColor = const Color(0xFFD1D5DB); rankEmoji = '🥈'; }
                        else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankEmoji = '🥉'; }
                        else { rankColor = Colors.white54; rankEmoji = '#$rank'; }

                        final isTopThree = rank <= 3;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isTopThree
                                ? rankColor.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isTopThree
                                  ? rankColor.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.1),
                              width: isTopThree ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  rankEmoji,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isTopThree ? 24 : 14,
                                    color: rankColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              UserAvatar(
                                uid: p['uid']?.toString() ?? '',
                                name: name,
                                size: 40,
                                iconSize: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTopThree ? 16 : 15,
                                    fontWeight: isTopThree
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isTopThree
                                      ? rankColor.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emoji_events,
                                        size: 14,
                                        color: isTopThree
                                            ? rankColor
                                            : Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$wins',
                                      style: TextStyle(
                                        color: isTopThree
                                            ? rankColor
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
