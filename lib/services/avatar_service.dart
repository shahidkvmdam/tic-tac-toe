import 'package:shared_preferences/shared_preferences.dart';

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  static const List<String> avatars = [
    '😀','😎','🤩','🥳','🦊','🐼','🐯','🦁',
    '🐸','🐧','🦄','🐲','👾','🤖','👽','🎃',
    '🧙','🥷','🦸','🧛','🍕','🎮','🚀','⚡',
  ];

  String _selected = '😀';
  String get selected => _selected;

  String? _imagePath;
  String? get imagePath => _imagePath;
  bool get hasCustomImage => _imagePath != null && _imagePath!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString('avatar') ?? '😀';
    _imagePath = prefs.getString('avatar_image');
  }

  Future<void> setAvatar(String emoji) async {
    _selected = emoji;
    _imagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar', emoji);
    await prefs.remove('avatar_image');
  }

  Future<void> setCustomImage(String path) async {
    _imagePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_image', path);
  }
}
