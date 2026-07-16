// ============================================================
// lib/widgets/build_outfit_screen.dart
// Build Outfit – AI-generated, same engine as Style Boards
//
// This screen used to be a fully separate manual builder (add item /
// remove item / save outfit, no AI). That's gone. Build Outfit now
// runs the same AI flow as Style Boards, implemented natively here:
//
// AI FLOW:
//   Step 1: selected item = fixed ANCHOR.
//   Step 2: search wardrobe for compatible items (category/slot,
//           color harmony, style/occasion signals). See ItemAttributes
//           + StyleCompatibility.
//   Step 3: rank candidates per slot, keep the highest scorer.
//           See BuildOutfitAIService._buildOutfitForOccasion.
//   Step 4 (missing-item handling) is intentionally NOT implemented:
//           if no wardrobe item matches a slot, that slot is simply
//           skipped. Every item on an outfit is always a real
//           wardrobe item — no AI-recommended placeholders.
//   Bonus: 3 variations generated per tap — Casual / Office / Evening —
//          surfaced as tabs above the grid.
//
// Outfit generation is async (BuildOutfitAIService.generateOutfits) to
// model a real "fetch from the styling AI" call. Today it's a local
// scoring heuristic + a simulated delay; swap the body of that one
// method for a real network call later without touching the rest of
// the screen.
//
// Screen features:
//   - Occasion tabs (Casual/Office/Evening) above the outfit.
//   - Lock/unlock individual items, shuffle unlocked items (re-ranked
//     against the anchor, not random).
//   - Outfit history, scoped per occasion tab.
//   - Tap an item to see details: lock/unlock, replace, find similar.
//   - Loading state while outfits are generated; error state with retry.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/app_localizations.dart';

// ============================================================
// PUBLIC ENTRY POINT
// ============================================================
void showBuildOutfitSheet(
    BuildContext context, {
      required WardrobeItem selectedItem,
      required List<WardrobeItem> allItems,
      VoidCallback? onStyleSelected,
      VoidCallback? onItemReplaced,
    }) {
  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog.fullscreen(
      child: BuildOutfitScreen(
        selectedItem: selectedItem,
        allItems: allItems,
        onStyleSelected: onStyleSelected,
        onItemReplaced: onItemReplaced,
      ),
    ),
  );
}

// ============================================================
// BOARD DISPLAY ITEM
// Every outfit slot is a real wardrobe item — there's no
// AI-recommended placeholder type here (Step 4 removed).
// ============================================================
abstract class BoardDisplayItem {
  String get id;
  String get name;
  String get cat;
  String? get displayUrl;
  double get matchScore;
  WardrobeItem? get wardrobeItem;
}

class WardrobeBoardItem implements BoardDisplayItem {
  final WardrobeItem item;
  @override
  final double matchScore;

  WardrobeBoardItem(this.item, {this.matchScore = 0});

  @override
  String get id => item.id;
  @override
  String get name => item.name ?? '';
  @override
  String get cat => item.cat;
  @override
  String? get displayUrl => item.displayUrl;
  @override
  WardrobeItem? get wardrobeItem => item;
}

// ============================================================
// MODEL CLASSES
// ============================================================
class Outfit {
  final String id;
  final String name;
  final String occasion; // 'casual' | 'office' | 'evening'
  final List<BoardDisplayItem> items;
  final String thumbnail;
  final DateTime createdAt;

  Outfit({
    required this.id,
    required this.name,
    required this.occasion,
    required this.items,
    required this.thumbnail,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class OutfitHistory {
  final String id;
  final String occasion; // which occasion tab this belongs to
  final List<BoardDisplayItem> items;
  final DateTime createdAt;

  OutfitHistory({
    required this.id,
    required this.occasion,
    required this.items,
    required this.createdAt,
  });

  String getTimeAgo(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) {
      return AppLocalizations.t(context, 'style_boards_time_now');
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${AppLocalizations.t(context, 'style_boards_time_minutes_ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${AppLocalizations.t(context, 'style_boards_time_hours_ago')}';
    }
    return '${diff.inDays}${AppLocalizations.t(context, 'style_boards_time_days_ago')}';
  }
}

// ============================================================
// ITEM CLASSIFICATION (slot / color / occasion signals)
// Heuristic, name+category based — same spirit as the previous
// keyword-matching approach, extended so the AI flow has something
// real to score against. Swap for real tagged wardrobe metadata
// (color, season, occasion fields on WardrobeItem) when available.
// ============================================================
enum ClothingSlot { top, bottom, dress, outerwear, footwear, bag, accessory, other }

class ItemAttributes {
  final ClothingSlot slot;
  final Set<String> colors;
  final Set<String> occasionTags;

  ItemAttributes({
    required this.slot,
    required this.colors,
    required this.occasionTags,
  });

  static const List<String> _knownColors = [
    'black', 'white', 'grey', 'gray', 'navy', 'blue', 'red', 'pink',
    'green', 'yellow', 'beige', 'brown', 'tan', 'cream', 'maroon',
    'purple', 'orange', 'gold', 'silver', 'olive',
  ];

  static const Map<String, List<String>> _occasionKeywords = {
    'casual': ['casual', 'denim', 'tshirt', 't-shirt', 'sneaker', 'hoodie', 'jeans', 'everyday'],
    'office': ['formal', 'office', 'blazer', 'trouser', 'shirt', 'pencil', 'loafer', 'work'],
    'evening': ['evening', 'party', 'gown', 'heel', 'silk', 'sequin', 'cocktail', 'dress'],
  };

  static ItemAttributes analyze(String? rawName, String rawCat) {
    final text = '${(rawName ?? '').toLowerCase()} ${rawCat.toLowerCase()}';

    final ClothingSlot slot;
    if (text.contains('dress') || text.contains('gown') || text.contains('jumpsuit')) {
      slot = ClothingSlot.dress;
    } else if (text.contains('shirt') ||
        text.contains('blouse') ||
        text.contains('top') ||
        text.contains('tshirt') ||
        text.contains('t-shirt') ||
        text.contains('sweater') ||
        text.contains('kurta') ||
        text.contains('tunic')) {
      slot = ClothingSlot.top;
    } else if (text.contains('pant') ||
        text.contains('trouser') ||
        text.contains('jeans') ||
        text.contains('skirt') ||
        text.contains('short') ||
        text.contains('legging')) {
      slot = ClothingSlot.bottom;
    } else if (text.contains('jacket') ||
        text.contains('blazer') ||
        text.contains('coat') ||
        text.contains('cardigan')) {
      slot = ClothingSlot.outerwear;
    } else if (text.contains('shoe') ||
        text.contains('heel') ||
        text.contains('sneaker') ||
        text.contains('sandal') ||
        text.contains('boot') ||
        text.contains('footwear')) {
      slot = ClothingSlot.footwear;
    } else if (text.contains('bag') ||
        text.contains('purse') ||
        text.contains('clutch') ||
        text.contains('tote')) {
      slot = ClothingSlot.bag;
    } else if (text.contains('watch') ||
        text.contains('necklace') ||
        text.contains('earring') ||
        text.contains('bracelet') ||
        text.contains('belt') ||
        text.contains('scarf') ||
        text.contains('sunglasses')) {
      slot = ClothingSlot.accessory;
    } else {
      slot = ClothingSlot.other;
    }

    final colors = _knownColors.where((c) => text.contains(c)).toSet();

    final occasionTags = <String>{};
    _occasionKeywords.forEach((occasion, keywords) {
      if (keywords.any((k) => text.contains(k))) occasionTags.add(occasion);
    });

    return ItemAttributes(slot: slot, colors: colors, occasionTags: occasionTags);
  }
}

/// Step 2 + Step 3 of the AI flow: compatibility search + ranking.
class StyleCompatibility {
  static const Set<String> _neutrals = {
    'black', 'white', 'grey', 'gray', 'navy', 'beige', 'tan', 'cream', 'brown'
  };

  static double colorHarmonyScore(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.5; // unknown colors — stay neutral
    if (a.any(_neutrals.contains) || b.any(_neutrals.contains)) return 1.0;
    if (a.intersection(b).isNotEmpty) return 0.9;
    return 0.6; // two different accent colors — still wearable, lower bonus
  }

  static double occasionScore(Set<String> tags, String targetOccasion) {
    if (tags.isEmpty) return 0.5; // no signal either way
    return tags.contains(targetOccasion) ? 1.0 : 0.3;
  }

  static double scoreCandidate({
    required ItemAttributes anchor,
    required ItemAttributes candidate,
    required String targetOccasion,
  }) {
    final color = colorHarmonyScore(anchor.colors, candidate.colors);
    final occasion = occasionScore(candidate.occasionTags, targetOccasion);
    return color * 0.5 + occasion * 0.5;
  }
}

// ============================================================
// AI STYLING SERVICE
// Owns Steps 1-4 of the "Style This" flow described in the AHVI spec.
// The public method is async and stands in for a real backend/model
// call — replace the body with an actual API request when one exists;
// the return type and call site stay the same.
// ============================================================
class BuildOutfitAIService {
  static const List<String> occasions = ['casual', 'office', 'evening'];

  static const Map<String, List<ClothingSlot>> _slotPlan = {
    'casual': [ClothingSlot.top, ClothingSlot.bottom, ClothingSlot.footwear, ClothingSlot.bag, ClothingSlot.accessory],
    'office': [ClothingSlot.top, ClothingSlot.bottom, ClothingSlot.outerwear, ClothingSlot.footwear, ClothingSlot.bag],
    'evening': [ClothingSlot.dress, ClothingSlot.footwear, ClothingSlot.bag, ClothingSlot.accessory],
  };

  static const int minItemsPerOutfit = 6;
  static const int maxItemsPerOutfit = 8;

  /// Steps 1-3 (no step 4 — see file header), run once per occasion,
  /// three occasions per tap.
  /// [occasionNameFor] resolves the localized tab/title text for an
  /// occasion key ('casual' | 'office' | 'evening').
  static Future<List<Outfit>> generateOutfits({
    required WardrobeItem anchorItem,
    required List<WardrobeItem> wardrobe,
    required String Function(String occasion) occasionNameFor,
  }) async {
    // Stand-in for network/model latency so the UI has a real
    // "fetching" state to show instead of an instant local shuffle.
    await Future.delayed(const Duration(milliseconds: 650));

    final anchorAttrs = ItemAttributes.analyze(anchorItem.name, anchorItem.cat);
    final pool = wardrobe.where((i) => i.id != anchorItem.id).toList();

    return [
      for (final occasion in occasions)
        _buildOutfitForOccasion(
          occasion: occasion,
          anchorItem: anchorItem,
          anchorAttrs: anchorAttrs,
          pool: pool,
          name: occasionNameFor(occasion),
        ),
    ];
  }

  static Outfit _buildOutfitForOccasion({
    required String occasion,
    required WardrobeItem anchorItem,
    required ItemAttributes anchorAttrs,
    required List<WardrobeItem> pool,
    required String name,
  }) {
    final neededSlots = List<ClothingSlot>.from(_slotPlan[occasion]!);
    neededSlots.remove(anchorAttrs.slot); // anchor already fills its own slot

    final entries = <BoardDisplayItem>[WardrobeBoardItem(anchorItem, matchScore: 1.0)];
    final usedIds = <String>{anchorItem.id};

    // Step 2 (search) + Step 3 (rank) per remaining slot.
    for (final slot in neededSlots) {
      if (entries.length >= maxItemsPerOutfit) break;

      final ranked = pool
          .where((i) => !usedIds.contains(i.id))
          .where((i) => ItemAttributes.analyze(i.name, i.cat).slot == slot)
          .map((i) => MapEntry(
        i,
        StyleCompatibility.scoreCandidate(
          anchor: anchorAttrs,
          candidate: ItemAttributes.analyze(i.name, i.cat),
          targetOccasion: occasion,
        ),
      ))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (ranked.isNotEmpty) {
        final best = ranked.first;
        entries.add(WardrobeBoardItem(best.key, matchScore: best.value));
        usedIds.add(best.key.id);
      }
      // No AI placeholder fallback: if nothing in the wardrobe matches
      // this slot, it's simply skipped.
    }

    // Keep the outfit within the 6-8 item cap; top up with any remaining
    // wardrobe pieces if it's short (e.g. very few slots planned).
    while (entries.length < minItemsPerOutfit) {
      final leftover = pool.where((i) => !usedIds.contains(i.id)).toList();
      if (leftover.isEmpty) break;
      leftover.shuffle();
      final pick = leftover.first;
      entries.add(WardrobeBoardItem(pick, matchScore: 0.5));
      usedIds.add(pick.id);
    }

    return Outfit(
      id: occasion,
      name: name,
      occasion: occasion,
      items: entries.take(maxItemsPerOutfit).toList(),
      thumbnail: anchorItem.displayUrl ?? '',
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================
class BuildOutfitScreen extends StatefulWidget {
  final WardrobeItem selectedItem;
  final List<WardrobeItem> allItems;
  final VoidCallback? onStyleSelected;
  final VoidCallback? onItemReplaced;

  const BuildOutfitScreen({
    required this.selectedItem,
    required this.allItems,
    this.onStyleSelected,
    this.onItemReplaced,
  });

  @override
  State<BuildOutfitScreen> createState() => _BuildOutfitScreenState();
}

class _BuildOutfitScreenState extends State<BuildOutfitScreen> {
  List<Outfit> outfits = [];
  List<OutfitHistory> outfitHistory = [];
  int selectedOutfitIndex = 0;
  String? selectedItemId;
  Set<String> lockedItemIds = {};
  bool _boardsInitialized = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    selectedItemId = widget.selectedItem.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_boardsInitialized) {
      _boardsInitialized = true;
      _loadOutfits();
    }
  }

  /// Small helper so brand-new UI strings never crash if a
  /// localization key hasn't been added yet — falls back to the
  /// given English text. Existing keys keep using AppLocalizations.t
  /// directly, unchanged.
  String _tr(BuildContext context, String key, String fallback) {
    try {
      final value = AppLocalizations.t(context, key);
      return value.isNotEmpty ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  // ── Data fetching (AI flow) ──────────────────────────────────

  Future<void> _loadOutfits() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final boards = await BuildOutfitAIService.generateOutfits(
        anchorItem: widget.selectedItem,
        wardrobe: widget.allItems,
        occasionNameFor: (occasion) {
          switch (occasion) {
            case 'casual':
              return _tr(context, 'style_boards_board_name_1', 'Casual');
            case 'office':
              return _tr(context, 'style_boards_board_name_2', 'Office');
            default:
              return _tr(context, 'style_boards_board_name_3', 'Evening');
          }
        },
      );

      if (!mounted) return;
      setState(() {
        outfits = boards;
        selectedOutfitIndex = 0;
        lockedItemIds.clear();
        outfitHistory = boards
            .map((b) => OutfitHistory(
          id: 'h_${b.occasion}_${DateTime.now().millisecondsSinceEpoch}',
          occasion: b.occasion,
          items: b.items,
          createdAt: DateTime.now(),
        ))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = _tr(context, 'buildOutfitLoadError',
            'Could not generate an outfit. Please try again.');
        _isLoading = false;
      });
    }
  }

  // ── State mutations ──────────────────────────────────────────

  void _toggleItemLock(String itemId) {
    setState(() {
      lockedItemIds.contains(itemId)
          ? lockedItemIds.remove(itemId)
          : lockedItemIds.add(itemId);
    });
  }

  /// Re-ranks unlocked, same-slot candidates against the anchor instead
  /// of shuffling purely at random — keeps a shoe slot a shoe, etc.
  void _shuffleUnlockedPieces() {
    setState(() {
      final board = outfits[selectedOutfitIndex];
      final anchorAttrs =
      ItemAttributes.analyze(widget.selectedItem.name, widget.selectedItem.cat);
      final usedIds = board.items.map((e) => e.id).toSet();
      final pool = widget.allItems.where((i) => i.id != widget.selectedItem.id).toList();

      final updated = board.items.map((entry) {
        if (lockedItemIds.contains(entry.id)) return entry;
        if (entry.id == widget.selectedItem.id) return entry; // never touch the anchor

        final slot = ItemAttributes.analyze(entry.name, entry.cat).slot;
        final ranked = pool
            .where((i) => !usedIds.contains(i.id))
            .where((i) => ItemAttributes.analyze(i.name, i.cat).slot == slot)
            .map((i) => MapEntry(
          i,
          StyleCompatibility.scoreCandidate(
            anchor: anchorAttrs,
            candidate: ItemAttributes.analyze(i.name, i.cat),
            targetOccasion: board.occasion,
          ),
        ))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (ranked.isEmpty) return entry; // nothing else fits this slot

        final topPicks = ranked.take(3).toList()..shuffle();
        final picked = topPicks.first;
        usedIds
          ..remove(entry.id)
          ..add(picked.key.id);
        return WardrobeBoardItem(picked.key, matchScore: picked.value);
      }).toList();

      final now = DateTime.now();

      outfits[selectedOutfitIndex] = Outfit(
        id: board.id,
        name: board.name,
        occasion: board.occasion,
        items: updated,
        thumbnail: board.thumbnail,
        createdAt: now,
      );

      outfitHistory.insert(
        0,
        OutfitHistory(
          id: 'h_${now.millisecondsSinceEpoch}',
          occasion: board.occasion,
          items: updated,
          createdAt: now,
        ),
      );
    });
  }

  void _unlockAll() => setState(() => lockedItemIds.clear());

  /// Restores a history snapshot into the currently-selected occasion
  /// board (Casual/Office/Evening), instead of always overwriting the
  /// first board regardless of which tab is open.
  void _switchOutfit(int historyIndex) {
    setState(() {
      final h = outfitHistory[historyIndex];
      final board = outfits[selectedOutfitIndex];

      outfits[selectedOutfitIndex] = Outfit(
        id: board.id,
        name: board.name,
        occasion: board.occasion,
        items: h.items,
        thumbnail: h.items.isNotEmpty ? (h.items.first.displayUrl ?? '') : '',
        createdAt: h.createdAt,
      );

      lockedItemIds.clear();
    });
  }

  void _selectItem(String itemId) {
    setState(() => selectedItemId = itemId);
    _showItemDetailsPanel();
  }

  void _showItemDetailsPanel() {
    final item = outfits[selectedOutfitIndex]
        .items
        .firstWhere((i) => i.id == selectedItemId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _SelectedItemPanel(
          item: item,
          isLocked: lockedItemIds.contains(selectedItemId),
          onToggleLock: () {
            _toggleItemLock(selectedItemId!);
            setModalState(() {});
          },
          onReplace: () {
            Navigator.pop(ctx);
            _openItemPicker(item, similarOnly: false);
          },
          onFindSimilar: () {
            Navigator.pop(ctx);
            _openItemPicker(item, similarOnly: true);
          },
        ),
      ),
    );
  }

  void _replaceItem(String oldId, BoardDisplayItem newItem) {
    setState(() {
      final board = outfits[selectedOutfitIndex];
      final idx = board.items.indexWhere((i) => i.id == oldId);
      if (idx == -1) return;

      final updated = List<BoardDisplayItem>.from(board.items)..[idx] = newItem;
      lockedItemIds.remove(oldId);

      final now = DateTime.now();

      outfits[selectedOutfitIndex] = Outfit(
        id: board.id,
        name: board.name,
        occasion: board.occasion,
        items: updated,
        thumbnail: board.thumbnail,
        createdAt: board.createdAt,
      );

      outfitHistory.insert(
        0,
        OutfitHistory(
          id: 'h_${now.millisecondsSinceEpoch}',
          occasion: board.occasion,
          items: updated,
          createdAt: now,
        ),
      );

      if (selectedItemId == oldId) selectedItemId = newItem.id;
    });
    widget.onItemReplaced?.call();
  }

  void _openItemPicker(BoardDisplayItem current, {required bool similarOnly}) {
    final usedIds = outfits[selectedOutfitIndex].items.map((i) => i.id).toSet();
    var candidates = widget.allItems.where((i) => !usedIds.contains(i.id)).toList();
    if (similarOnly) {
      candidates = candidates.where((i) => i.cat == current.cat).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemPickerSheet(
        title: similarOnly
            ? _tr(context, 'style_boards_find_similar_title', 'Find Similar')
            : _tr(context, 'style_boards_replace_title', 'Replace This Item'),
        candidates: candidates,
        onPicked: (picked) {
          Navigator.pop(ctx);
          _replaceItem(current.id, WardrobeBoardItem(picked));
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>()!;

    return Scaffold(
      backgroundColor: t.backgroundPrimary,
      appBar: _buildAppBar(context, t),
      body: _isLoading
          ? _buildLoadingState(context, t)
          : _loadError != null
          ? _buildErrorState(context, t)
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _buildOccasionTabs(context, t),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: t.cardBorder, width: 1.0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _buildUnifiedGrid(
                            context, t, outfits[selectedOutfitIndex].items),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildControlButtons(context, t),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _buildOutfitHistorySection(context, t),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, AppThemeTokens t) {
    return AppBar(
      backgroundColor: t.backgroundPrimary,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: t.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(context, 'buildOutfitTitle', 'Build Outfit'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          Text(
            _isLoading || _loadError != null || outfits.isEmpty
                ? ''
                : outfits[selectedOutfitIndex].name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: t.mutedText,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.done_all, color: t.textPrimary),
          onPressed: () {
            widget.onStyleSelected?.call();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  // ── Loading / error states ────────────────────────────────────

  Widget _buildLoadingState(BuildContext context, AppThemeTokens t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: t.accent.primary),
          const SizedBox(height: 16),
          Text(
            _tr(context, 'style_boards_loading', 'Styling your outfit…'),
            style: GoogleFonts.inter(fontSize: 13, color: t.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppThemeTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: t.mutedText, size: 32),
            const SizedBox(height: 12),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: t.mutedText),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _loadOutfits,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _tr(context, 'style_boards_retry', 'Retry'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.accent.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Occasion tabs (bonus feature: 3 variations) ────────────────

  Widget _buildOccasionTabs(BuildContext context, AppThemeTokens t) {
    return Row(
      children: List.generate(outfits.length, (i) {
        final isSelected = i == selectedOutfitIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == outfits.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => setState(() {
                selectedOutfitIndex = i;
                lockedItemIds.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? t.accent.primary : t.backgroundSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? t.accent.primary : t.cardBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  outfits[i].name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : t.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ============================================================
  // LAYOUT DISPATCHER
  // Picks the exact sketch layout based on item count (3–8).
  // ============================================================

  static const double _kGap = 16.0;

  // Caps how large any single grid cell in the 1/2/4-item layouts can
  // grow. Those layouts use half-width (or bigger) cells, which made
  // outfits with only a few items look oversized on typical phone
  // widths. 5/6/7/8-item layouts already divide into three columns and
  // stay compact on their own, so they're left as-is. (3-item layout
  // has its own sizing — see _kLayout3MaxRowWidth below.)
  static const double _kMaxCardExtent = 180.0;

  double _cappedCellWidth(double totalWidth, double gap, int columns,
      {double maxExtent = _kMaxCardExtent}) {
    final raw = (totalWidth - gap * (columns - 1)) / columns;
    return raw < maxExtent ? raw : maxExtent;
  }

  Widget _buildUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    switch (items.length) {
      case 1:
      case 2:
        return _layoutSmall(context, t, items);
      case 3:
        return _layout3(context, t, items);
      case 4:
        return _layout4(context, t, items);
      case 5:
        return _layout5(context, t, items);
      case 6:
        return _layout6(context, t, items);
      case 7:
        return _layout7(context, t, items);
      default:
        return _layout8(context, t, items.take(8).toList());
    }
  }

  // ─── 1–2 items: equal columns ─────────────────────────────────────────
  Widget _layoutSmall(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final n = items.length;
      final cw = _cappedCellWidth(box.maxWidth, _kGap, n);
      final gridWidth = cw * n + _kGap * (n - 1);

      return Center(
        child: SizedBox(
          width: gridWidth,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: n,
              crossAxisSpacing: _kGap,
              mainAxisSpacing: _kGap,
              childAspectRatio: 0.85,
            ),
            itemCount: n,
            itemBuilder: (_, i) => _buildItemCard(context, items[i], t),
          ),
        ),
      );
    });
  }

  // ─── 3 items ──────────────────────────────────────────────────────────
  // Left col:  one square item (leftW × leftW).
  // Right col: two square items (rightCw × rightCw each) stacked to
  //            exactly match the left item's height — derived so the
  //            left tile comes out square (matches a typical product
  //            photo's aspect, instead of a narrow rectangle that got
  //            cropped by BoxFit.cover) and the whole row never grows
  //            past _kLayout3MaxRowWidth.
  static const double _kLayout3MaxRowWidth = 270.0;

  Widget _layout3(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      const double g = _kGap;
      final w = box.maxWidth < _kLayout3MaxRowWidth
          ? box.maxWidth
          : _kLayout3MaxRowWidth;

      // Solving leftW = 2*rightCw + g (right column height matches the
      // left tile) together with leftW + g + rightCw = w (row fills w):
      final leftW = (2 * w - g) / 3;
      final rightCw = (w - 2 * g) / 3;
      final totalH = leftW; // square left tile

      return Center(
        child: SizedBox(
          width: leftW + g + rightCw,
          height: totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: one square item
              SizedBox(
                width: leftW,
                height: totalH,
                child: _buildItemCard(context, items[0], t),
              ),
              SizedBox(width: g),
              // Right: two square items, stacked
              SizedBox(
                width: rightCw,
                child: Column(
                  children: [
                    SizedBox(height: rightCw, child: _buildItemCard(context, items[1], t)),
                    SizedBox(height: g),
                    SizedBox(height: rightCw, child: _buildItemCard(context, items[2], t)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── 4 items ──────────────────────────────────────────────────────────
  Widget _layout4(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final cw = _cappedCellWidth(w, g, 2);
      final ih = cw;

      return Center(
        child: SizedBox(
          width: cw * 2 + g,
          child: Column(
            children: [
              _row2(context, t, items[0], items[1], cw, ih),
              SizedBox(height: g),
              _row2(context, t, items[2], items[3], cw, ih),
            ],
          ),
        ),
      );
    });
  }

  // ─── 5 items ──────────────────────────────────────────────────────────
  Widget _layout5(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final tlw = w * 0.42 - g / 2;
      final topH = tlw / 0.65;

      final biw = (w - 2 * g) / 3;
      final bih = biw;

      return Column(
        children: [
          SizedBox(
            height: topH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: tlw, child: _buildItemCard(context, items[0], t)),
                SizedBox(width: g),
                Expanded(child: _buildItemCard(context, items[1], t)),
              ],
            ),
          ),
          SizedBox(height: g),
          Row(
            children: [
              SizedBox(width: biw, height: bih, child: _buildItemCard(context, items[2], t)),
              SizedBox(width: g),
              SizedBox(width: biw, height: bih, child: _buildItemCard(context, items[3], t)),
              SizedBox(width: g),
              SizedBox(width: biw, height: bih, child: _buildItemCard(context, items[4], t)),
            ],
          ),
        ],
      );
    });
  }

  // ─── 6 items ──────────────────────────────────────────────────────────
  Widget _layout6(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final cw = (w - 2 * g) / 3;
      final ih = cw;

      return Column(
        children: [
          _row3(context, t, items.sublist(0, 3), cw, ih),
          SizedBox(height: g),
          _row3(context, t, items.sublist(3, 6), cw, ih),
        ],
      );
    });
  }

  // ─── 7 items ──────────────────────────────────────────────────────────
  // All items share the same cell size (cw × cw).
  // Left/middle cols: 2 items stacked → total height = cw*2 + g.
  // Right col: 3 items stacked at the same cw height → total height = cw*3 + 2*g.
  // The overall SizedBox uses the taller right column so nothing is clipped.
  Widget _layout7(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final cw = (w - 2 * g) / 3; // equal-width columns
      final totalH = cw * 3 + 2 * g; // right col drives the height

      return SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cw,
              child: Column(
                children: [
                  SizedBox(height: cw, child: _buildItemCard(context, items[0], t)),
                  SizedBox(height: g),
                  SizedBox(height: cw, child: _buildItemCard(context, items[1], t)),
                ],
              ),
            ),
            SizedBox(width: g),
            SizedBox(
              width: cw,
              child: Column(
                children: [
                  SizedBox(height: cw, child: _buildItemCard(context, items[2], t)),
                  SizedBox(height: g),
                  SizedBox(height: cw, child: _buildItemCard(context, items[3], t)),
                ],
              ),
            ),
            SizedBox(width: g),
            SizedBox(
              width: cw,
              child: Column(
                children: [
                  SizedBox(height: cw, child: _buildItemCard(context, items[4], t)),
                  SizedBox(height: g),
                  SizedBox(height: cw, child: _buildItemCard(context, items[5], t)),
                  SizedBox(height: g),
                  SizedBox(height: cw, child: _buildItemCard(context, items[6], t)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── 8 items ──────────────────────────────────────────────────────────
  Widget _layout8(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final tLW = w * 0.30 - g * 2 / 3;
      final tCW = w * 0.42 - g * 2 / 3;
      final tRW = w - tLW - tCW - 2 * g;
      final topH = tCW;

      final bLW = tLW;
      final bItemW = (w - bLW - 3 * g) / 3;
      final botH = bItemW;

      return Column(
        children: [
          SizedBox(
            height: topH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: tLW, child: _buildItemCard(context, items[0], t)),
                SizedBox(width: g),
                SizedBox(width: tCW, child: _buildItemCard(context, items[1], t)),
                SizedBox(width: g),
                SizedBox(
                  width: tRW,
                  child: Column(
                    children: [
                      Expanded(child: _buildItemCard(context, items[2], t)),
                      SizedBox(height: g),
                      Expanded(child: _buildItemCard(context, items[3], t)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: g),
          SizedBox(
            height: botH,
            child: Row(
              children: [
                SizedBox(width: bLW, child: _buildItemCard(context, items[4], t)),
                SizedBox(width: g),
                SizedBox(width: bItemW, child: _buildItemCard(context, items[5], t)),
                SizedBox(width: g),
                SizedBox(width: bItemW, child: _buildItemCard(context, items[6], t)),
                SizedBox(width: g),
                SizedBox(width: bItemW, child: _buildItemCard(context, items[7], t)),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ─── Row helpers ───────────────────────────────────────────────────────

  Widget _row2(BuildContext context, AppThemeTokens t,
      BoardDisplayItem a, BoardDisplayItem b, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, a, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, b, t)),
      ],
    );
  }

  Widget _row3(BuildContext context, AppThemeTokens t,
      List<BoardDisplayItem> row, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, row[0], t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, row[1], t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, row[2], t)),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, BoardDisplayItem item, AppThemeTokens t) {
    final isLocked = lockedItemIds.contains(item.id);

    // Border is only shown when item is locked
    final showBorder = isLocked;

    return GestureDetector(
      onTap: () => _selectItem(item.id),
      child: Container(
        decoration: BoxDecoration(
          border: showBorder
              ? Border.all(color: t.accent.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: t.backgroundSecondary,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.displayUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                item.displayUrl!,
                fit: BoxFit.cover,
              ),
            )
                : Center(
              child: Icon(
                Icons.checkroom,
                color: t.mutedText,
                size: 28,
              ),
            ),
            // Lock icon: always visible. Unlocked by default (light
            // circle + open padlock); switches to the locked look
            // (accent-filled circle + closed padlock) only once the
            // item is actually locked. Tapping it toggles the state.
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _toggleItemLock(item.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? t.accent.primary.withOpacity(0.90)
                        : Colors.white.withOpacity(0.90),
                    shape: BoxShape.circle,
                    border: isLocked
                        ? null
                        : Border.all(color: t.cardBorder, width: 1),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    color: isLocked ? Colors.white : t.mutedText,
                    size: 12,
                  ),
                ),
              ),
            ),
            // "Locked" badge: only shown once an item is locked, so it
            // never competes visually with the always-on icon above.
            if (isLocked)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accent.primary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.t(context, 'style_boards_item_locked_badge'),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Control buttons ──────────────────────────────────────────

  Widget _buildControlButtons(BuildContext context, AppThemeTokens t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.repeat,
          label: AppLocalizations.t(context, 'style_boards_button_shuffle'),
          onTap: _shuffleUnlockedPieces,
          t: t,
          isPrimary: true,
        ),
        _buildActionButton(
          context,
          icon: Icons.lock_open,
          label: AppLocalizations.t(context, 'style_boards_button_unlock_all'),
          onTap: _unlockAll,
          t: t,
        ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required AppThemeTokens t,
        bool isPrimary = false,
      }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isPrimary ? t.accent.primary : t.textPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isPrimary ? t.accent.primary : t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Board history section ────────────────────────────────────

  Widget _buildOutfitHistorySection(BuildContext context, AppThemeTokens t) {
    // Show only history entries that match the currently selected occasion tab
    final currentOccasion = outfits.isNotEmpty
        ? outfits[selectedOutfitIndex].occasion
        : '';
    final filteredHistory = outfitHistory
        .where((h) => h.occasion == currentOccasion)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "OUTFIT HISTORY" header — matches screenshot style (bold uppercase)
          Text(
            AppLocalizations.t(context, 'style_boards_history_title'),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredHistory.isEmpty)
          // Empty state wrapped in the same bordered container
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: t.cardBorder, width: 1.0),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.t(context, 'style_boards_no_history'),
                style: GoogleFonts.inter(fontSize: 13, color: t.mutedText),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredHistory.length,
              itemBuilder: (_, i) {
                final h = filteredHistory[i];
                final isCurrent = i == 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  // Board History cards are intentionally capped to a
                  // fixed max width — smaller than the main board's
                  // container — so they always read as compact
                  // previews, regardless of item count or layout.
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: _kHistoryCardMaxWidth),
                      child: GestureDetector(
                        onTap: () {
                          final realIndex = outfitHistory.indexOf(h);
                          _switchOutfit(realIndex);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isCurrent ? t.accent.primary : t.cardBorder,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: isCurrent
                                ? t.accent.primary.withOpacity(0.04)
                                : null,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row: timestamp label + current indicator
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isCurrent
                                              ? AppLocalizations.t(
                                              context,
                                              'style_boards_history_current')
                                              : h.getTimeAgo(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: t.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${h.items.length} ${AppLocalizations.t(context, 'style_boards_history_items_count')}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: t.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Current indicator — matching screenshot's blue check circle
                                  if (isCurrent)
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: t.accent.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Mini-grid: same layout as the main board, non-interactive
                              IgnorePointer(
                                child: _buildHistoryGrid(context, t, h.items),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── History mini-grid ────────────────────────────────────────
  // Renders the same layout as the main outfit grid but with cards
  // that have no interactive chrome (no lock icon, no tap handler).
  // IgnorePointer on the caller ensures taps fall through to the
  // parent GestureDetector that calls _switchOutfit.

  Widget _buildHistoryGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildHistoryUnifiedGrid(context, t, items);
  }

  Widget _buildHistoryUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    switch (items.length) {
      case 1:
      case 2:
        return _historyLayoutSmall(context, t, items);
      case 3:
        return _historyLayout3(context, t, items);
      case 4:
        return _historyLayout4(context, t, items);
      case 5:
        return _historyLayout5(context, t, items);
      case 6:
        return _historyLayout6(context, t, items);
      case 7:
        return _historyLayout7(context, t, items);
      default:
        return _historyLayout8(context, t, items.take(8).toList());
    }
  }

  static const double _kHGap = 10.0; // tighter gap for the mini preview

  // Outfit History cards are always rendered smaller than the main
  // board — this caps their overall width regardless of layout (A, B,
  // or otherwise), so they read as compact previews rather than
  // full-size boards.
  static const double _kHistoryCardMaxWidth = 200.0;

  Widget _buildHistoryItemCard(
      BuildContext context, BoardDisplayItem item, AppThemeTokens t) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: t.backgroundSecondary,
      ),
      child: item.displayUrl != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          item.displayUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.checkroom, color: t.mutedText, size: 14),
          ),
        ),
      )
          : Center(
        child: Icon(Icons.checkroom, color: t.mutedText, size: 14),
      ),
    );
  }

  Widget _historyLayoutSmall(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;
      final cw = items.length == 1 ? w : (w - g) / 2;
      final ih = cw * 0.85;
      return SizedBox(
        height: ih,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: g),
              SizedBox(width: cw, child: _buildHistoryItemCard(context, items[i], t)),
            ],
          ],
        ),
      );
    });
  }

  Widget _historyLayout3(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;

      // Same derivation as the main board's _layout3: left tile comes
      // out square (matches typical product-photo aspect instead of a
      // narrow rectangle that got cropped by BoxFit.cover), right
      // column sized to match its height exactly.
      final leftW = (2 * w - g) / 3;
      final rightCw = (w - 2 * g) / 3;
      final totalH = leftW;

      return SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: leftW, height: totalH, child: _buildHistoryItemCard(context, items[0], t)),
            SizedBox(width: g),
            SizedBox(
              width: rightCw,
              child: Column(
                children: [
                  SizedBox(height: rightCw, child: _buildHistoryItemCard(context, items[1], t)),
                  SizedBox(height: g),
                  SizedBox(height: rightCw, child: _buildHistoryItemCard(context, items[2], t)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _historyLayout4(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;
      final cw = (w - g) / 2;
      final ih = cw * 0.85;
      return Column(
        children: [
          _historyRow2(context, t, items[0], items[1], cw, ih),
          SizedBox(height: g),
          _historyRow2(context, t, items[2], items[3], cw, ih),
        ],
      );
    });
  }

  Widget _historyLayout5(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;
      final tlw = w * 0.42 - g / 2;
      final topH = tlw / 0.65;
      final biw = (w - 2 * g) / 3;
      final bih = biw;
      return Column(
        children: [
          SizedBox(
            height: topH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: tlw, child: _buildHistoryItemCard(context, items[0], t)),
                SizedBox(width: g),
                Expanded(child: _buildHistoryItemCard(context, items[1], t)),
              ],
            ),
          ),
          SizedBox(height: g),
          Row(
            children: [
              SizedBox(width: biw, height: bih, child: _buildHistoryItemCard(context, items[2], t)),
              SizedBox(width: g),
              SizedBox(width: biw, height: bih, child: _buildHistoryItemCard(context, items[3], t)),
              SizedBox(width: g),
              SizedBox(width: biw, height: bih, child: _buildHistoryItemCard(context, items[4], t)),
            ],
          ),
        ],
      );
    });
  }

  Widget _historyLayout6(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;
      final cw = (w - 2 * g) / 3;
      final ih = cw;
      return Column(
        children: [
          _historyRow3(context, t, items.sublist(0, 3), cw, ih),
          SizedBox(height: g),
          _historyRow3(context, t, items.sublist(3, 6), cw, ih),
        ],
      );
    });
  }

  Widget _historyLayout7(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;
      final cw = (w - 2 * g) / 3;
      final totalH = cw * 3 + 2 * g;
      return SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cw,
              child: Column(children: [
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[0], t)),
                SizedBox(height: g),
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[1], t)),
              ]),
            ),
            SizedBox(width: g),
            SizedBox(
              width: cw,
              child: Column(children: [
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[2], t)),
                SizedBox(height: g),
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[3], t)),
              ]),
            ),
            SizedBox(width: g),
            SizedBox(
              width: cw,
              child: Column(children: [
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[4], t)),
                SizedBox(height: g),
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[5], t)),
                SizedBox(height: g),
                SizedBox(height: cw, child: _buildHistoryItemCard(context, items[6], t)),
              ]),
            ),
          ],
        ),
      );
    });
  }

  Widget _historyLayout8(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kHGap;
      final tLW = w * 0.30 - g * 2 / 3;
      final tCW = w * 0.42 - g * 2 / 3;
      final tRW = w - tLW - tCW - 2 * g;
      final topH = tCW;
      final bLW = tLW;
      final bItemW = (w - bLW - 3 * g) / 3;
      final botH = bItemW;
      return Column(
        children: [
          SizedBox(
            height: topH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: tLW, child: _buildHistoryItemCard(context, items[0], t)),
                SizedBox(width: g),
                SizedBox(width: tCW, child: _buildHistoryItemCard(context, items[1], t)),
                SizedBox(width: g),
                SizedBox(
                  width: tRW,
                  child: Column(children: [
                    Expanded(child: _buildHistoryItemCard(context, items[2], t)),
                    SizedBox(height: g),
                    Expanded(child: _buildHistoryItemCard(context, items[3], t)),
                  ]),
                ),
              ],
            ),
          ),
          SizedBox(height: g),
          SizedBox(
            height: botH,
            child: Row(
              children: [
                SizedBox(width: bLW, child: _buildHistoryItemCard(context, items[4], t)),
                SizedBox(width: g),
                SizedBox(width: bItemW, child: _buildHistoryItemCard(context, items[5], t)),
                SizedBox(width: g),
                SizedBox(width: bItemW, child: _buildHistoryItemCard(context, items[6], t)),
                SizedBox(width: g),
                SizedBox(width: bItemW, child: _buildHistoryItemCard(context, items[7], t)),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _historyRow2(BuildContext context, AppThemeTokens t,
      BoardDisplayItem a, BoardDisplayItem b, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildHistoryItemCard(context, a, t)),
        const SizedBox(width: _kHGap),
        SizedBox(width: cw, height: ih, child: _buildHistoryItemCard(context, b, t)),
      ],
    );
  }

  Widget _historyRow3(BuildContext context, AppThemeTokens t,
      List<BoardDisplayItem> row, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildHistoryItemCard(context, row[0], t)),
        const SizedBox(width: _kHGap),
        SizedBox(width: cw, height: ih, child: _buildHistoryItemCard(context, row[1], t)),
        const SizedBox(width: _kHGap),
        SizedBox(width: cw, height: ih, child: _buildHistoryItemCard(context, row[2], t)),
      ],
    );
  }
}

// ============================================================
// ITEM DETAILS PANEL
// ============================================================
class _SelectedItemPanel extends StatelessWidget {
  final BoardDisplayItem item;
  final bool isLocked;
  final VoidCallback onToggleLock;
  final VoidCallback onReplace;
  final VoidCallback? onFindSimilar;

  const _SelectedItemPanel({
    required this.item,
    required this.isLocked,
    required this.onToggleLock,
    required this.onReplace,
    this.onFindSimilar,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>()!;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Material(
        color: t.backgroundPrimary,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.t(
                                context, 'style_boards_item_details_title'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: t.textPrimary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 280,
                        decoration: BoxDecoration(
                          color: t.backgroundSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: item.displayUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.displayUrl!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                            : Icon(
                          Icons.checkroom,
                          color: t.mutedText,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item.name.isNotEmpty ? item.name : item.cat,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.cat,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: t.mutedText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _action(
                        context,
                        icon: isLocked ? Icons.lock : Icons.lock_open,
                        label: isLocked
                            ? AppLocalizations.t(
                            context, 'style_boards_item_unlock')
                            : AppLocalizations.t(
                            context, 'style_boards_item_lock'),
                        onTap: onToggleLock,
                        t: t,
                        isPrimary: true,
                      ),
                      const SizedBox(height: 8),
                      _action(
                        context,
                        icon: Icons.repeat,
                        label: AppLocalizations.t(
                            context, 'style_boards_item_replace'),
                        onTap: onReplace,
                        t: t,
                      ),
                      const SizedBox(height: 8),
                      _action(
                        context,
                        icon: Icons.search,
                        label: AppLocalizations.t(
                            context, 'style_boards_item_find_similar'),
                        onTap: onFindSimilar ?? () {},
                        t: t,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required AppThemeTokens t,
        bool isPrimary = false,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Icon(icon,
                color: isPrimary ? t.accent.primary : t.textPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? t.accent.primary : t.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ITEM PICKER SHEET (Replace / Find Similar)
// Operates on real wardrobe items only — picking one always
// produces a WardrobeBoardItem back on the board.
// ============================================================
class _ItemPickerSheet extends StatelessWidget {
  final String title;
  final List<WardrobeItem> candidates;
  final ValueChanged<WardrobeItem> onPicked;

  const _ItemPickerSheet({
    required this.title,
    required this.candidates,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>()!;
    final height = MediaQuery.of(context).size.height;

    return Container(
      height: height * 0.65,
      decoration: BoxDecoration(
        color: t.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: t.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: candidates.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.t(context, 'style_boards_no_items_to_swap'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: t.mutedText),
                ),
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: candidates.length,
              itemBuilder: (_, i) {
                final item = candidates[i];
                return GestureDetector(
                  onTap: () => onPicked(item),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: t.cardBorder),
                      borderRadius: BorderRadius.circular(8),
                      color: t.backgroundPrimary,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.displayUrl != null
                        ? Image.network(item.displayUrl!,
                        fit: BoxFit.contain)
                        : Icon(Icons.checkroom,
                        color: t.mutedText, size: 24),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}