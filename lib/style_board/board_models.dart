import 'package:flutter/foundation.dart';

enum BoardItemRole {
  top,
  bottom,
  footwear,
  outerwear,
  dress,
  accessory,
  unknown,
}

@immutable
class StyleBoardItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final BoardItemRole role;
  final Map<String, dynamic> raw;

  const StyleBoardItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.role,
    this.raw = const <String, dynamic>{},
  });
}

/// Premium board story object emitted by the backend `board_storyteller`.
///
/// Every field is nullable so the UI can degrade gracefully when the backend
/// does not yet supply story data.
@immutable
class BoardStory {
  final String? headline;
  final String? summary;
  final String? why;
  final String? personalNote;
  final String? occasionFit;
  final String? tip;
  final String? role;

  const BoardStory({
    this.headline,
    this.summary,
    this.why,
    this.personalNote,
    this.occasionFit,
    this.tip,
    this.role,
  });

  factory BoardStory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BoardStory();
    String? read(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return BoardStory(
      headline: read('headline'),
      summary: read('summary'),
      why: read('why'),
      personalNote: read('personal_note'),
      occasionFit: read('occasion_fit'),
      tip: read('tip'),
      role: read('role'),
    );
  }

  bool get isEmpty =>
      (headline == null || headline!.isEmpty) &&
      (summary == null || summary!.isEmpty) &&
      (why == null || why!.isEmpty) &&
      (personalNote == null || personalNote!.isEmpty) &&
      (occasionFit == null || occasionFit!.isEmpty) &&
      (tip == null || tip!.isEmpty) &&
      (role == null || role!.isEmpty);

  bool get hasExpandableContent =>
      (why != null && why!.isNotEmpty) ||
      (personalNote != null && personalNote!.isNotEmpty) ||
      (occasionFit != null && occasionFit!.isNotEmpty) ||
      (tip != null && tip!.isNotEmpty);
}

@immutable
class StyleBoardData {
  final String title;
  final String? occasion;
  final String? whyItWorks;
  final List<StyleBoardItem> items;
  final BoardStory? story;
  final String? stylingTip;

  const StyleBoardData({
    required this.title,
    this.occasion,
    this.whyItWorks,
    required this.items,
    this.story,
    this.stylingTip,
  });

  /// Preferred short copy for collapsed cards.
  String? get summaryText =>
      story?.summary ?? whyItWorks ?? (occasion?.isNotEmpty == true ? occasion : null);

  /// Preferred long copy for expanded "why this works".
  String? get whyText => story?.why ?? whyItWorks;

  /// Preferred copy for styling tip rows.
  String? get tipText => story?.tip ?? stylingTip;

  /// Preferred role badge (e.g. "Safest polished option").
  String? get roleLabel => story?.role ?? occasion;
}

/// Existing/legacy section layout modes. Keep while older board renderers migrate.
enum BoardLayoutMode {
  dress,
  outerwearLayered,
  tripletClassic,
  pairWithFoot,
  accessoryHeavy,
  singleItem,
  empty,
}

@immutable
class BoardLayoutResult {
  final BoardLayoutMode mode;
  final StyleBoardItem? hero;
  final StyleBoardItem? outerwear;
  final StyleBoardItem? top;
  final StyleBoardItem? bottom;
  final StyleBoardItem? footwear;
  final List<StyleBoardItem> accessories;
  final double accessorySectionHeight;
  final int accessoryColumns;

  const BoardLayoutResult({
    required this.mode,
    required this.hero,
    required this.outerwear,
    required this.top,
    required this.bottom,
    required this.footwear,
    required this.accessories,
    required this.accessorySectionHeight,
    required this.accessoryColumns,
  });
}

/// New editorial/freeform layout modes for Pinterest-style flat-lay boards.
enum EditorialLayoutMode {
  classicThreePlusAccessory,
  dressFocused,
  outerwearLayered,
  accessoryHeavy,
  generic,
  empty,
}

@immutable
class BoardItemPlacement {
  final StyleBoardItem item;

  /// Absolute pixel values computed by LayoutBuilder.
  final double x;
  final double y;
  final double width;
  final double height;

  /// Rotation in radians. Keep small values like -0.04 or 0.05.
  final double rotation;

  /// Higher zIndex appears above lower zIndex.
  final int zIndex;

  const BoardItemPlacement({
    required this.item,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.zIndex = 0,
  });

  BoardItemPlacement copyWith({
    StyleBoardItem? item,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
  }) {
    return BoardItemPlacement(
      item: item ?? this.item,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

@immutable
class EditorialLayoutResult {
  final EditorialLayoutMode mode;
  final List<BoardItemPlacement> placements;

  const EditorialLayoutResult({required this.mode, required this.placements});

  bool get isEmpty => placements.isEmpty;
}
