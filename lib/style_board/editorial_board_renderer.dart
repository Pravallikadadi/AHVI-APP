import 'package:flutter/material.dart';

import 'board_models.dart';
import 'editorial_board_layout_engine.dart';
import 'editorial_board_widgets.dart';

/// Inner canvas only: no save/share bar, no item boxes.
/// Put this inside the existing AHVI board card body.
class EditorialBoardCanvas extends StatelessWidget {
  final StyleBoardData board;

  const EditorialBoardCanvas({super.key, required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final layout = EditorialBoardLayoutEngine.resolve(
            board,
            width: w,
            height: h,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              const _EditorialBackgroundDecor(),
              ...layout.placements.map((p) {
                return Positioned(
                  left: p.x,
                  top: p.y,
                  width: p.width,
                  height: p.height,
                  child: EditorialBoardItem(item: p.item, rotation: p.rotation),
                );
              }),
              Positioned(
                left: w * 0.03,
                bottom: h * 0.035,
                width: w * 0.42,
                child: Text(
                  _resolveCornerLabel(board),
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.05,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A6A78),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _resolveCornerLabel(StyleBoardData board) {
    final role = board.story?.role?.trim();
    if (role != null && role.isNotEmpty) return role;
    final occasion = board.occasion?.trim();
    if (occasion != null && occasion.isNotEmpty) return occasion;
    return 'Composed.';
  }
}

/// Premium board headline + summary above the collage.
///
/// Keep this lightweight (max two text lines) so the collage stays the focal
/// point. The expandable detail lives in [BoardStoryExpandable] below.
class BoardStoryHeader extends StatelessWidget {
  final StyleBoardData board;
  final EdgeInsetsGeometry padding;

  const BoardStoryHeader({
    super.key,
    required this.board,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final headline = board.story?.headline?.trim();
    final summary = board.summaryText?.trim();
    final hasHeadline = headline != null && headline.isNotEmpty;
    final hasSummary = summary != null && summary.isNotEmpty;
    if (!hasHeadline && !hasSummary) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeadline)
            Text(
              headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: Color(0xFF2A2A2A),
              ),
            ),
          if (hasSummary) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.25,
                color: Color(0xFF6E6968),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Collapsed-by-default "Why this works ›" panel that expands to show full
/// story details. Only renders rows where the backend supplied copy.
class BoardStoryExpandable extends StatefulWidget {
  final StyleBoardData board;
  final EdgeInsetsGeometry padding;

  const BoardStoryExpandable({
    super.key,
    required this.board,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  State<BoardStoryExpandable> createState() => _BoardStoryExpandableState();
}

class _BoardStoryExpandableState extends State<BoardStoryExpandable> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.board.story;
    if (story == null || !story.hasExpandableContent) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Why this works',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2A2A2A),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _open ? Icons.expand_less : Icons.chevron_right,
                  size: 16,
                  color: const Color(0xFF8A6A78),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: !_open
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _row('Why this works', widget.board.whyText),
                        _row('Personalized for you', story.personalNote),
                        _row('Occasion fit', story.occasionFit),
                        _row('Styling tip', widget.board.tipText),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String? body) {
    final text = body?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A6A78),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.32,
              color: Color(0xFF3C3A39),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialBackgroundDecor extends StatelessWidget {
  const _EditorialBackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _EditorialBackgroundPainter()),
      ),
    );
  }
}

class _EditorialBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Clean flat off-white canvas. The card's 0xFFFAF9F6 backing shows
    // through without decorative ovals competing with the garment cutouts.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
