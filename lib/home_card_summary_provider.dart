import 'package:flutter/foundation.dart';

/// Holds the one-line summaries shown on the Home hero card.
class HomeCardSummaryProvider extends ChangeNotifier {
  /// Gender-aware neutral fallback for the "Wear" line. Never a specific
  /// gendered look (no "gold hoops") unless the backend supplies a real one.
  static String wearFallbackFor(String? gender) {
    switch ((gender ?? '').trim().toLowerCase()) {
      case 'male':
      case 'm':
      case 'man':
      case 'men':
        return 'Structured shirt, tailored trousers, clean footwear, and a watch.';
      case 'female':
      case 'f':
      case 'woman':
      case 'women':
        return 'Soft top or dress, comfortable footwear, and one simple accessory.';
      default:
        return 'Comfortable layers, clean footwear, and one simple finishing detail.';
    }
  }

  String _wear = wearFallbackFor(null);
  String _move = '7-min stretch';
  String _eat = 'Light, protein-focused';
  String _care = 'Quick glow routine';

  // True once a real (backend/dynamic) wear summary has been set, so the
  // gender fallback never overrides genuine data.
  bool _wearFromBackend = false;

  String get wear => _wear;
  String get move => _move;
  String get eat => _eat;
  String get care => _care;

  /// Apply the gender-aware fallback ONLY while no real summary has arrived.
  void applyGenderFallback(String? gender) {
    if (_wearFromBackend) return;
    final next = wearFallbackFor(gender);
    if (next == _wear) return;
    _wear = next;
    notifyListeners();
  }

  bool _setIfUseful(
    String current,
    String value,
    void Function(String) assign,
  ) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned == current) return false;
    assign(cleaned);
    notifyListeners();
    return true;
  }

  void setWear(String value) {
    final changed = _setIfUseful(_wear, value, (cleaned) => _wear = cleaned);
    if (changed || value.trim().isNotEmpty) _wearFromBackend = true;
  }

  void setMove(String value) {
    _setIfUseful(_move, value, (cleaned) => _move = cleaned);
  }

  void setEat(String value) {
    _setIfUseful(_eat, value, (cleaned) => _eat = cleaned);
  }

  void setCare(String value) {
    _setIfUseful(_care, value, (cleaned) => _care = cleaned);
  }

  void reset() {
    _wear = wearFallbackFor(null);
    _wearFromBackend = false;
    _move = '7-min stretch';
    _eat = 'Light, protein-focused';
    _care = 'Quick glow routine';
    notifyListeners();
  }
}
