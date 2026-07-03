import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/avatar_service.dart';
import '../utils/theme_utils.dart';
import 'lobby_screen.dart';
import 'username_screen.dart';
import 'ai_game_screen.dart';
import 'leaderboard_screen.dart';
import 'donate_screen.dart';

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
