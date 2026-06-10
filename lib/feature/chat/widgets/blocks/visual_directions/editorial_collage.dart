import 'package:flutter/material.dart';
import 'package:myapp/theme/theme_tokens.dart';

/// Tile feeding the Pinterest-style editorial collage.
class CollageTile {
  final String name;
  final String? imageUrl;
  final IconData icon;
  const CollageTile({required this.name, this.imageUrl, required this.icon});
}

/// Premium magazine-collage layout: one dominant hero tile, the rest of the
/// look orbits as smaller supporting tiles.
///
/// Handles 1–6 tiles. Each row stays inside the surrounding card so the
/// layout never overflows on small screens; missing image URLs degrade to
/// soft category-icon placeholders.
class EditorialCollage extends StatelessWidget {
  final List<CollageTile> tiles;
  final double maxHeight;

  const EditorialCollage({
    super.key,
    required this.tiles,
    this.maxHeight = 280,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final hero = tiles.first;
    final supporting = tiles.skip(1).take(5).toList(growable: false);
    final radius = BorderRadius.circular(14);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _TileFrame(
              tile: hero,
              radius: radius,
              heroLabel: true,
            ),
          ),
          if (supporting.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _SupportingColumn(
                tiles: supporting,
                radius: radius,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportingColumn extends StatelessWidget {
  final List<CollageTile> tiles;
  final BorderRadius radius;
  const _SupportingColumn({required this.tiles, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (tiles.length == 1) {
      return _TileFrame(tile: tiles.first, radius: radius);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _TileFrame(tile: tiles[0], radius: radius)),
        const SizedBox(height: 8),
        if (tiles.length == 2)
          Expanded(child: _TileFrame(tile: tiles[1], radius: radius))
        else
          Expanded(
            child: Row(
              children: [
                Expanded(child: _TileFrame(tile: tiles[1], radius: radius)),
                const SizedBox(width: 8),
                Expanded(child: _TileFrame(tile: tiles[2], radius: radius)),
                if (tiles.length >= 4) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _TileFrame(tile: tiles[3], radius: radius)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TileFrame extends StatelessWidget {
  final CollageTile tile;
  final BorderRadius radius;
  final bool heroLabel;
  const _TileFrame({
    required this.tile,
    required this.radius,
    this.heroLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final url = tile.imageUrl?.trim();
    final body = (url != null && url.isNotEmpty)
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(t),
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : _placeholder(t),
          )
        : _placeholder(t);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: t.accent.primary.withValues(alpha: 0.04)),
          body,
          if (heroLabel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Text(
                  tile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            )
          else
            Positioned(
              left: 6,
              right: 6,
              bottom: 5,
              child: Text(
                tile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(blurRadius: 4, color: Colors.white70),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(dynamic t) {
    return Container(
      alignment: Alignment.center,
      color: t.accent.primary.withValues(alpha: 0.06),
      child: Icon(
        tile.icon,
        color: t.accent.primary.withValues(alpha: 0.6),
        size: 28,
      ),
    );
  }
}

/// Map a piece name to a soft category icon for the placeholder state.
IconData collageIconForPiece(String name) {
  final n = name.toLowerCase();
  if (n.contains('blazer') ||
      n.contains('jacket') ||
      n.contains('coat') ||
      n.contains('overshirt')) {
    return Icons.checkroom_rounded;
  }
  if (n.contains('shirt') ||
      n.contains('polo') ||
      n.contains('tee') ||
      n.contains('top') ||
      n.contains('kurta')) {
    return Icons.dry_cleaning_rounded;
  }
  if (n.contains('trouser') ||
      n.contains('pant') ||
      n.contains('chino') ||
      n.contains('jean') ||
      n.contains('short')) {
    return Icons.straighten_rounded;
  }
  if (n.contains('loafer') ||
      n.contains('shoe') ||
      n.contains('sneaker') ||
      n.contains('boot') ||
      n.contains('sandal')) {
    return Icons.directions_walk_rounded;
  }
  if (n.contains('watch')) return Icons.watch_rounded;
  if (n.contains('bag') ||
      n.contains('tote') ||
      n.contains('sling') ||
      n.contains('backpack')) {
    return Icons.work_outline_rounded;
  }
  if (n.contains('sunglass')) return Icons.wb_sunny_rounded;
  if (n.contains('belt')) return Icons.linear_scale_rounded;
  if (n.contains('cap') || n.contains('hat') || n.contains('beanie')) {
    return Icons.face_retouching_natural_rounded;
  }
  if (n.contains('necklace') ||
      n.contains('bracelet') ||
      n.contains('ring') ||
      n.contains('earring') ||
      n.contains('jewel')) {
    return Icons.diamond_outlined;
  }
  return Icons.style_rounded;
}
