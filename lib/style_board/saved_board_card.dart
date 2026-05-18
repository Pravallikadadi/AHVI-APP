import 'package:appwrite/models.dart' as appwrite_models;
import 'package:flutter/material.dart';

import 'package:myapp/app_localizations.dart';
import 'package:myapp/style_board/saved_board_thumb.dart';
import 'package:myapp/theme/theme_tokens.dart';

class SavedBoardCard extends StatelessWidget {
  final dynamic source;
  final Map<String, Map<String, dynamic>> wardrobeById;
  final VoidCallback? onTap;

  const SavedBoardCard({
    super.key,
    required this.source,
    required this.wardrobeById,
    this.onTap,
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
      return Map<String, dynamic>.from(source as Map);
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final data = _data;
    final category = (data['boardCategoryLabel'] ?? data['occasion'] ?? 'Saved')
        .toString();
    final title = (data['title'] ?? category).toString();
    final description =
        (data['outfitDescription'] ??
                data['description'] ??
                'AHVI saved style board')
            .toString();
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: SavedBoardThumb(
                source: source,
                wardrobeById: wardrobeById,
                radius: BorderRadius.zero,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.accent.primary,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.mutedText,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                width: double.infinity,
                height: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [t.accent.tertiary, t.accent.primary],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      context.tr('daily_wear_try_on'),
                      style: TextStyle(
                        color: onAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
