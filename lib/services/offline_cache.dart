import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appwrite/models.dart' as appwrite_models;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache extends ChangeNotifier {
  static const String _kImageDirName = 'ahvi_offline/images';
  static const int _maxParallelDownloads = 4;

  String? _userId;
  late SharedPreferences _prefs;
  Directory? _imageDir;

  List<Map<String, dynamic>> _wardrobe = const [];
  final Map<String, List<Map<String, dynamic>>> _savedBoardsByOccasion = {};
  // url -> file name (relative to image dir)
  Map<String, String> _imageMap = {};

  bool _initialized = false;

  bool get initialized => _initialized;
  List<Map<String, dynamic>> get wardrobe =>
      List<Map<String, dynamic>>.unmodifiable(_wardrobe);

  Future<void> init({required String? userId}) async {
    _userId = userId;
    _prefs = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    _imageDir = Directory('${docs.path}/$_kImageDirName');
    if (!await _imageDir!.exists()) {
      await _imageDir!.create(recursive: true);
    }
    _loadFromPrefs();
    _initialized = true;
    notifyListeners();
  }

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _loadFromPrefs();
    notifyListeners();
  }

  // Per-user prefs keys. We deliberately do NOT use an "anon" fallback —
  // anonymous reads/writes leak data across accounts on the same device.
  // Callers must ensure a userId is set; helpers below early-return when not.
  String? _wardrobeKey() =>
      _userId == null || _userId!.isEmpty ? null : 'offline:wardrobe:$_userId';
  String? _boardsKey(String occasion) =>
      _userId == null || _userId!.isEmpty
          ? null
          : 'offline:boards:$_userId:${occasion.toLowerCase()}';
  String? _imageMapKey() =>
      _userId == null || _userId!.isEmpty ? null : 'offline:images:$_userId';

  void _loadFromPrefs() {
    // Always reset in-memory state first so a user-switch never inherits the
    // previous user's data when there is no key for the new user yet.
    _wardrobe = const [];
    _savedBoardsByOccasion.clear();
    _imageMap = {};

    final wKey = _wardrobeKey();
    if (wKey != null) {
      final wRaw = _prefs.getString(wKey);
      if (wRaw != null) {
        try {
          final decoded = jsonDecode(wRaw);
          if (decoded is List) {
            _wardrobe = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } catch (_) {
          _wardrobe = const [];
        }
      }
    }

    final imgKey = _imageMapKey();
    if (imgKey != null) {
      final imgRaw = _prefs.getString(imgKey);
      if (imgRaw != null) {
        try {
          final decoded = jsonDecode(imgRaw);
          if (decoded is Map) {
            _imageMap =
                decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (_) {
          _imageMap = {};
        }
      }
    }
  }

  // ---------- WARDROBE ----------

  List<Map<String, dynamic>> getWardrobe() => wardrobe;

  Future<void> setWardrobe(List<Map<String, dynamic>> items) async {
    final key = _wardrobeKey();
    if (key == null) return; // refuse anonymous writes
    _wardrobe = List<Map<String, dynamic>>.from(items);
    await _prefs.setString(key, jsonEncode(_wardrobe));
    notifyListeners();
  }

  Future<void> removeWardrobeItem(
    String itemId, {
    bool deleteImages = true,
  }) async {
    final removed = <Map<String, dynamic>>[];
    final next = <Map<String, dynamic>>[];
    for (final item in _wardrobe) {
      final id = (item[r'$id'] ?? item['id'] ?? '').toString();
      if (id == itemId) {
        removed.add(item);
      } else {
        next.add(item);
      }
    }
    _wardrobe = next;
    final key = _wardrobeKey();
    if (key != null) {
      await _prefs.setString(key, jsonEncode(_wardrobe));
    }

    if (deleteImages) {
      for (final item in removed) {
        final urls = _itemImageUrls(item);
        for (final url in urls) {
          await _deleteLocalImage(url);
        }
      }
    }
    notifyListeners();
  }

  // ---------- SAVED BOARDS ----------

  List<Map<String, dynamic>> getSavedBoards(String occasion) {
    final key = occasion.toLowerCase();
    if (_savedBoardsByOccasion.containsKey(key)) {
      return List.unmodifiable(_savedBoardsByOccasion[key]!);
    }
    final prefsKey = _boardsKey(occasion);
    if (prefsKey == null) return const [];
    final raw = _prefs.getString(prefsKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _savedBoardsByOccasion[key] = list;
        return List.unmodifiable(list);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> setSavedBoardsFromDocs(
    String occasion,
    List<appwrite_models.Document> docs,
  ) async {
    final list = docs
        .map((d) => {
              r'$id': d.$id,
              'data': Map<String, dynamic>.from(d.data),
              r'$createdAt': d.$createdAt,
            })
        .toList();
    _savedBoardsByOccasion[occasion.toLowerCase()] = list;
    final key = _boardsKey(occasion);
    if (key != null) {
      await _prefs.setString(key, jsonEncode(list));
    }
    notifyListeners();
  }

  // Reconstruct shape compatible with appwrite_models.Document for callers
  // that read `.data` and `.$id`. Returns plain maps; callers updated to
  // accept either.
  List<Map<String, dynamic>> getSavedBoardsRaw(String occasion) =>
      getSavedBoards(occasion);

  // ---------- IMAGES ----------

  File? localImageFile(String url) {
    if (url.isEmpty) return null;
    final dir = _imageDir;
    if (dir == null) return null;
    final fileName = _imageMap[url];
    if (fileName == null) return null;
    final f = File('${dir.path}/$fileName');
    return f.existsSync() ? f : null;
  }

  Future<File?> downloadImage(String url) async {
    if (url.isEmpty) return null;
    final dir = _imageDir;
    if (dir == null) return null;
    final existing = localImageFile(url);
    if (existing != null) return existing;

    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      final fileName = '${_hashUrl(url)}.bin';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      _imageMap[url] = fileName;
      await _persistImageMap();
      return file;
    } catch (e) {
      debugPrint('OfflineCache.downloadImage($url) failed: $e');
      return null;
    }
  }

  Future<void> syncImages(Set<String> urls) async {
    final missing = urls.where((u) => u.isNotEmpty && localImageFile(u) == null).toList();
    if (missing.isEmpty) return;

    final pool = <Future<void>>[];
    final iter = missing.iterator;
    Future<void> worker() async {
      while (true) {
        String? next;
        if (iter.moveNext()) {
          next = iter.current;
        } else {
          return;
        }
        await downloadImage(next);
      }
    }

    for (var i = 0; i < _maxParallelDownloads; i++) {
      pool.add(worker());
    }
    await Future.wait(pool);
    notifyListeners();
  }

  Future<void> pruneOrphans(Set<String> keepUrls) async {
    final dir = _imageDir;
    if (dir == null) return;
    final keepFiles = <String>{};
    for (final url in keepUrls) {
      final f = _imageMap[url];
      if (f != null) keepFiles.add(f);
    }

    final removedUrls = <String>[];
    _imageMap.forEach((url, fileName) {
      if (!keepUrls.contains(url)) removedUrls.add(url);
    });
    for (final url in removedUrls) {
      await _deleteLocalImage(url);
    }

    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final base = entity.uri.pathSegments.last;
          if (!keepFiles.contains(base)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteLocalImage(String url) async {
    final fileName = _imageMap.remove(url);
    final dir = _imageDir;
    if (dir == null || fileName == null) {
      await _persistImageMap();
      return;
    }
    final file = File('${dir.path}/$fileName');
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await _persistImageMap();
  }

  Future<void> _persistImageMap() async {
    final key = _imageMapKey();
    if (key != null) {
      await _prefs.setString(key, jsonEncode(_imageMap));
    }
  }

  // ---------- HELPERS ----------

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    return sha1.convert(bytes).toString();
  }

  static List<String> _itemImageUrls(Map<String, dynamic> item) {
    final urls = <String>[];
    for (final key in const [
      'image_url',
      'imageUrl',
      'masked_url',
      'maskedUrl',
      'raw_url',
      'rawUrl',
    ]) {
      final v = item[key];
      if (v is String && v.trim().isNotEmpty) urls.add(v.trim());
    }
    return urls;
  }

  Set<String> collectAllUrls() {
    final urls = <String>{};
    for (final item in _wardrobe) {
      urls.addAll(_itemImageUrls(item));
    }
    for (final list in _savedBoardsByOccasion.values) {
      for (final board in list) {
        final data = board['data'];
        if (data is Map) {
          final imgUrl = data['imageUrl'];
          if (imgUrl is String && imgUrl.trim().isNotEmpty) urls.add(imgUrl.trim());
        }
      }
    }
    return urls;
  }

  // Bytes for export (used by board exporter when offline)
  Future<Uint8List?> readImageBytes(String url) async {
    final file = localImageFile(url);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
