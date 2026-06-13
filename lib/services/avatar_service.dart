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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString('avatar') ?? '😀';
  }

  Future<void> setAvatar(String emoji) async {
    _selected = emoji;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar', emoji);
  }
}
