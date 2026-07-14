import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  // ✅ instance-level — static ఉంటే race condition వస్తుంది
  Map<String, String> _localizedStrings = {};

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  Future<bool> load() async {
    final jsonString = await rootBundle.loadString(
      'assets/lang/${locale.languageCode}.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map(
          (key, value) => MapEntry(key, value.toString()),
    );
    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // Short helper — use anywhere: AppLocalizations.t(context, 'key')
  static String t(BuildContext context, String key) {
    return AppLocalizations.of(context)?.translate(key) ?? key;
  }

  // ============================================================
  // Clothing slot labels
  // ============================================================
  String get clothingSlotTop => translate('clothingSlotTop');
  String get clothingSlotBottom => translate('clothingSlotBottom');
  String get clothingSlotDress => translate('clothingSlotDress');
  String get clothingSlotOuterwear => translate('clothingSlotOuterwear');
  String get clothingSlotFootwear => translate('clothingSlotFootwear');
  String get clothingSlotBag => translate('clothingSlotBag');
  String get clothingSlotAccessory => translate('clothingSlotAccessory');
  String get clothingSlotOther => translate('clothingSlotOther');

  // ============================================================
  // Build Outfit screen
  // ============================================================
  String get buildOutfitTitle => translate('buildOutfitTitle');
  String get buildOutfitNameHint => translate('buildOutfitNameHint');
  String get buildOutfitFilterAll => translate('buildOutfitFilterAll');
  String get buildOutfitCancel => translate('buildOutfitCancel');
  String get buildOutfitSaveOutfit => translate('buildOutfitSaveOutfit');
  String get buildOutfitSelectAtLeastOneItem =>
      translate('buildOutfitSelectAtLeastOneItem');
  String get buildOutfitNoItemsAvailable =>
      translate('buildOutfitNoItemsAvailable');

  // "buildOutfitSelectedItems" in the JSON is a plain label (e.g. "Selected
  // items", no {count} placeholder) — prefix the count onto it.
  String buildOutfitSelectedItems(int count) {
    return '$count ${translate('buildOutfitSelectedItems')}';
  }
}

// Extension so you can write: context.tr('key')
extension AppLocalizationsContext on BuildContext {
  String tr(String key) => AppLocalizations.t(this, key);
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      // ✅ 8 languages support
  [
    'en',
    'hi',
    'te',
    'ta',
    'kn',
    'ml',
    'bn',
    'mr',
  ].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}