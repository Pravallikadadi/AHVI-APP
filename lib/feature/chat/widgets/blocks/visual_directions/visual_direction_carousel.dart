import 'package:flutter/material.dart';
import 'package:myapp/theme/theme_tokens.dart';

class VisualDirectionCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> directions;

  const VisualDirectionCarousel({super.key, required this.directions});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final usable = directions.where((item) => item.isNotEmpty).toList();
    if (usable.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 310,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: usable.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final direction = usable[index];
          final title = _text(direction['title'], 'Style Direction');
          final description = _text(direction['description'], '');
          final styleNote = _text(
            direction['style_note'] ?? direction['styleNote'],
            '',
          );
          final imageUrl = _nullableText(
            direction['image_url'] ?? direction['imageUrl'],
          );
          final palette = _stringList(direction['palette']).take(5);
          final pieces = _stringList(direction['pieces']).take(5);

          return Container(
            width: 300,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      height: 82,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: t.accent.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textPrimary.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.32,
                    ),
                  ),
                ],
                if (palette.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: palette
                        .map(
                          (color) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: t.accent.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: t.accent.secondary.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: Text(
                              color,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (pieces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    pieces.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.mutedText,
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                if (styleNote.isNotEmpty)
                  Text(
                    styleNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 11.4,
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _text(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty && item != 'null')
      .toList(growable: false);
}
