import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Local accessory inspiration assets (Meghna's catalogue) for Complete the
/// Look / Visual Inspiration / Missing Pieces / Find This fallback.
///
/// These are INSPIRATION suggestions only — never owned wardrobe items.
/// Backend image_url always wins; this is the local fallback.
class StyleAssetService {
  StyleAssetService._();
  static final StyleAssetService instance = StyleAssetService._();

  static const _manifestPath = 'assets/style_assets/style_assets_manifest.json';
  List<Map<String, dynamic>>? _assets;

  Future<List<Map<String, dynamic>>> _load() async {
    if (_assets != null) return _assets!;
    try {
      final raw = await rootBundle.loadString(_manifestPath);
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['assets'] : decoded;
      _assets = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('AHVI_STYLE_ASSETS_LOAD_FAILED $e');
      _assets = <Map<String, dynamic>>[];
    }
    return _assets!;
  }

  bool _matchGender(Map<String, dynamic> a, String? gender) {
    if (gender == null || gender.isEmpty) return true;
    final g = (a['gender'] ?? 'unisex').toString().toLowerCase();
    if (g == 'unisex') return true;
    return g == gender.toLowerCase();
  }

  int _score(Map<String, dynamic> a, String? archetype, String? occasion) {
    int s = 0;
    final arch = (a['archetypes'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? const [];
    final occ = (a['occasions'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? const [];
    if (archetype != null && arch.contains(archetype.toLowerCase())) s += 3;
    if (occasion != null && occ.any((o) => occasion.toLowerCase().contains(o) || o.contains(occasion.toLowerCase()))) s += 2;
    return s;
  }

  /// Pick a few accessory assets that complete a look for the given
  /// archetype/occasion/gender. Falls back to a spread across categories.
  Future<List<Map<String, dynamic>>> getCompleteTheLookAssets({
    String? archetype,
    String? occasion,
    String? gender,
    int limit = 3,
  }) async {
    final all = await _load();
    if (all.isEmpty) return const [];
    final pool = all.where((a) => _matchGender(a, gender)).toList();
    final candidates = pool.isEmpty ? all : pool;
    candidates.sort((b, a) =>
        _score(a, archetype, occasion).compareTo(_score(b, archetype, occasion)));

    // Diversify by category so we don't return 3 earrings.
    final out = <Map<String, dynamic>>[];
    final seenCat = <String>{};
    for (final a in candidates) {
      final cat = (a['category'] ?? '').toString();
      if (seenCat.contains(cat)) continue;
      seenCat.add(cat);
      out.add(a);
      if (out.length >= limit) break;
    }
    // top up if categories were too few
    if (out.length < limit) {
      for (final a in candidates) {
        if (out.contains(a)) continue;
        out.add(a);
        if (out.length >= limit) break;
      }
    }
    debugPrint('AHVI_COMPLETE_THE_LOOK_ASSETS count=${out.length} archetype=$archetype occasion=$occasion');
    return out;
  }
}
