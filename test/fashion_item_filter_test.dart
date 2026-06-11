import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/services/fashion_item_filter.dart';

void main() {
  group('isFashionItem', () {
    test('rejects charger', () {
      expect(isFashionItem({'name': 'Phone Charger', 'category': 'electronics'}), isFalse);
      expect(isFashionItem({'name': 'Charger', 'category': ''}), isFalse);
    });

    test('rejects powerbank and cable', () {
      expect(isFashionItem({'name': 'Power Bank', 'category': 'accessory'}), isFalse);
      expect(isFashionItem({'name': 'Powerbank 20000mAh', 'category': ''}), isFalse);
      expect(isFashionItem({'name': 'USB-C Cable', 'category': 'misc'}), isFalse);
    });

    test('rejects skincare and grooming', () {
      expect(isFashionItem({'name': 'Face Moisturizer', 'category': 'skincare'}), isFalse);
      expect(isFashionItem({'name': 'Razor', 'category': ''}), isFalse);
      expect(isFashionItem({'name': 'Wide Tooth Comb', 'category': ''}), isFalse);
    });

    test('rejects travel gear', () {
      expect(isFashionItem({'name': 'Neck Pillow', 'category': 'travel_accessory'}), isFalse);
      expect(isFashionItem({'name': 'Water Bottle', 'category': ''}), isFalse);
      expect(isFashionItem({'name': 'Eye Mask', 'category': ''}), isFalse);
    });

    test('accepts core garments', () {
      expect(isFashionItem({'name': 'Navy Blazer', 'category': 'outerwear'}), isTrue);
      expect(isFashionItem({'name': 'White Oxford Shirt', 'category': 'top'}), isTrue);
      expect(isFashionItem({'name': 'Grey Trousers', 'category': 'bottom'}), isTrue);
      expect(isFashionItem({'name': 'Black Loafers', 'category': 'footwear'}), isTrue);
      expect(isFashionItem({'name': 'Steel Watch', 'category': 'watch'}), isTrue);
      expect(isFashionItem({'name': 'Blue Kurta', 'category': 'ethnicwear'}), isTrue);
    });

    test('short-token collisions do not false-positive', () {
      // "comb" must not match inside "combat boots";
      // "pen" must not match inside "open toe heels".
      expect(isFashionItem({'name': 'Combat Boots', 'category': ''}), isTrue);
      expect(isFashionItem({'name': 'Open Toe Heels', 'category': ''}), isTrue);
    });

    test('rejects empty name and unknown junk', () {
      expect(isFashionItem({'name': '', 'category': 'top'}), isFalse);
      expect(isFashionItem({'name': 'Something', 'category': ''}), isFalse);
      expect(isFashionItem({'name': 'Mystery', 'category': 'unknown'}), isFalse);
    });
  });

  group('filterFashionItems', () {
    test('filters mixed payload preserving order', () {
      final out = filterFashionItems([
        {'name': 'Navy Blazer', 'category': 'outerwear'},
        {'name': 'Phone Charger', 'category': 'electronics'},
        {'name': 'Grey Trousers', 'category': 'bottom'},
        'not-a-map',
        {'name': 'Power Bank', 'category': ''},
        {'name': 'Brown Loafer', 'category': 'footwear'},
      ]);
      expect(out.map((i) => i['name']).toList(),
          ['Navy Blazer', 'Grey Trousers', 'Brown Loafer']);
    });

    test('handles null and empty', () {
      expect(filterFashionItems(null), isEmpty);
      expect(filterFashionItems([]), isEmpty);
    });
  });
}
