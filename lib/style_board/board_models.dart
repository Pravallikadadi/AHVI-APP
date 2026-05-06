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

@immutable
class StyleBoardData {
  final String title;
  final String? occasion;
  final String? whyItWorks;
  final List<StyleBoardItem> items;

  const StyleBoardData({
    required this.title,
    this.occasion,
    this.whyItWorks,
    required this.items,
  });
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

  const EditorialLayoutResult({
    required this.mode,
    required this.placements,
  });

  bool get isEmpty => placements.isEmpty;
}
