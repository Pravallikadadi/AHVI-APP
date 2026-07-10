import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'app_localizations.dart'; // adjust path to wherever this actually lives

/// Holds the one-line summaries shown on the Home hero card.
///
/// Values are stored as translation KEYS until the backend supplies real
/// text, then stored verbatim from that point on. This class deliberately
/// holds no BuildContext (ChangeNotifiers shouldn't) — call the `*For`
/// getters with a BuildContext at render time to resolve the current key
/// through AppLocalizations. Because `AppLocalizations.translate()` returns
/// its input unchanged when the key isn't found, backend-provided literal
/// strings pass through safely too.
class HomeCardSummaryProvider extends ChangeNotifier {
  static const String _wearMaleKey = 'home_card_wear_male';
  static const String _wearFemaleKey = 'home_card_wear_female';
  static const String _wearDefaultKey = 'home_card_wear_default';
  static const String _moveDefaultKey = 'home_card_move_default';
  static const String _eatDefaultKey = 'home_card_eat_default';
  static const String _careDefaultKey = 'home_card_care_default';

  /// Gender-aware neutral fallback KEY for the "Wear" line. Never a specific
  /// gendered look (no "gold hoops") unless the backend supplies a real one.
  static String wearFallbackKeyFor(String? gender) {
    switch ((gender ?? '').trim().toLowerCase()) {
      case 'male':
      case 'm':
      case 'man':
      case 'men':
        return _wearMaleKey;
      case 'female':
      case 'f':
      case 'woman':
      case 'women':
        return _wearFemaleKey;
      default:
        return _wearDefaultKey;
    }
  }

  String _wear = _wearDefaultKey;
  String _move = _moveDefaultKey;
  String _eat = _eatDefaultKey;
  String _care = _careDefaultKey;

  // True once a real (backend/dynamic) wear summary has been set, so the
  // gender fallback never overrides genuine data.
  bool _wearFromBackend = false;

  /// Raw stored value — a translation key unless the backend has supplied
  /// real text. Prefer the `*For(context)` getters when rendering UI.
  String get wear => _wear;
  String get move => _move;
  String get eat => _eat;
  String get care => _care;

  /// Resolved display text for [context]'s current locale.
  String wearFor(BuildContext context) => context.tr(_wear);
  String moveFor(BuildContext context) => context.tr(_move);
  String eatFor(BuildContext context) => context.tr(_eat);
  String careFor(BuildContext context) => context.tr(_care);

  /// Apply the gender-aware fallback ONLY while no real summary has arrived.
  void applyGenderFallback(String? gender) {
    if (_wearFromBackend) return;
    final next = wearFallbackKeyFor(gender);
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
    _wear = _wearDefaultKey;
    _wearFromBackend = false;
    _move = _moveDefaultKey;
    _eat = _eatDefaultKey;
    _care = _careDefaultKey;
    notifyListeners();
  }
}