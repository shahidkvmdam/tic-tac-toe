import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImageScreen extends StatelessWidget {
  final String? imageUrl;
  final String? localImagePath;
  final String? emoji;
  final String? title;

  const FullScreenImageScreen({
    super.key,
    this.imageUrl,
    this.localImagePath,
    this.emoji,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl != null && imageUrl!.isNotEmpty) ||
        (localImagePath != null && localImagePath!.isNotEmpty && File(localImagePath!).existsSync());

    Widget imageWidget;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    } else if (localImagePath != null && localImagePath!.isNotEmpty && File(localImagePath!).existsSync()) {
      imageWidget = Image.file(
        File(localImagePath!),
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = _fallback(context);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: hasImage
          ? InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: imageWidget),
            )
          : Center(child: imageWidget),
    );
  }

  Widget _fallback(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          emoji?.isNotEmpty == true ? emoji! : '😀',
          style: const TextStyle(fontSize: 120),
        ),
        const SizedBox(height: 16),
        Text(
          'No image available',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

void showFullScreenImage(
  BuildContext context, {
  String? imageUrl,
  String? localImagePath,
  String? emoji,
  String? title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => FullScreenImageScreen(
        imageUrl: imageUrl,
        localImagePath: localImagePath,
        emoji: emoji,
        title: title,
      ),
    ),
  );
}
