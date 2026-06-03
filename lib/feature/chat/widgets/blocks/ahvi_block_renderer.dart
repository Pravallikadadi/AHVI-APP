import 'package:flutter/material.dart';
import 'package:myapp/feature/chat/models/ahvi_response_block.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/visual_direction_carousel.dart';
import 'package:myapp/models/ahvi_visual_board_model.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_module_card.dart';

typedef StyleBoardsBuilder = Widget Function(List<dynamic> boards);
typedef VisualBoardBuilder = Widget Function(AhviVisualBoard board);
typedef ModuleCardBuilder = Widget Function(AhviModuleCard card);
typedef ModuleCardsBuilder = Widget Function(List<Map<String, dynamic>> cards);
typedef WardrobeGapBuilder = Widget Function(Map<String, dynamic> data);

class AhviBlockRenderer extends StatelessWidget {
  final AhviResponseBlock block;
  final StyleBoardsBuilder styleBoardsBuilder;
  final VisualBoardBuilder visualBoardBuilder;
  final ModuleCardBuilder moduleCardBuilder;
  final ModuleCardsBuilder moduleCardsBuilder;
  final WardrobeGapBuilder? wardrobeGapBuilder;

  const AhviBlockRenderer({
    super.key,
    required this.block,
    required this.styleBoardsBuilder,
    required this.visualBoardBuilder,
    required this.moduleCardBuilder,
    required this.moduleCardsBuilder,
    this.wardrobeGapBuilder,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case AhviBlockType.visualDirections:
        final directions = _mapList(block.data['directions']);
        return VisualDirectionCarousel(directions: directions);
      case AhviBlockType.styleBoards:
        final boards = block.data['boards'];
        return styleBoardsBuilder(boards is List ? boards : const []);
      case AhviBlockType.visualBoard:
        final board = block.data['board'];
        return board is AhviVisualBoard
            ? visualBoardBuilder(board)
            : const SizedBox.shrink();
      case AhviBlockType.moduleCards:
      case AhviBlockType.checklist:
      case AhviBlockType.plan:
        final moduleCard = block.data['module_card'];
        if (moduleCard is AhviModuleCard) return moduleCardBuilder(moduleCard);
        return moduleCardsBuilder(_mapList(block.data['cards']));
      case AhviBlockType.wardrobeGap:
        return wardrobeGapBuilder?.call(block.data) ??
            _DefaultWardrobeGapCard(data: block.data);
      case AhviBlockType.text:
      case AhviBlockType.image:
      case AhviBlockType.unknown:
        return const SizedBox.shrink();
    }
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

class _DefaultWardrobeGapCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DefaultWardrobeGapCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final message = (data['message'] ?? data['response'] ?? '')
        .toString()
        .trim();
    final missing = _mapList(data['missing_items']);
    if (message.isEmpty && missing.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16, right: 20, left: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.isEmpty
                ? "I need a little more wardrobe coverage for this."
                : message,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missing
                  .map(
                    (item) => Chip(
                      label: Text(
                        (item['label'] ?? item['name'] ?? item['category'])
                            .toString(),
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
