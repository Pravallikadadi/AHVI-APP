import 'package:flutter/material.dart';
import 'package:myapp/feature/chat/services/fashion_item_filter.dart';
import 'package:myapp/feature/chat/services/saved_boards_store.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/editorial_collage.dart';
import 'package:myapp/theme/theme_tokens.dart';

typedef OutfitBoardMessageSender = void Function(String message);

class AhviOutfitBoardCard extends StatelessWidget {
  final Map<String, dynamic> direction;
  final double width;
  final OutfitBoardMessageSender? onSendMessage;
  final Map<String, dynamic> editorialCover;

  const AhviOutfitBoardCard({
    super.key,
    required this.direction,
    required this.width,
    this.onSendMessage,
    this.editorialCover = const {},
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final model = OutfitBoardModel.fromPayload(
      direction,
      editorialCover: editorialCover,
    );

    return SizedBox(
      width: width,
      height: width / 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: OutfitCollageGrid(items: model.items),
                ),
              ),
              OutfitContextStrip(model: model),
              OutfitActionBar(
                direction: direction,
                editorialCover: editorialCover,
                primaryLabel: model.title,
                missingName: model.missingName,
                onSendMessage: onSendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutfitCollageGrid extends StatelessWidget {
  final List<OutfitBoardItem> items;

  const OutfitCollageGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    if (items.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: t.accent.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Icon(
            Icons.checkroom_rounded,
            color: t.accent.primary.withValues(alpha: 0.55),
            size: 42,
          ),
        ),
      );
    }

    final hero = items.first;
    final support = items.skip(1).take(5).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 330 ? 6.0 : 8.0;
        final bottomHeight = support.length > 2
            ? constraints.maxHeight * 0.30
            : 0.0;
        final topHeight =
            constraints.maxHeight - bottomHeight - (bottomHeight > 0 ? gap : 0);
        final topSupport = support.take(2).toList(growable: false);
        final bottomSupport = support.skip(2).take(3).toList(growable: false);

        return Column(
          children: [
            SizedBox(
              height: topHeight,
              child: Row(
                children: [
                  Expanded(
                    flex: topSupport.isEmpty ? 1 : 3,
                    child: OutfitHeroTile(item: hero),
                  ),
                  if (topSupport.isNotEmpty) ...[
                    SizedBox(width: gap),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < topSupport.length;
                            index++
                          ) ...[
                            Expanded(
                              child: OutfitSupportTile(item: topSupport[index]),
                            ),
                            if (index != topSupport.length - 1)
                              SizedBox(height: gap),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (bottomSupport.isNotEmpty) ...[
              SizedBox(height: gap),
              SizedBox(
                height: bottomHeight,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < bottomSupport.length;
                      index++
                    ) ...[
                      Expanded(
                        child: OutfitSupportTile(item: bottomSupport[index]),
                      ),
                      if (index != bottomSupport.length - 1)
                        SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class OutfitHeroTile extends StatelessWidget {
  final OutfitBoardItem item;

  const OutfitHeroTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return _OutfitTile(item: item, hero: true);
  }
}

class OutfitSupportTile extends StatelessWidget {
  final OutfitBoardItem item;

  const OutfitSupportTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return _OutfitTile(item: item);
  }
}

class _OutfitTile extends StatelessWidget {
  final OutfitBoardItem item;
  final bool hero;

  const _OutfitTile({required this.item, this.hero = false});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final url = item.imageUrl;
    final image = url == null
        ? _placeholder(t)
        : Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _placeholder(t),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _placeholder(t),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: t.accent.primary.withValues(alpha: 0.045),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(padding: EdgeInsets.all(hero ? 10 : 6), child: image),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.66),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    hero ? 10 : 7,
                    hero ? 16 : 12,
                    hero ? 10 : 7,
                    hero ? 9 : 6,
                  ),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: hero ? 13 : 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
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

  Widget _placeholder(AppThemeTokens t) {
    return Center(
      child: Icon(
        collageIconForPiece(item.name),
        color: t.accent.primary.withValues(alpha: 0.58),
        size: hero ? 44 : 28,
      ),
    );
  }
}

class OutfitContextStrip extends StatelessWidget {
  final OutfitBoardModel model;

  const OutfitContextStrip({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              model.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ),
          if (model.chips.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 5,
                runSpacing: 4,
                children: model.chips
                    .take(2)
                    .map((chip) => _ContextChip(label: chip))
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;

  const _ContextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Container(
      constraints: const BoxConstraints(maxWidth: 98),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.accent.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: t.mutedText,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OutfitActionBar extends StatefulWidget {
  final Map<String, dynamic> direction;
  final Map<String, dynamic> editorialCover;
  final String primaryLabel;
  final String missingName;
  final OutfitBoardMessageSender? onSendMessage;

  const OutfitActionBar({
    super.key,
    required this.direction,
    required this.editorialCover,
    required this.primaryLabel,
    required this.missingName,
    this.onSendMessage,
  });

  @override
  State<OutfitActionBar> createState() => _OutfitActionBarState();
}

class _OutfitActionBarState extends State<OutfitActionBar> {
  bool _saved = false;
  bool _saving = false;

  String get _occasion {
    final cover = _text(widget.editorialCover['occasion_label']);
    if (cover.isNotEmpty) return cover;
    final direct = _text(widget.direction['occasion']);
    return direct.isNotEmpty ? direct : 'Curated Look';
  }

  String get _id => SavedBoardsStore.idFor(
    occasion: _occasion,
    directionName: widget.primaryLabel,
  );

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final saved = await SavedBoardsStore.isSaved(_id);
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_saved) {
        await SavedBoardsStore.remove(_id);
      } else {
        await SavedBoardsStore.saveBoard(
          occasion: _occasion,
          directionName: widget.primaryLabel,
          direction: widget.direction,
          editorialCover: widget.editorialCover,
        );
      }
      if (!mounted) return;
      setState(() {
        _saved = !_saved;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final canSend = widget.onSendMessage != null;
    final actions = <Widget>[
      _BoardAction(
        icon: _saved
            ? Icons.check_circle_rounded
            : Icons.favorite_border_rounded,
        label: _saved ? 'Saved' : 'Save',
        enabled: !_saving,
        onTap: _toggleSave,
      ),
      _BoardAction(
        icon: Icons.shuffle_rounded,
        label: 'Shuffle',
        enabled: canSend,
        onTap: () => widget.onSendMessage?.call(
          'Show more looks like ${widget.primaryLabel}',
        ),
      ),
      _BoardAction(
        icon: Icons.checkroom_rounded,
        label: 'Style This',
        enabled: canSend,
        onTap: () => widget.onSendMessage?.call(
          'Use my wardrobe for: ${widget.primaryLabel}',
        ),
      ),
      if (widget.missingName.isNotEmpty)
        _BoardAction(
          icon: Icons.shopping_bag_outlined,
          label: 'Missing',
          enabled: canSend,
          onTap: () => widget.onSendMessage?.call(
            'Show shopping ideas for: ${widget.missingName}',
          ),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.cardBorder)),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [for (final action in actions) Expanded(child: action)],
        ),
      ),
    );
  }
}

class _BoardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _BoardAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final color = enabled ? t.textPrimary : t.mutedText.withValues(alpha: 0.45);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum OutfitRole { hero, bottom, footwear, bag, accessory, other }

class OutfitBoardItem {
  final String id;
  final String name;
  final String? imageUrl;
  final OutfitRole role;

  const OutfitBoardItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
  });
}

class OutfitBoardModel {
  final String title;
  final List<String> chips;
  final List<OutfitBoardItem> items;
  final String missingName;

  const OutfitBoardModel({
    required this.title,
    required this.chips,
    required this.items,
    required this.missingName,
  });

  factory OutfitBoardModel.fromPayload(
    Map<String, dynamic> direction, {
    required Map<String, dynamic> editorialCover,
  }) {
    final directionName = _text(
      direction['direction_name'] ?? direction['directionName'],
    );
    final archetype = _text(direction['archetype']);
    final title = directionName.isNotEmpty
        ? directionName
        : (archetype.isNotEmpty
              ? archetype
              : _text(direction['title'], fallback: 'Style Direction'));
    final occasion = _text(
      direction['occasion'] ?? editorialCover['occasion_label'],
    );
    final adjectives = _strings(direction['adjectives']);
    final chips = <String>[
      if (occasion.isNotEmpty) occasion,
      if (adjectives.isNotEmpty) adjectives.first,
    ];

    final itemNames = _strings(direction['items'] ?? direction['pieces']);
    final heroName = _text(
      direction['hero_piece'] ?? direction['heroPiece'],
      fallback: itemNames.isEmpty ? 'Hero piece' : itemNames.first,
    );
    final heroUrl = _url(
      direction['normalized_url'] ??
          direction['normalizedUrl'] ??
          direction['masked_url'] ??
          direction['maskedUrl'] ??
          direction['image_url'] ??
          direction['imageUrl'],
    );
    final items = <OutfitBoardItem>[
      OutfitBoardItem(
        id: _text(direction['asset_id'], fallback: 'hero::$heroName::$heroUrl'),
        name: heroName,
        imageUrl: heroUrl,
        role: OutfitRole.hero,
      ),
    ];

    final complete = filterFashionItems(
      _maps(direction['complete_the_look'] ?? direction['completeTheLook']),
    );
    for (final item in complete) {
      final name = _text(item['name'] ?? item['title'] ?? item['label']);
      if (name.isEmpty) continue;
      items.add(
        OutfitBoardItem(
          id: _text(
            item['asset_id'] ?? item['id'],
            fallback:
                '$name::${_url(item['normalized_url'] ?? item['normalizedUrl'] ?? item['masked_url'] ?? item['maskedUrl'] ?? item['image_url'] ?? item['imageUrl'])}',
          ),
          name: name,
          imageUrl: _url(
            item['normalized_url'] ??
                item['normalizedUrl'] ??
                item['masked_url'] ??
                item['maskedUrl'] ??
                item['image_url'] ??
                item['imageUrl'],
          ),
          role: _roleFor(item, name),
        ),
      );
    }

    for (final name in itemNames) {
      if (name.toLowerCase() == heroName.toLowerCase()) continue;
      items.add(
        OutfitBoardItem(
          id: 'piece::$name',
          name: name,
          imageUrl: null,
          role: _roleFor(const {}, name),
        ),
      );
    }

    final seen = <String>{};
    final unique = items.where((item) {
      final key = item.id.isNotEmpty
          ? item.id.toLowerCase()
          : '${item.name.toLowerCase()}::${item.imageUrl ?? ''}';
      return seen.add(key);
    }).toList();
    final hero = unique.first;
    final support = unique.skip(1).toList()
      ..sort((a, b) => _roleRank(a.role).compareTo(_roleRank(b.role)));

    final rawMissing = direction['missing_piece'];
    final missing = rawMissing is Map
        ? Map<String, dynamic>.from(rawMissing)
        : const <String, dynamic>{};
    final missingName = isFashionItem(missing) ? _text(missing['name']) : '';

    return OutfitBoardModel(
      title: title,
      chips: chips,
      items: [hero, ...support.take(5)],
      missingName: missingName,
    );
  }
}

OutfitRole _roleFor(Map<String, dynamic> item, String name) {
  final blob = [
    name,
    item['category'],
    item['subcategory'],
    item['sub_category'],
    item['type'],
  ].whereType<Object>().join(' ').toLowerCase();
  if (RegExp(
    r'\b(trouser|pant|chino|jean|denim|skirt|short)\b',
  ).hasMatch(blob)) {
    return OutfitRole.bottom;
  }
  if (RegExp(
    r'\b(shoe|sneaker|loafer|boot|sandal|heel|jutti|mojari)\b',
  ).hasMatch(blob)) {
    return OutfitRole.footwear;
  }
  if (RegExp(
    r'\b(bag|tote|clutch|backpack|sling|duffle|briefcase)\b',
  ).hasMatch(blob)) {
    return OutfitRole.bag;
  }
  if (RegExp(
    r'\b(watch|belt|ring|brooch|necklace|bracelet|earring|scarf|tie)\b',
  ).hasMatch(blob)) {
    return OutfitRole.accessory;
  }
  return OutfitRole.other;
}

int _roleRank(OutfitRole role) {
  return switch (role) {
    OutfitRole.hero => 0,
    OutfitRole.bottom => 1,
    OutfitRole.footwear => 2,
    OutfitRole.bag => 3,
    OutfitRole.accessory => 4,
    OutfitRole.other => 5,
  };
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _url(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

List<String> _strings(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => _text(item))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
