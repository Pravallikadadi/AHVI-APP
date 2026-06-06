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
      height: 430,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: usable.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final direction = usable[index];
          final title = _text(direction['title'], 'Style Direction');
          final archetype = _text(direction['archetype'], '');
          final primaryLabel = archetype.isNotEmpty ? archetype : title;
          final secondaryLabel =
              archetype.isNotEmpty && archetype.toLowerCase() != title.toLowerCase()
                  ? title
                  : _text(direction['subtitle'], '');
          final description = _text(direction['description'], '');
          final heroPiece = _text(
            direction['hero_piece'] ?? direction['heroPiece'],
            '',
          );
          final whyItWorks = _text(
            direction['why_it_works'] ??
                direction['whyThisWorks'] ??
                direction['why_this_works'],
            '',
          );
          final styleNote = _text(
            direction['styling_tip'] ??
                direction['style_note'] ??
                direction['styleNote'],
            '',
          );
          final imageUrl = _nullableText(
            direction['image_url'] ?? direction['imageUrl'],
          );
          final palette = (_stringList(direction['colors']).isNotEmpty
                  ? _stringList(direction['colors'])
                  : _stringList(direction['palette']))
              .take(5)
              .toList(growable: false);
          final pieces = (_stringList(direction['items']).isNotEmpty
                  ? _stringList(direction['items'])
                  : _stringList(direction['pieces']))
              .take(5)
              .toList(growable: false);

          return Container(
            width: 310,
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
                        primaryLabel,
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
                if (secondaryLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      secondaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.mutedText,
                        fontSize: 11.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textPrimary.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.32,
                    ),
                  ),
                ],
                if (heroPiece.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoSection(
                    label: 'HERO PIECE',
                    value: heroPiece,
                    tokens: t,
                    icon: Icons.star_border_rounded,
                  ),
                ],
                if (whyItWorks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoSection(
                    label: 'WHY IT WORKS',
                    value: whyItWorks,
                    tokens: t,
                    maxLines: 4,
                  ),
                ],
                if (palette.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SectionLabel(text: 'COLOR STORY', tokens: t),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: palette
                        .map((color) => _PaletteChip(label: color, tokens: t))
                        .toList(growable: false),
                  ),
                ],
                if (pieces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SectionLabel(text: 'COMPONENTS', tokens: t),
                  const SizedBox(height: 4),
                  Text(
                    pieces.join(' - '),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.accent.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
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
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String label;
  final String value;
  final dynamic tokens;
  final IconData? icon;
  final int maxLines;

  const _InfoSection({
    required this.label,
    required this.value,
    required this.tokens,
    this.icon,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.accent.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: t.accent.primary),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: t.mutedText,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 12,
              height: 1.32,
              fontWeight: label == 'HERO PIECE' ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final dynamic tokens;

  const _SectionLabel({required this.text, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Text(
      text,
      style: TextStyle(
        color: t.mutedText,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final String label;
  final dynamic tokens;

  const _PaletteChip({required this.label, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: t.accent.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.accent.secondary.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: t.textPrimary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
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
