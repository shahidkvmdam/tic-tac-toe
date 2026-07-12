import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../screens/full_screen_image_screen.dart';

class UserAvatar extends StatelessWidget {
  final String uid;
  final String? name;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final bool tapToFullScreen;

  const UserAvatar({
    super.key,
    required this.uid,
    this.name,
    this.size = 48,
    this.iconSize = 24,
    this.backgroundColor,
    this.tapToFullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: AvatarService.instance.avatarStream(uid),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final imageUrl = data['avatarUrl']?.toString();
        final avatarEmoji = data['avatarEmoji']?.toString() ?? '';
        final fallbackEmoji = data['avatar']?.toString() ?? '';
        final emoji = avatarEmoji.isNotEmpty
            ? avatarEmoji
            : (fallbackEmoji.isNotEmpty ? fallbackEmoji : '😀');

        return AvatarService.buildAvatar(
          imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
          emoji: emoji,
          size: size,
          iconSize: iconSize,
          backgroundColor: backgroundColor,
          onTap: tapToFullScreen
              ? () => showFullScreenImage(
                    context,
                    imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
                    emoji: emoji,
                    title: name,
                  )
              : null,
        );
      },
    );
  }
}
