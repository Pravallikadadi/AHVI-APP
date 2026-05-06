import 'board_models.dart';

String normalizeBoardCategory(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

BoardItemRole resolveBoardRole(String category) {
  final c = normalizeBoardCategory(category);

  if (c.contains('shirt') ||
      c.contains('t shirt') ||
      c.contains('tee') ||
      c.contains('top') ||
      c.contains('polo') ||
      c.contains('blouse') ||
      c.contains('kurta') ||
      c.contains('hoodie')) {
    return BoardItemRole.top;
  }

  if (c.contains('jeans') ||
      c.contains('pant') ||
      c.contains('trouser') ||
      c.contains('shorts') ||
      c.contains('skirt') ||
      c.contains('chino') ||
      c.contains('jogger') ||
      c.contains('bottom')) {
    return BoardItemRole.bottom;
  }

  if (c.contains('shoe') ||
      c.contains('boot') ||
      c.contains('loafer') ||
      c.contains('sneaker') ||
      c.contains('slider') ||
      c.contains('slipper') ||
      c.contains('sandal') ||
      c.contains('heel') ||
      c.contains('footwear')) {
    return BoardItemRole.footwear;
  }

  if (c.contains('watch') ||
      c.contains('belt') ||
      c.contains('cap') ||
      c.contains('hat') ||
      c.contains('bag') ||
      c.contains('eyewear') ||
      c.contains('glass') ||
      c.contains('jewelry') ||
      c.contains('jewellery') ||
      c.contains('chain') ||
      c.contains('bracelet') ||
      c.contains('ring')) {
    return BoardItemRole.accessory;
  }

  if (c.contains('jacket') ||
      c.contains('blazer') ||
      c.contains('coat') ||
      c.contains('overshirt') ||
      c.contains('outerwear')) {
    return BoardItemRole.outerwear;
  }

  if (c.contains('dress') ||
      c.contains('gown') ||
      c.contains('saree') ||
      c.contains('lehenga') ||
      c.contains('one piece') ||
      c.contains('onepiece')) {
    return BoardItemRole.dress;
  }

  return BoardItemRole.unknown;
}
