import 'dart:math' as math;

import 'board_models.dart';

class EditorialBoardLayoutEngine {
  static EditorialLayoutResult resolve(
    StyleBoardData board, {
    required double width,
    required double height,
  }) {
    final top = _firstOf(board.items, BoardItemRole.top);
    final bottom = _firstOf(board.items, BoardItemRole.bottom);
    final footwear = _firstOf(board.items, BoardItemRole.footwear);
    final dress = _firstOf(board.items, BoardItemRole.dress);
    final outerwear = _firstOf(board.items, BoardItemRole.outerwear);
    final accessories = board.items
        .where((e) => e.role == BoardItemRole.accessory)
        .toList(growable: false);

    if (board.items.isEmpty) {
      return const EditorialLayoutResult(
        mode: EditorialLayoutMode.empty,
        placements: <BoardItemPlacement>[],
      );
    }

    final EditorialLayoutResult raw;
    if (dress != null) {
      raw = _dressFocused(
        dress: dress,
        footwear: footwear,
        outerwear: outerwear,
        accessories: accessories,
        width: width,
        height: height,
      );
    } else if (top != null && bottom != null && footwear != null) {
      if (accessories.length <= 2) {
        raw = _classicThreePlusAccessory(
          top: top,
          bottom: bottom,
          footwear: footwear,
          outerwear: outerwear,
          accessories: accessories,
          width: width,
          height: height,
        );
      } else {
        raw = _accessoryHeavy(
          mainItems: <StyleBoardItem>[
            ?outerwear,
            top,
            bottom,
            footwear,
          ],
          accessories: accessories,
          width: width,
          height: height,
        );
      }
    } else {
      raw = _generic(items: board.items, width: width, height: height);
    }

    // Enforce safe zones: 5% top, 6% sides, 10% bottom.
    // Prevents footwear/hems from touching the action row or canvas edge.
    final safePlacements = _applySafeZone(raw.placements, width, height);
    return EditorialLayoutResult(mode: raw.mode, placements: safePlacements);
  }

  static StyleBoardItem? _firstOf(
    List<StyleBoardItem> items,
    BoardItemRole role,
  ) {
    for (final item in items) {
      if (item.role == role) return item;
    }
    return null;
  }

  static EditorialLayoutResult _classicThreePlusAccessory({
    required StyleBoardItem top,
    required StyleBoardItem bottom,
    required StyleBoardItem footwear,
    required StyleBoardItem? outerwear,
    required List<StyleBoardItem> accessories,
    required double width,
    required double height,
  }) {
    final hasOuter = outerwear != null;
    final placements = <BoardItemPlacement>[];

    if (hasOuter) {
      // Outfit-first flat-lay: jacket+shirt column left/center, jeans below,
      // footwear lower-left. AR-derived from canvas fractions (Meghna ratios as
      // guidance only — never force absolute sizes that exceed the canvas).
      final outerW = width * 0.60;
      final outerH = outerW * (460.0 / 340.0); // AR 340:460
      placements.add(
        BoardItemPlacement(
          item: outerwear,
          x: width * 0.08,
          y: height * 0.00,
          width: outerW,
          height: outerH,
          rotation: -0.03,
          zIndex: 0,
        ),
      );
      final layerTopW = width * 0.44;
      final layerTopH = layerTopW * (330.0 / 250.0); // AR 250:330
      placements.add(
        BoardItemPlacement(
          item: top,
          x: width * 0.18,
          y: height * 0.09,
          width: layerTopW,
          height: layerTopH,
          rotation: -0.015,
          zIndex: 2,
        ),
      );
      final botW = width * 0.37;
      final botY = height * 0.48;
      // Cap jeans height so hem never exceeds safe-bottom zone.
      final botH = (botW * (650.0 / 250.0)).clamp(0.0, height * 0.90 - botY);
      placements.add(
        BoardItemPlacement(
          item: bottom,
          x: width * 0.42,
          y: botY,
          width: botW,
          height: botH,
          rotation: 0.01,
          zIndex: 1,
        ),
      );
    } else {
      // Editorial flat-lay, no outerwear: hero shirt upper-centre, jeans pulled
      // UP and to the centre-right so it overlaps the shirt's hem (kills the
      // dead vertical gap), shoes anchor lower-left. Aspect-derived heights so
      // garments are not distorted.
      final topW = width * 0.58;
      final botW = width * 0.44;
      placements.add(
        BoardItemPlacement(
          item: top,
          x: width * 0.18,
          y: height * 0.20,
          width: topW,
          height: topW * 1.28,
          rotation: -0.02,
          zIndex: 2,
        ),
      );
      placements.add(
        BoardItemPlacement(
          item: bottom,
          x: width * 0.45,
          y: height * 0.53,
          width: botW,
          height: botW * 1.55,
          rotation: 0.01,
          zIndex: 2,
        ),
      );
    }

    final footW = width * 0.40;
    placements.add(
      BoardItemPlacement(
        item: footwear,
        x: width * 0.16,
        y: height * 0.69,
        width: footW,
        height: footW * 0.62,
        rotation: -0.03,
        zIndex: 3,
      ),
    );

    for (var i = 0; i < math.min(accessories.length, 2); i++) {
      // i==0 = small jewelry/accessory mid-right; i==1 = bag/extra upper-right,
      // a touch larger but never dominant. Both kept close to the outfit.
      final accW = width * (i == 0 ? 0.16 : 0.20);
      placements.add(
        BoardItemPlacement(
          item: accessories[i],
          x: width * (i == 0 ? 0.68 : 0.67),
          y: height * (i == 0 ? 0.38 : 0.20),
          width: accW,
          height: accW,
          rotation: i == 0 ? 0.06 : -0.04,
          zIndex: i == 0 ? 4 : 3,
        ),
      );
    }

    return EditorialLayoutResult(
      mode: EditorialLayoutMode.classicThreePlusAccessory,
      placements: _sorted(placements),
    );
  }

  static EditorialLayoutResult _dressFocused({
    required StyleBoardItem dress,
    required StyleBoardItem? footwear,
    required StyleBoardItem? outerwear,
    required List<StyleBoardItem> accessories,
    required double width,
    required double height,
  }) {
    final placements = <BoardItemPlacement>[
      BoardItemPlacement(
        item: dress,
        x: width * 0.18,
        y: height * 0.04,
        width: width * 0.60,
        height: height * 0.70,
        rotation: 0.01,
        zIndex: 2,
      ),
    ];

    if (outerwear != null) {
      placements.add(
        BoardItemPlacement(
          item: outerwear,
          x: width * 0.02,
          y: height * 0.10,
          width: width * 0.36,
          height: height * 0.48,
          rotation: -0.04,
          zIndex: 1,
        ),
      );
    }

    if (footwear != null) {
      placements.add(
        BoardItemPlacement(
          item: footwear,
          x: width * 0.06,
          y: height * 0.68,
          width: width * 0.42,
          height: height * 0.25,
          rotation: -0.02,
          zIndex: 3,
        ),
      );
    }

    for (var i = 0; i < math.min(accessories.length, 3); i++) {
      placements.add(
        BoardItemPlacement(
          item: accessories[i],
          x: width * (0.68 - (i % 2) * 0.16),
          y: height * (0.68 + (i ~/ 2) * 0.14),
          width: width * 0.20,
          height: height * 0.16,
          rotation: i.isEven ? 0.05 : -0.04,
          zIndex: 4,
        ),
      );
    }

    return EditorialLayoutResult(
      mode: EditorialLayoutMode.dressFocused,
      placements: _sorted(placements),
    );
  }

  static EditorialLayoutResult _accessoryHeavy({
    required List<StyleBoardItem> mainItems,
    required List<StyleBoardItem> accessories,
    required double width,
    required double height,
  }) {
    final placements = <BoardItemPlacement>[];
    final mainTemplates = <_Template>[
      const _Template(0.03, 0.10, 0.38, 0.36, -0.03, 2),
      const _Template(0.44, 0.05, 0.48, 0.58, 0.02, 1),
      const _Template(0.05, 0.56, 0.46, 0.26, -0.02, 3),
      const _Template(0.54, 0.48, 0.34, 0.30, 0.03, 2),
    ];

    for (var i = 0; i < math.min(mainItems.length, mainTemplates.length); i++) {
      placements.add(mainTemplates[i].place(mainItems[i], width, height));
    }

    final accessoryTemplates = <_Template>[
      const _Template(0.58, 0.68, 0.18, 0.14, 0.05, 5),
      const _Template(0.77, 0.68, 0.18, 0.14, -0.04, 5),
      const _Template(0.58, 0.82, 0.18, 0.14, -0.02, 5),
      const _Template(0.77, 0.82, 0.18, 0.14, 0.03, 5),
    ];

    for (
      var i = 0;
      i < math.min(accessories.length, accessoryTemplates.length);
      i++
    ) {
      placements.add(
        accessoryTemplates[i].place(accessories[i], width, height),
      );
    }

    return EditorialLayoutResult(
      mode: EditorialLayoutMode.accessoryHeavy,
      placements: _sorted(placements),
    );
  }

  static EditorialLayoutResult _generic({
    required List<StyleBoardItem> items,
    required double width,
    required double height,
  }) {
    final templates = <_Template>[
      const _Template(0.05, 0.08, 0.42, 0.38, -0.03, 1),
      const _Template(0.48, 0.08, 0.42, 0.45, 0.02, 1),
      const _Template(0.10, 0.53, 0.46, 0.30, -0.02, 2),
      const _Template(0.58, 0.55, 0.28, 0.24, 0.04, 3),
      const _Template(0.63, 0.78, 0.22, 0.16, -0.03, 3),
    ];

    final placements = <BoardItemPlacement>[];
    for (var i = 0; i < math.min(items.length, templates.length); i++) {
      placements.add(templates[i].place(items[i], width, height));
    }

    return EditorialLayoutResult(
      mode: EditorialLayoutMode.generic,
      placements: _sorted(placements),
    );
  }

  static List<BoardItemPlacement> _sorted(List<BoardItemPlacement> placements) {
    return <BoardItemPlacement>[...placements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  /// Enforce safe zones on every placement:
  ///   top  5%, sides 6%, bottom 10%.
  /// Shoes and hems that exceed the safe-bottom boundary are moved UP.
  /// Items that exceed top/side margins are clamped to the margin edge.
  /// Width/height are never shrunk unless the item is already too tall to fit.
  static List<BoardItemPlacement> _applySafeZone(
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) {
    final safeBottomY = height * 0.90;
    final safeTopY = height * 0.05;
    final safeLeftX = width * 0.06;
    final safeRightX = width * 0.94;
    return placements.map((p) {
      double y = p.y;
      double x = p.x;
      // Push up if item bottom overflows the safe zone.
      if (y + p.height > safeBottomY) {
        y = safeBottomY - p.height;
      }
      // Don't go above top margin.
      if (y < safeTopY) y = safeTopY;
      // Clamp x to side margins.
      if (x < safeLeftX) x = safeLeftX;
      if (x + p.width > safeRightX) x = safeRightX - p.width;
      if (x == p.x && y == p.y) return p;
      return p.copyWith(x: x, y: y);
    }).toList();
  }
}

class _Template {
  final double x;
  final double y;
  final double w;
  final double h;
  final double rotation;
  final int z;

  const _Template(this.x, this.y, this.w, this.h, this.rotation, this.z);

  BoardItemPlacement place(StyleBoardItem item, double width, double height) {
    return BoardItemPlacement(
      item: item,
      x: width * x,
      y: height * y,
      width: width * w,
      height: height * h,
      rotation: rotation,
      zIndex: z,
    );
  }
}
