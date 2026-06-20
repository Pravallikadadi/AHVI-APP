import 'package:flutter/foundation.dart';

/// Holds the one-line summaries shown on the Home hero card.
class HomeCardSummaryProvider extends ChangeNotifier {
  String _wear = 'White shirt + denims + gold hoops';
  String _move = '7-min stretch';
  String _eat = 'Light, protein-focused';
  String _care = 'Quick glow routine';

  String get wear => _wear;
  String get move => _move;
  String get eat => _eat;
  String get care => _care;

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
    _setIfUseful(_wear, value, (cleaned) => _wear = cleaned);
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
    _wear = 'White shirt + denims + gold hoops';
    _move = '7-min stretch';
    _eat = 'Light, protein-focused';
    _care = 'Quick glow routine';
    notifyListeners();
  }
}
