import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';
import '../utils/theme_utils.dart';
import 'online_game_screen.dart';
import 'spectator_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GameService _gameService = GameService();
  final _joinCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isCreating = false;
  bool _isJoining = false;
  bool _isSpectating = false;
  bool _isReconnecting = false;
  bool _isMatchmaking = false;
  final _spectateCodeController = TextEditingController();
  final _spectateFormKey = GlobalKey<FormState>();

  Future<void> _createRoom() async {
    setState(() => _isCreating = true);
    try {
      final gameId = await _gameService.createGame();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OnlineGameScreen(gameId: gameId),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create room: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isJoining = true);

    try {
      final result =
          await _gameService.joinGame(_joinCodeController.text.trim());
      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OnlineGameScreen(gameId: result['gameId']),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to join room')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _spectateRoom() async {
    if (!_spectateFormKey.currentState!.validate()) return;
    setState(() => _isSpectating = true);
    try {
      final result = await _gameService.joinAsSpectator(_spectateCodeController.text.trim());
      if (!mounted) return;
      if (result['success'] == true) {
        if (result['isPlayer'] == true) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => OnlineGameScreen(gameId: result['gameId']),
          ));
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => SpectatorScreen(gameId: result['gameId']),
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Cannot spectate room')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSpectating = false);
    }
  }

  Future<void> _reconnect() async {
    setState(() => _isReconnecting = true);
    try {
      final gameId = await _gameService.findActiveGame();
      if (!mounted) return;
      if (gameId != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OnlineGameScreen(gameId: gameId),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active game found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isReconnecting = false);
    }
  }

  Future<void> _quickMatch() async {
    setState(() => _isMatchmaking = true);

    // Show waiting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const SizedBox(
                width: 52, height: 52,
                child: CircularProgressIndicator(color: Color(0xFFA78BFA), strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              const Text('Finding an opponent…',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('This may take up to 60 seconds',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _gameService.cancelMatchmaking();
                  if (mounted) setState(() => _isMatchmaking = false);
                },
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFA78BFA))),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final gameId = await _gameService.joinMatchmaking();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst); // close dialog
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OnlineGameScreen(gameId: gameId),
      ));
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      setState(() => _isMatchmaking = false);
      if (e.toString().contains('cancelled')) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().contains('timeout')
            ? 'No opponents found. Try again later.'
            : 'Matchmaking failed: $e'),
      ));
    }
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _spectateCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isCreating || _isJoining || _isSpectating || _isReconnecting || _isMatchmaking;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isLoading) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      },
      child: Scaffold(
      body: Container(
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
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: isLoading ? null : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const HomeScreen())),
                        ),
                        const Expanded(
                          child: Text(
                            'Online Game',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Icon(Icons.wifi, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Play with a friend online',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Quick Match card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6D28D9), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flash_on, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              const Text('Quick Match',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Get paired with a random opponent instantly',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _quickMatch,
                              icon: _isMatchmaking
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(color: Color(0xFF6D28D9), strokeWidth: 2))
                                  : const Icon(Icons.people, color: Color(0xFF6D28D9)),
                              label: Text(
                                _isMatchmaking ? 'Finding…' : 'Find Opponent',
                                style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Create Room section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create a Room',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Share the room code with your friend',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: isLoading ? null : _createRoom,
                              icon: _isCreating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add),
                              label: Text(
                                  _isCreating ? 'Creating...' : 'Create Room'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white38)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR',
                              style: TextStyle(color: Colors.white70)),
                        ),
                        Expanded(child: Divider(color: Colors.white38)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Reconnect banner
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _reconnect,
                        icon: _isReconnecting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.refresh, color: Colors.white70, size: 18),
                        label: Text(
                          _isReconnecting ? 'Searching...' : 'Reconnect to Active Game',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Join Room section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Join a Room',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter the 6-character room code',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Form(
                            key: _formKey,
                            child: TextFormField(
                              controller: _joinCodeController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9]')),
                                LengthLimitingTextInputFormatter(6),
                              ],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: 6,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'AB3K7Z',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 20,
                                  letterSpacing: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white38),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white38),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a room code';
                                }
                                if (value.length != 6) {
                                  return 'Room code must be 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : _joinRoom,
                              icon: _isJoining
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login,
                                      color: Colors.white),
                              label: Text(
                                _isJoining ? 'Joining...' : 'Join Room',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white38)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('SPECTATE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                        ),
                        Expanded(child: Divider(color: Colors.white38)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Watch a Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('Enter a room code to spectate', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                          const SizedBox(height: 16),
                          Form(
                            key: _spectateFormKey,
                            child: TextFormField(
                              controller: _spectateCodeController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                                LengthLimitingTextInputFormatter(6),
                              ],
                              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'AB3K7Z',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 20, letterSpacing: 6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white38)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white38)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white)),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Please enter a room code';
                                if (v.length != 6) return 'Room code must be 6 characters';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : _spectateRoom,
                              icon: _isSpectating
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.visibility, color: Colors.white),
                              label: Text(_isSpectating ? 'Joining...' : 'Watch Game', style: const TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ), // close Scaffold
    ); // close PopScope
  }
}
