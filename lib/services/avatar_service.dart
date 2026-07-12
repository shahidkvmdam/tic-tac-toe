import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  static const List<String> avatars = [
    // Faces
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃',
    '😉','😊','😇','🥰','😍','😘','😗','😚','😙',
    '😋','😛','😜','😝','🤑','🤗','🤭','🤫','🤔','🤐',
    '🤨','😐','😑','😶','😏','😒','🙄','😬','🤥','😌',
    '😔','😪','🤤','😴','😷','🤒','🤕','🤢','🤮','🤧',
    '🥵','🥶','🥴','😵','🤯','🤠','😎','🤓','🧐',
    '😕','😟','🥺','😳','🥲','😲','☹️','🙁','😖','😞',
    // Animals
    '🐶','🐱','🐭','🐹','🐰','🐻','🐨','🦁','🐮','🐷','🐽','🐸','🐵','🐔','🐧','🐦','🐤',
    '🦆','🦅','🦉','🦇','🐺','🐗','🦄','🐝','🐛',
    '🦋','🐌','🐞','🐜','🦟',
    // Sea creatures
    '🦠','🐙','🦑','🦀','🦞','🦐','🐟','🐬','🐳','🐋',
    // Large animals
    '🐅','🐆','🦓','🦍','🦧','🐘','🦛','🦏','🐪',
    '🐫','🦒','🦘','🐃','🐂',
    // Food
    '🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍈',
    '🍒','🍑','🍍','🥝','🥭','🍅','🍆','🥑','🌽','🥕',
    '🍔','🍟','🍕','🌭','🥪',
    '🌮','🌯','🥚','🍳','🥘','🍲','🥗','🍿','🧂','🥫',
    '🍱','🍘','🍙','🍚','🍜',
    // Sports & activities
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱',
    '🏓','🏸','🥅','🏒','🥊','🥋','⛸️','🎿','🛷','🥌',
    // Tech & misc
    '🎮','🕹️','🎰','🎲','🧩','🧸','🃏','🀄','🎴','🎭',
    '🖥️','💻','⌨️','🖱️','🚀',
  ];

  String _selected = '😀';
  String get selected => _selected;

  String? _imagePath;
  String? get imagePath => _imagePath;
  bool get hasCustomImage => _imagePath != null && _imagePath!.isNotEmpty;

  String? _imageUrl;
  String? get imageUrl => _imageUrl;

  String? _uid;
  bool _initialized = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _avatarKey()      => _uid != null ? 'avatar_$_uid'       : 'avatar';
  String _imageKey()       => _uid != null ? 'avatar_image_$_uid'  : 'avatar_image';
  String _imageUrlKey()    => _uid != null ? 'avatar_image_url_$_uid' : 'avatar_image_url';

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString(_avatarKey()) ?? '😀';
    _imagePath = prefs.getString(_imageKey());
    _imageUrl = prefs.getString(_imageUrlKey());
    _initialized = true;
  }

  Future<void> loadForUser(String uid) async {
    _uid = uid;
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString(_avatarKey()) ?? '😀';
    _imagePath = prefs.getString(_imageKey());
    _imageUrl = prefs.getString(_imageUrlKey());

    // Sync from Firestore to stay consistent across devices
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final firestoreEmoji = data['avatarEmoji'] as String?;
        final firestoreUrl = data['avatarUrl'] as String?;

        if (firestoreEmoji != null && firestoreEmoji.isNotEmpty) {
          _selected = firestoreEmoji;
          await prefs.setString(_avatarKey(), firestoreEmoji);
        }
        if (firestoreUrl != null && firestoreUrl.isNotEmpty) {
          _imageUrl = firestoreUrl;
          await prefs.setString(_imageUrlKey(), firestoreUrl);
        }
      }
    } catch (e) {
      debugPrint('AvatarService loadForUser error: $e');
    }

    _initialized = true;
  }

  Future<void> clearCurrentUser() async {
    _uid = null;
    _initialized = false;
    _selected = '😀';
    _imagePath = null;
    _imageUrl = null;
  }

  Future<void> setAvatar(String emoji) async {
    await _deleteCurrentStorageImage();

    _selected = emoji;
    _imagePath = null;
    _imageUrl = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey(), emoji);
    await prefs.remove(_imageKey());
    await prefs.remove(_imageUrlKey());

    // Sync to Firestore
    if (_uid != null) {
      try {
        await _firestore.collection('users').doc(_uid).set({
          'avatarEmoji': emoji,
          'avatarUrl': '',
          'avatar': emoji,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('AvatarService setAvatar error: $e');
      }
    }
  }

  Future<void> _deleteCurrentStorageImage() async {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      try {
        final ref = _storage.refFromURL(_imageUrl!);
        await ref.delete();
        debugPrint('AvatarService: deleted old image $_imageUrl');
      } catch (e) {
        debugPrint('AvatarService: failed to delete old image $_imageUrl: $e');
      }
    }
  }

  Future<String?> setCustomImage(String path) async {
    // Delete previous image before uploading the new one
    await _deleteCurrentStorageImage();

    _imagePath = path;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imageKey(), path);

    // Upload to Firebase Storage
    if (_uid == null) {
      final msg = 'AvatarService: cannot upload, uid is null';
      debugPrint(msg);
      return msg;
    }

    try {
      final file = File(path);
      final ref = _storage.ref().child('avatars/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      debugPrint('AvatarService: uploaded ${uploadTask.totalBytes} bytes to ${uploadTask.ref.fullPath}');

      // Retry getDownloadURL a few times in case of propagation delay
      String? downloadUrl;
      for (var attempt = 1; attempt <= 5; attempt++) {
        try {
          downloadUrl = await uploadTask.ref.getDownloadURL();
          break;
        } catch (e) {
          debugPrint('AvatarService: getDownloadURL attempt $attempt failed: $e');
          if (attempt == 5) rethrow;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (downloadUrl == null || downloadUrl.isEmpty) {
        return 'AvatarService: failed to get download URL after upload';
      }

      _imageUrl = downloadUrl;
      await prefs.setString(_imageUrlKey(), downloadUrl);
      debugPrint('AvatarService: downloadUrl = $downloadUrl');

      await _firestore.collection('users').doc(_uid).set({
        'avatarUrl': downloadUrl,
        'avatarEmoji': '',
        'avatar': '',
      }, SetOptions(merge: true));
      debugPrint('AvatarService: Firestore updated');
      return null;
    } catch (e) {
      final msg = 'AvatarService upload error: $e';
      debugPrint(msg);
      return msg;
    }
  }

  Future<String?> pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      return await setCustomImage(picked.path);
    }
    return 'No image selected';
  }

  // Real-time stream of a user's avatar data from Firestore
  Stream<Map<String, dynamic>> avatarStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>;
      return {
        'avatarUrl': data['avatarUrl'] ?? '',
        'avatarEmoji': data['avatarEmoji'] ?? '',
        'avatar': data['avatar'] ?? '',
      };
    });
  }

  static Widget buildAvatar({
    required String? imageUrl,
    required String emoji,
    String? localImagePath,
    double size = 48,
    double iconSize = 24,
    Color? backgroundColor,
    VoidCallback? onTap,
  }) {
    final bg = backgroundColor ?? const Color(0xFF6D28D9).withValues(alpha: 0.2);

    Widget avatar;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: bg,
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('AvatarService: failed to load network image $imageUrl: $exception');
        },
      );
    } else if (localImagePath != null && localImagePath.isNotEmpty && File(localImagePath).existsSync()) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: FileImage(File(localImagePath)),
        backgroundColor: Colors.transparent,
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: bg,
        child: Text(
          emoji.isNotEmpty ? emoji : '😀',
          style: TextStyle(fontSize: iconSize),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }
    return avatar;
  }

  Widget avatarWidget({double size = 48, double iconSize = 24}) {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(_imageUrl!),
        backgroundColor: Colors.transparent,
      );
    }
    if (hasCustomImage && _imagePath != null && _imagePath!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: FileImage(File(_imagePath!)),
        backgroundColor: Colors.transparent,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF6D28D9).withValues(alpha: 0.2),
      child: Text(
        _selected.isNotEmpty ? _selected : '😀',
        style: TextStyle(fontSize: iconSize),
      ),
    );
  }
}
