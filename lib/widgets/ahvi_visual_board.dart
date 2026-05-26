import 'package:flutter/material.dart';
import 'package:myapp/models/ahvi_visual_board_model.dart';

/// Single reusable renderer for every AHVI visual_board response
/// (diet / pack / plan). Handles all section layouts:
/// meal_options, batch_prep, simple_combinations, checklist, timeline_checklist.
///
/// Usage in any page:
///   if (AhviVisualBoard.isVisualBoard(response))
///     AhviVisualBoardView(board: AhviVisualBoard.fromJson(response));
class AhviVisualBoardView extends StatelessWidget {
  final AhviVisualBoard board;

  /// Optional palette overrides so a page can match its own theme.
  final Color? surfaceColor;
  final Color? textColor;
  final Color? mutedColor;
  final Color? accentColor;
  final Color? borderColor;

  const AhviVisualBoardView({
    super.key,
    required this.board,
    this.surfaceColor,
    this.textColor,
    this.mutedColor,
    this.accentColor,
    this.borderColor,
  });

  Color _surface(BuildContext c) =>
      surfaceColor ?? Theme.of(c).colorScheme.surfaceContainerHighest;
  Color _text(BuildContext c) =>
      textColor ?? Theme.of(c).colorScheme.onSurface;
  Color _muted(BuildContext c) =>
      mutedColor ?? Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.62);
  Color _accent(BuildContext c) =>
      accentColor ?? Theme.of(c).colorScheme.primary;
  Color _border(BuildContext c) =>
      borderColor ?? Theme.of(c).colorScheme.outline.withValues(alpha: 0.35);

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (board.title.isNotEmpty)
            Text(
              board.title,
              style: TextStyle(
                color: _text(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (board.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              board.subtitle,
              style: TextStyle(
                color: _muted(context),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (board.principles.isNotEmpty) ...[
            const SizedBox(height: 12),
            _principles(context),
          ],
          for (final section in board.sections) ...[
            const SizedBox(height: 16),
            _section(context, section),
          ],
          if (board.whyThisPlan.isNotEmpty) ...[
            const SizedBox(height: 16),
            _whyBox(context),
          ],
        ],
      ),
    );
  }

  Widget _principles(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: board.principles.map((p) {
        final value = p.value.isEmpty ? p.label : '${p.label} · ${p.value}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _accent(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent(context).withValues(alpha: 0.30)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: _text(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _section(BuildContext context, AhviBoardSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title.isNotEmpty)
          Text(
            section.title.toUpperCase(),
            style: TextStyle(
              color: _accent(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        const SizedBox(height: 8),
        _sectionBody(context, section),
      ],
    );
  }

  Widget _sectionBody(BuildContext context, AhviBoardSection section) {
    switch (section.layout) {
      case 'batch_prep':
        return _batchPrep(context, section);
      case 'checklist':
        return _checklist(context, section, timeline: false);
      case 'timeline_checklist':
        return _checklist(context, section, timeline: true);
      case 'meal_options':
      case 'simple_combinations':
      default:
        return _mealOptions(context, section);
    }
  }

  // meal_options + simple_combinations: name (bold) + pairing (muted).
  Widget _mealOptions(BuildContext context, AhviBoardSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: section.items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _accent(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: item.name,
                        style: TextStyle(
                          color: _text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.pairing.isNotEmpty)
                        TextSpan(
                          text: '  with ${item.pairing}',
                          style: TextStyle(
                            color: _muted(context),
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // batch_prep: category + option chips, plus an optional "turn into" row.
  Widget _batchPrep(BuildContext context, AhviBoardSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...section.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  style: TextStyle(
                    color: _text(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.options.map((opt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accent(context).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: _text(context),
                          fontSize: 11.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        if (section.turnInto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Turn into:  ',
                    style: TextStyle(
                      color: _accent(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: section.turnInto.join('  •  '),
                    style: TextStyle(color: _muted(context), fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // checklist + timeline_checklist: label rows.
  Widget _checklist(
    BuildContext context,
    AhviBoardSection section, {
    required bool timeline,
  }) {
    final items = section.items;
    final isPackingBoard =
        !timeline &&
        (board.boardType.toLowerCase().contains('pack') ||
            board.boardType.toLowerCase().contains('trip'));
    if (isPackingBoard) {
      return GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, i) => _packingTile(context, items[i]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        final isLast = i == items.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timeline)
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: _accent(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: _accent(context).withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: _accent(context),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
                  child: Text(
                    items[i].displayText,
                    style: TextStyle(color: _text(context), fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _packingTile(BuildContext context, AhviBoardItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _accent(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border(context).withValues(alpha: 0.75)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _packingThumb(context, item)),
          const SizedBox(height: 6),
          Text(
            item.displayText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _text(context),
              fontSize: 10.5,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _packingThumb(BuildContext context, AhviBoardItem item) {
    if (item.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          item.imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _packingIcon(context, item),
        ),
      );
    }
    return _packingIcon(context, item);
  }

  Widget _packingIcon(BuildContext context, AhviBoardItem item) {
    final label = item.displayText.toLowerCase();
    final icon = label.contains('sun')
        ? Icons.wb_sunny_outlined
        : label.contains('charger') || label.contains('power')
        ? Icons.battery_charging_full_rounded
        : label.contains('shoe') || label.contains('footwear')
        ? Icons.directions_run_rounded
        : label.contains('water')
        ? Icons.water_drop_outlined
        : label.contains('medicine') || label.contains('first')
        ? Icons.medical_services_outlined
        : label.contains('jacket') || label.contains('layer')
        ? Icons.checkroom_rounded
        : label.contains('toilet') || label.contains('moistur')
        ? Icons.spa_outlined
        : label.contains('sunglass')
        ? Icons.visibility_outlined
        : Icons.inventory_2_outlined;
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _accent(context).withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _accent(context), size: 22),
      ),
    );
  }

  Widget _whyBox(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _accent(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 15,
            color: _accent(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              board.whyThisPlan,
              style: TextStyle(
                color: _muted(context),
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
