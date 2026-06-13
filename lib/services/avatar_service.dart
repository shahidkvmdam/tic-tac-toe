import 'package:shared_preferences/shared_preferences.dart';

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  static const List<String> avatars = [
    // Faces
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃',
    '😉','😊','😇','🥰','😍','','😘','😗','😚','😙',
    '😋','😛','😜','😝','🤑','🤗','🤭','🤫','🤔','🤐',
    '🤨','😐','😑','😶','😏','😒','🙄','😬','🤥','😌',
    '😔','😪','🤤','😴','😷','🤒','🤕','🤢','🤮','🤧',
    '🥵','🥶','🥴','😵','🤯','🤠','','😎','🤓','🧐',
    '😕','😟','🥺','😳','🥲','😲','☹️','🙁','😖','😞',
    // Animals
    '🐶','🐱','🐭','🐹','🐰','','🐻','','🐨','',
    '🦁','🐮','🐷','🐽','🐸','🐵','🐔','🐧','🐦','🐤',
    '🦆','🦅','🦉','🦇','🐺','🐗','🦄','🐝','🐛',
    '🦋','🐌','🐞','🐜','🦟',
    // Sea creatures
    '🦠','🐙','🦑','🦀','🦞','🦐','🐟','🐬','🐳','🐋',
    // Large animals
    '🦁','🐅','🐆','🦓','🦍','🦧','🐘','🦛','🦏','🐪',
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
    '�','🕹️','🎰','🎲','🧩','🧸','🃏','🀄','🎴','🎭',
    '🖥️','💻','⌨️','🖱️','🚀',
  ];

  String _selected = '😀';
  String get selected => _selected;

  String? _imagePath;
  String? get imagePath => _imagePath;
  bool get hasCustomImage => _imagePath != null && _imagePath!.isNotEmpty;

  String? _uid;

  String _avatarKey()      => _uid != null ? 'avatar_$_uid'       : 'avatar';
  String _imageKey()       => _uid != null ? 'avatar_image_$_uid'  : 'avatar_image';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString(_avatarKey()) ?? '😀';
    _imagePath = prefs.getString(_imageKey());
  }

  Future<void> loadForUser(String uid) async {
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString(_avatarKey()) ?? '😀';
    _imagePath = prefs.getString(_imageKey());
  }

  Future<void> clearCurrentUser() async {
    _uid = null;
    _selected = '😀';
    _imagePath = null;
  }

  Future<void> setAvatar(String emoji) async {
    _selected = emoji;
    _imagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey(), emoji);
    await prefs.remove(_imageKey());
  }

  Future<void> setCustomImage(String path) async {
    _imagePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imageKey(), path);
  }
}
