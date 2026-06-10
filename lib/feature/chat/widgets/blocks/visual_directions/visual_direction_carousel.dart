import 'package:flutter/material.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/curation_reveal.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/editorial_collage.dart';
import 'package:myapp/theme/theme_tokens.dart';

/// Signature for sticky-action-bar invocations on a direction card.
typedef DirectionMessageSender = void Function(String message);

class VisualDirectionCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> directions;
  final double? cardWidth;
  final Map<String, dynamic> editorialCover;

  /// Optional sender used by the sticky action bar inside each direction
  /// card. When null the bar still renders but each action becomes a soft
  /// no-op so unmounted callbacks never crash.
  final DirectionMessageSender? onSendMessage;

  /// Toggle for the premium one-shot reveal animation. Defaults to on; the
  /// loader self-disables when there are no directions to gate.
  final bool curationReveal;

  const VisualDirectionCarousel({
    super.key,
    required this.directions,
    this.cardWidth,
    this.editorialCover = const {},
    this.onSendMessage,
    this.curationReveal = true,
  });

  @override
  Widget build(BuildContext context) {
    final usable = directions.where((item) => item.isNotEmpty).toList();
    if (usable.isEmpty) return const SizedBox.shrink();

    final width = cardWidth ?? 310.0;
    final hasCover = editorialCover.isNotEmpty &&
        _text(editorialCover['direction_name'], '').isNotEmpty;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCover) ...[
          EditorialCoverCard(cover: editorialCover),
          const SizedBox(height: 14),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < usable.length; index++) ...[
                _VisualDirectionCard(
                  direction: usable[index],
                  width: width,
                  onSendMessage: onSendMessage,
                ),
                if (index != usable.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );

    if (!curationReveal) return body;
    final occasionLabel =
        _text(editorialCover['occasion_label'], '').toUpperCase();
    final venueLabel = _text(editorialCover['venue'], '');
    return CurationReveal(
      occasionLabel: occasionLabel,
      venueLabel: venueLabel,
      child: body,
    );
  }
}

/// Magazine-style cover header that frames the curated looks below.
/// Renders the occasion label, lead direction name, wardrobe-match badge
/// and the curated-for benefit triad.
class EditorialCoverCard extends StatelessWidget {
  final Map<String, dynamic> cover;
  const EditorialCoverCard({super.key, required this.cover});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final occasion = _text(cover['occasion_label'], 'CURATED LOOK');
    final direction = _text(cover['direction_name'], 'Curated Direction');
    final pct = cover['wardrobe_match_pct'];
    final curatedFor = _stringList(cover['curated_for']).take(3).toList();
    final badge = cover['badge'];
    final occasionFit = badge is Map
        ? _text((badge)['occasion_fit'], '')
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            occasion,
            style: TextStyle(
              color: t.mutedText,
              fontSize: 11.5,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            direction,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          if (pct is int) ...[
            Row(
              children: [
                Icon(Icons.star_rounded, size: 16, color: t.accent.primary),
                const SizedBox(width: 5),
                Text(
                  'You Own $pct% Of This Look',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (occasionFit.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    '· $occasionFit Fit',
                    style: TextStyle(
                      color: t.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (curatedFor.isNotEmpty) ...[
            Text(
              'CURATED FOR',
              style: TextStyle(
                color: t.mutedText,
                fontSize: 9.5,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: curatedFor
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: t.accent.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisualDirectionCard extends StatelessWidget {
  final Map<String, dynamic> direction;
  final double width;
  final DirectionMessageSender? onSendMessage;

  const _VisualDirectionCard({
    required this.direction,
    required this.width,
    this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final title = _text(direction['title'], 'Style Direction');
    final archetype = _text(direction['archetype'], '');
    // Backend's editorial polish surfaces a curated direction_name which
    // should win over the looser archetype/title fallbacks.
    final directionName = _text(
      direction['direction_name'] ?? direction['directionName'],
      '',
    );
    final primaryLabel = directionName.isNotEmpty
        ? directionName
        : (archetype.isNotEmpty ? archetype : title);
    final secondaryLabel =
        archetype.isNotEmpty && archetype.toLowerCase() != title.toLowerCase()
            ? title
            : _text(direction['subtitle'], '');
    final description = _text(direction['description'], '');
    final heroPiece = _text(direction['hero_piece'] ?? direction['heroPiece'], '');
    // Prefer the server-capped short_note (≤2 sentences) so the card never
    // shows a wall of LLM prose. Falls back to existing fields.
    final whyItWorks = _text(
      direction['short_note'] ??
          direction['shortNote'] ??
          direction['why_it_works'] ??
          direction['whyThisWorks'] ??
          direction['why_this_works'],
      '',
    );
    final adjectives =
        _stringList(direction['adjectives']).take(3).toList(growable: false);
    final wardrobeMatchPct = direction['wardrobe_match_pct'] ??
        direction['wardrobeMatchPct'];
    final badge = direction['badge'];
    final badgeMap = badge is Map ? Map<String, dynamic>.from(badge) : const {};
    final occasionFit = _text(badgeMap['occasion_fit'], '');
    final completeTheLookCopy = _text(
      direction['complete_the_look_copy'] ??
          direction['completeTheLookCopy'],
      '',
    );
    final styleNote = _text(
      direction['styling_tip'] ?? direction['style_note'] ?? direction['styleNote'],
      '',
    );
    final imageUrl = _nullableText(direction['image_url'] ?? direction['imageUrl']);
    final palette = (_stringList(direction['colors']).isNotEmpty
            ? _stringList(direction['colors'])
            : _stringList(direction['palette']))
        .take(5)
        .toList(growable: false);
    final pieces = (_stringList(direction['items']).isNotEmpty
            ? _stringList(direction['items'])
            : _stringList(direction['pieces']))
        .take(6)
        .toList(growable: false);
    final completeTheLook = _mapList(
      direction['complete_the_look'] ?? direction['completeTheLook'],
    ).take(4).toList(growable: false);
    final dnaAlignment = _text(
      direction['style_dna_alignment'] ??
          direction['dna_alignment'] ??
          direction['persona_fit_reason'],
      '',
    );

    return Container(
      width: width,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_collageTiles(heroPiece, imageUrl, pieces, completeTheLook)
              .isNotEmpty) ...[
            EditorialCollage(
              tiles:
                  _collageTiles(heroPiece, imageUrl, pieces, completeTheLook),
              maxHeight: 200,
            ),
            const SizedBox(height: 10),
          ] else if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                height: 104,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: t.accent.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  primaryLabel,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
          if (adjectives.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                adjectives.join(' · '),
                style: TextStyle(
                  color: t.accent.primary,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (wardrobeMatchPct is int || occasionFit.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RecommendationBadge(
              matchPct: wardrobeMatchPct is int ? wardrobeMatchPct : null,
              occasionFit: occasionFit,
              tokens: t,
            ),
          ],
          if (secondaryLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                secondaryLabel,
                style: TextStyle(
                  color: t.mutedText,
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: t.textPrimary.withValues(alpha: 0.82),
                fontSize: 12,
                height: 1.35,
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
            _InfoSection(label: 'WHY IT WORKS', value: whyItWorks, tokens: t),
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
              style: TextStyle(
                color: t.mutedText,
                fontSize: 11.5,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (completeTheLook.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionLabel(text: 'COMPLETE THE LOOK', tokens: t),
            const SizedBox(height: 6),
            ...completeTheLook.map((item) => _AccessoryRow(item: item, tokens: t)),
          ],
          if (completeTheLookCopy.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.accent.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: t.accent.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                completeTheLookCopy,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.32,
                ),
              ),
            ),
          ],
          if (dnaAlignment.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoSection(
              label: 'WHY THIS FITS YOU',
              value: dnaAlignment,
              tokens: t,
              icon: Icons.person_pin_rounded,
            ),
          ],
          if (styleNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.accent.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                styleNote,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 11.4,
                  height: 1.32,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (_ownedFromPieces(pieces).isNotEmpty) ...[
            const SizedBox(height: 12),
            _WardrobeOwnershipStrip(
              ownedNames: _ownedFromPieces(pieces),
              matchPct: wardrobeMatchPct is int ? wardrobeMatchPct : null,
              tokens: t,
            ),
          ],
          const SizedBox(height: 12),
          _StickyActionBar(
            direction: direction,
            primaryLabel: primaryLabel,
            onSendMessage: onSendMessage,
            tokens: t,
          ),
        ],
      ),
    );
  }
}

/// Items that pass the fashion-category filter for ownership chips.
/// Backend doesn't currently expose a per-item ownership flag, so we
/// only label items whose names map to a wardrobe-eligible family.
List<String> _ownedFromPieces(List<String> pieces) {
  const eligible = <String>{
    'top', 'shirt', 't-shirt', 'tshirt', 'polo', 'hoodie', 'sweatshirt',
    'sweater', 'knit',
    'bottom', 'trouser', 'pant', 'chino', 'jean', 'jeans', 'short', 'shorts',
    'dress', 'gown', 'jumpsuit',
    'footwear', 'shoe', 'loafer', 'sneaker', 'boot', 'sandal', 'heel',
    'outerwear', 'blazer', 'jacket', 'coat', 'overshirt',
    'ethnicwear', 'kurta', 'sherwani', 'lehenga', 'saree',
    'accessory', 'belt', 'tie', 'scarf', 'sunglass',
    'bag', 'tote', 'sling', 'backpack',
    'watch',
    'jewellery', 'jewelry', 'necklace', 'bracelet', 'ring', 'earring',
  };
  final out = <String>[];
  for (final piece in pieces) {
    final lower = piece.toLowerCase();
    if (eligible.any((token) => lower.contains(token))) {
      out.add(piece);
    }
  }
  return out.take(6).toList(growable: false);
}

/// Collage tile assembly. Hero comes from heroPiece + the direction's own
/// image_url; supporting tiles come from complete_the_look entries with
/// image URLs, then from piece-name strings.
List<CollageTile> _collageTiles(
  String heroPiece,
  String? heroImageUrl,
  List<String> pieces,
  List<Map<String, dynamic>> completeTheLook,
) {
  final tiles = <CollageTile>[];
  final heroName = heroPiece.isNotEmpty
      ? heroPiece
      : (pieces.isNotEmpty ? pieces.first : '');
  if (heroName.isNotEmpty) {
    tiles.add(
      CollageTile(
        name: heroName,
        imageUrl: heroImageUrl,
        icon: collageIconForPiece(heroName),
      ),
    );
  }
  for (final item in completeTheLook) {
    final name = (item['name'] ?? item['title'] ?? item['label'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) continue;
    final url = (item['image_url'] ?? item['imageUrl'])?.toString().trim();
    if (tiles.any((t) => t.name.toLowerCase() == name.toLowerCase())) continue;
    tiles.add(
      CollageTile(
        name: name,
        imageUrl: (url != null && url.isNotEmpty) ? url : null,
        icon: collageIconForPiece(name),
      ),
    );
    if (tiles.length >= 6) return tiles;
  }
  for (final piece in pieces) {
    if (tiles.any((t) => t.name.toLowerCase() == piece.toLowerCase())) continue;
    tiles.add(CollageTile(name: piece, icon: collageIconForPiece(piece)));
    if (tiles.length >= 6) break;
  }
  return tiles;
}

class _WardrobeOwnershipStrip extends StatelessWidget {
  final List<String> ownedNames;
  final int? matchPct;
  final dynamic tokens;
  const _WardrobeOwnershipStrip({
    required this.ownedNames,
    required this.matchPct,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    if (ownedNames.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: t.accent.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_rounded, size: 13, color: t.accent.primary),
              const SizedBox(width: 6),
              Text(
                matchPct == null
                    ? 'ALREADY IN YOUR WARDROBE'
                    : 'YOU OWN $matchPct% OF THIS LOOK',
                style: TextStyle(
                  color: t.mutedText,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ownedNames
                .map(
                  (label) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: t.accent.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      label,
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
      ),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  final Map<String, dynamic> direction;
  final String primaryLabel;
  final DirectionMessageSender? onSendMessage;
  final dynamic tokens;
  const _StickyActionBar({
    required this.direction,
    required this.primaryLabel,
    required this.onSendMessage,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final missingName = _text(
      (direction['missing_piece'] is Map
              ? (direction['missing_piece'] as Map)['name']
              : null) ??
          (direction['missing_piece_name']),
      '',
    );
    final canSend = onSendMessage != null;

    Future<void> emit(String message) async {
      if (!canSend) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Saved to your boards (coming soon)'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      onSendMessage!.call(message);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          icon: Icons.favorite_border_rounded,
          label: 'Save',
          tokens: t,
          enabled: true,
          onTap: () => emit('Save this look: $primaryLabel'),
        ),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: 'More',
          tokens: t,
          enabled: canSend,
          onTap: () => emit('Show more looks like $primaryLabel'),
        ),
        _ActionButton(
          icon: Icons.shopping_bag_outlined,
          label: 'Missing',
          tokens: t,
          enabled: canSend,
          onTap: () => emit(
            missingName.isNotEmpty
                ? 'Show shopping ideas for: $missingName'
                : 'Show shopping ideas for: $primaryLabel',
          ),
        ),
        _ActionButton(
          icon: Icons.auto_awesome_rounded,
          label: 'Try On',
          tokens: t,
          enabled: false,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final dynamic tokens;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final color = enabled
        ? t.textPrimary
        : t.mutedText.withValues(alpha: 0.55);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String label;
  final String value;
  final dynamic tokens;
  final IconData? icon;

  const _InfoSection({
    required this.label,
    required this.value,
    required this.tokens,
    this.icon,
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

class _AccessoryRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final dynamic tokens;

  const _AccessoryRow({required this.item, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final name = _text(item['name'] ?? item['title'] ?? item['label'], '');
    final reason = _text(item['reason'], '');
    final imageUrl = _nullableText(item['image_url'] ?? item['imageUrl']);
    if (name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 34, height: 34),
              ),
            )
          else
            Icon(Icons.check_rounded, size: 16, color: t.accent.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason.isNotEmpty ? '$name - $reason' : name,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 11.6,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationBadge extends StatelessWidget {
  final int? matchPct;
  final String occasionFit;
  final dynamic tokens;

  const _RecommendationBadge({
    required this.matchPct,
    required this.occasionFit,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final pieces = <Widget>[];
    for (var i = 0; i < 5; i++) {
      pieces.add(Icon(Icons.star_rounded, size: 13, color: t.accent.primary));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.accent.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.accent.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ...pieces,
          const SizedBox(width: 8),
          Text(
            'Recommended',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (matchPct != null)
            Text(
              '$matchPct% Match',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (matchPct != null && occasionFit.isNotEmpty)
            const SizedBox(width: 6),
          if (occasionFit.isNotEmpty)
            Text(
              '· $occasionFit',
              style: TextStyle(
                color: t.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
