import 'board_models.dart';

class BoardLayoutEngine {
  static BoardItemRole resolveRole(String category, {String? name}) {
    final c = '${category.toLowerCase()} ${(name ?? '').toLowerCase()}';

    if (RegExp(r'\b(dress|gown|saree|sari|lehenga|jumpsuit)\b').hasMatch(c)) {
      return BoardItemRole.dress;
    }
    if (RegExp(
      r'\b(jacket|blazer|coat|outerwear|overcoat|trench)\b',
    ).hasMatch(c)) {
      return BoardItemRole.outerwear;
    }
    if (RegExp(
      r'\b(shoe|shoes|boot|boots|loafer|sneaker|sandal|slider|heel|pump|flat|footwear)\b',
    ).hasMatch(c)) {
      return BoardItemRole.footwear;
    }
    if (RegExp(
      r'\b(watch|belt|cap|hat|bag|purse|clutch|tote|backpack|eyewear|sunglass|glasses|jewel|ring|necklace|bracelet|earring|scarf)\b',
    ).hasMatch(c)) {
      return BoardItemRole.accessory;
    }
    if (RegExp(
      r'\b(jeans|pant|pants|trouser|trousers|shorts|skirt|chino|chinos|cargo|jogger|palazzo|bottom|bottoms)\b',
    ).hasMatch(c)) {
      return BoardItemRole.bottom;
    }
    if (RegExp(
      r'\b(shirt|tshirt|t-shirt|tee|top|tops|blouse|polo|hoodie|sweater|cardigan|kurta|kurti|tunic|tank|cami)\b',
    ).hasMatch(c)) {
      return BoardItemRole.top;
    }
    return BoardItemRole.unknown;
  }

  static BoardLayoutResult resolve(StyleBoardData board) {
    StyleBoardItem? dress;
    StyleBoardItem? outerwear;
    StyleBoardItem? top;
    StyleBoardItem? bottom;
    StyleBoardItem? footwear;
    final accessories = <StyleBoardItem>[];

    for (final item in board.items) {
      switch (item.role) {
        case BoardItemRole.dress:
          dress ??= item;
          break;
        case BoardItemRole.outerwear:
          outerwear ??= item;
          break;
        case BoardItemRole.top:
          top ??= item;
          break;
        case BoardItemRole.bottom:
          bottom ??= item;
          break;
        case BoardItemRole.footwear:
          footwear ??= item;
          break;
        case BoardItemRole.accessory:
          accessories.add(item);
          break;
        case BoardItemRole.unknown:
          break;
      }
    }

    final mainCount =
        (top != null ? 1 : 0) +
        (bottom != null ? 1 : 0) +
        (outerwear != null ? 1 : 0);

    BoardLayoutMode mode;
    StyleBoardItem? hero;

    if (dress != null) {
      mode = BoardLayoutMode.dress;
      hero = dress;
    } else if (accessories.length >= 5 && mainCount <= 2) {
      mode = BoardLayoutMode.accessoryHeavy;
    } else if (outerwear != null && top != null && bottom != null) {
      mode = BoardLayoutMode.outerwearLayered;
    } else if (top != null && bottom != null) {
      mode = BoardLayoutMode.tripletClassic;
    } else if ((top != null || bottom != null || outerwear != null) &&
        footwear != null) {
      mode = BoardLayoutMode.pairWithFoot;
    } else if (top == null &&
        bottom == null &&
        outerwear == null &&
        footwear == null &&
        accessories.isEmpty) {
      mode = BoardLayoutMode.empty;
    } else {
      mode = BoardLayoutMode.singleItem;
    }

    final accessoryCount = accessories.length;
    final double accessorySectionHeight;
    final int accessoryColumns;

    if (mode == BoardLayoutMode.accessoryHeavy) {
      accessoryColumns = 4;
      final rows = (accessoryCount / 4).ceil().clamp(2, 3);
      accessorySectionHeight = rows * 88.0 + (rows - 1) * 8.0;
    } else if (accessoryCount == 0) {
      accessorySectionHeight = 0;
      accessoryColumns = 0;
    } else if (accessoryCount <= 2) {
      accessorySectionHeight = 92;
      accessoryColumns = accessoryCount;
    } else if (accessoryCount <= 4) {
      accessorySectionHeight = 96;
      accessoryColumns = 4;
    } else {
      accessorySectionHeight = 188;
      accessoryColumns = 4;
    }

    return BoardLayoutResult(
      mode: mode,
      hero: hero,
      outerwear: outerwear,
      top: top,
      bottom: bottom,
      footwear: footwear,
      accessories: accessories,
      accessorySectionHeight: accessorySectionHeight,
      accessoryColumns: accessoryColumns,
    );
  }
}
