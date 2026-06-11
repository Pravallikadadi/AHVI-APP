/// Frontend safety net mirroring the backend fashion sanitizer.
///
/// The backend is the source of truth, but payloads from older backend
/// revisions (or cached responses) may still carry non-fashion wardrobe
/// rows. Every stylist-facing render path filters through here so a
/// charger can never appear inside ownership chips, missing pieces or
/// generic item lists regardless of payload age.
library;

const _blockedCategories = <String>{
  'electronics',
  'electronic',
  'gadget',
  'gadgets',
  'charger',
  'misc',
  'unknown',
  'travel_accessory',
  'travel-accessory',
  'grooming',
  'skincare',
  'toiletries',
  'stationery',
  'medicine',
  'supplement',
  'food',
  'drink',
};

const _blockedNameTokens = <String>[
  'charger',
  'charging',
  'cable',
  'power bank',
  'powerbank',
  'adapter',
  'headphone',
  'earphone',
  'earbud',
  'airpod',
  'speaker',
  'moisturizer',
  'moisturiser',
  'skincare',
  'serum',
  'sunscreen',
  'cleanser',
  'face wash',
  'razor',
  'shaver',
  'trimmer',
  'toothbrush',
  'toothpaste',
  'deodorant',
  'shampoo',
  'conditioner',
  'lotion',
  'bottle',
  'tumbler',
  'flask',
  'neck pillow',
  'travel pillow',
  'eye mask',
  'eyemask',
  'ear plug',
  'earplug',
  'first aid',
  'medicine',
  'supplement',
  'vitamin',
  'notebook',
  'diary',
  'pencil',
  'umbrella',
  'sanitizer',
];

// Tokens too short / collision-prone for substring matching — must equal a
// whole word ("comb" in "combat boots", "pen" in "open toe heels").
const _exactWordTokens = <String>{'comb', 'pen', 'mask'};

const _fashionTokens = <String>[
  'shirt', 'tshirt', 't-shirt', 'tee', 'polo', 'top', 'blouse', 'hoodie',
  'sweatshirt', 'sweater', 'cardigan', 'knit', 'kurta', 'tunic',
  'trouser', 'pant', 'chino', 'jean', 'denim', 'short', 'skirt', 'jogger',
  'cargo', 'legging',
  'dress', 'gown', 'jumpsuit', 'saree', 'lehenga', 'sherwani', 'suit',
  'blazer', 'waistcoat',
  'jacket', 'coat', 'overshirt', 'parka',
  'shoe', 'sneaker', 'loafer', 'boot', 'sandal', 'heel', 'flat', 'mule',
  'slipper', 'slide', 'flip flop', 'flipflop', 'oxford', 'espadrille',
  'belt', 'watch', 'sunglass', 'scarf', 'muffler', 'tie', 'cufflink',
  'hat', 'cap', 'beanie', 'glove',
  'bag', 'tote', 'backpack', 'sling', 'clutch', 'wallet', 'cardholder',
  'briefcase', 'duffle', 'messenger',
  'necklace', 'bracelet', 'earring', 'ring', 'bangle', 'chain', 'pendant',
  'brooch', 'anklet', 'jewellery', 'jewelry',
];

const _fashionCategories = <String>{
  'top', 'tops', 'bottom', 'bottoms', 'dress', 'dresses', 'footwear',
  'shoes', 'outerwear', 'ethnicwear', 'ethnic', 'accessory', 'accessories',
  'bag', 'bags', 'watch', 'watches', 'jewellery', 'jewelry', 'shirt',
  'trouser', 'trousers', 'jeans', 'jacket', 'blazer', 'kurta', 'saree',
  'festive', 'loungewear', 'activewear',
};

String _blobOf(Map<String, dynamic> item) {
  final parts = <String>[
    (item['name'] ?? item['title'] ?? '').toString(),
    (item['category'] ?? item['type'] ?? item['subcategory'] ?? '').toString(),
  ];
  final tags = item['tags'];
  if (tags is List) parts.addAll(tags.map((t) => t.toString()));
  return parts.join(' ').toLowerCase();
}

bool _hasBlockedToken(String blob) {
  final words = blob.split(RegExp(r'[^a-z]+')).toSet();
  for (final token in _blockedNameTokens) {
    if (blob.contains(token)) return true;
  }
  for (final token in _exactWordTokens) {
    if (words.contains(token)) return true;
  }
  return false;
}

/// True when an item is safe to surface in stylist UI.
bool isFashionItem(Map<String, dynamic> item) {
  final name = (item['name'] ?? item['title'] ?? '').toString().trim();
  if (name.isEmpty) return false;
  final category =
      (item['category'] ?? item['type'] ?? '').toString().trim().toLowerCase();
  final blob = _blobOf(item);
  if (_blockedCategories.contains(category)) return false;
  if (_hasBlockedToken(blob)) return false;
  if (_fashionCategories.contains(category)) return true;
  for (final token in _fashionTokens) {
    if (blob.contains(token)) return true;
  }
  return false;
}

/// Filter a payload list down to fashion items only. Non-map entries are
/// dropped. Order preserved.
List<Map<String, dynamic>> filterFashionItems(List<dynamic>? items) {
  if (items == null) return const [];
  final out = <Map<String, dynamic>>[];
  for (final raw in items) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    if (isFashionItem(item)) out.add(item);
  }
  return out;
}
