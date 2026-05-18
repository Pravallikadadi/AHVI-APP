import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' as appwrite_models;

import 'package:myapp/widgets/offline_image.dart';
import 'board_renderer.dart';

class SavedBoardThumb extends StatelessWidget {
  /// Either an Appwrite Document or a `{id, data}` raw map.
  final dynamic source;
  final Map<String, Map<String, dynamic>> wardrobeById;
  final BorderRadius radius;

  const SavedBoardThumb({
    super.key,
    required this.source,
    required this.wardrobeById,
    this.radius = const BorderRadius.all(Radius.circular(16)),
  });

  Map<String, dynamic> get _data {
    if (source is appwrite_models.Document) {
      return Map<String, dynamic>.from(
        (source as appwrite_models.Document).data,
      );
    }
    if (source is Map) {
      final data = (source as Map)['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    return const {};
  }

  // Backwards-compat constructor for callers passing `doc:`.
  factory SavedBoardThumb.fromDoc({
    Key? key,
    required appwrite_models.Document doc,
    required Map<String, Map<String, dynamic>> wardrobeById,
    BorderRadius radius = const BorderRadius.all(Radius.circular(16)),
  }) => SavedBoardThumb(
    key: key,
    source: doc,
    wardrobeById: wardrobeById,
    radius: radius,
  );

  List<Map<String, dynamic>> _hydrateItems() {
    final raw = _data['itemIds'] ?? _data['item_ids'] ?? const [];
    if (raw is! Iterable) return const [];
    final out = <Map<String, dynamic>>[];
    for (final id in raw) {
      final key = id.toString();
      final item = wardrobeById[key];
      if (item != null) out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final items = _hydrateItems();

    if (items.length >= 2) {
      final occasion = (data['title'] ?? data['occasion'] ?? '').toString();
      final boardMap = <String, dynamic>{
        'title': occasion.isEmpty ? 'Saved Look' : occasion,
        'occasion': occasion,
        'items': items,
      };
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          color: const Color(0xFFFFFCF5),
          padding: const EdgeInsets.all(8),
          child: StyleBoardBody(board: boardDataFromMap(boardMap)),
        ),
      );
    }

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: OfflineImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_) => _placeholder(),
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: const Color(0xFFF1ECE3),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.black38),
      ),
    );
  }
}
