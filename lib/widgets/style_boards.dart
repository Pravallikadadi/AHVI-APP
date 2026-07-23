// ============================================================
// lib/widgets/style_boards.dart
// Style Boards – FULLY OPTIMIZED for large wardrobes
//
// AI FLOW UPDATE (per AHVI "Style This" spec):
//   Step 1: selected item = fixed ANCHOR — always position 0 in every
//           generated board, guaranteed by _rehydrateBoards.
//   Step 2: backend receives the anchor + full wardrobe and returns
//           outfit items for each occasion (casual/office/evening).
//           See StyleBoardBackendClient + _BackendBoardDto.
//   Step 3: backend items are re-hydrated into BoardDisplayItem:
//           known wardrobeItemIds → WardrobeBoardItems (full model);
//           unknown items → AiRecommendedBoardItems.
//   Step 4: assemble the board (anchor + backend items, 6-8 total).
//           Style Board items are BACKEND-ONLY — there is no local
//           heuristic fallback. If the backend call fails, the screen
//           shows the error state (retry button) instead of silently
//           generating a board from the local wardrobe.
//   Bonus: 3 variations per tap — Casual / Office / Evening —
//          surfaced as tabs above the grid instead of a single board.
//
// NEW LOCALIZATION KEYS REQUIRED:
//   style_boards_anchor_badge  — short badge shown on the anchor card
//                                e.g. "Selected"
//   style_boards_anchor_note   — note in the item details panel when
//                                the anchor is tapped, e.g. "This is
//                                your selected item. It will always
//                                appear in your style board."
//   style_boards_picker_load_error — shown in the Replace / Find Similar
//                                sheet when the backend call fails,
//                                e.g. "Couldn't load suggestions. Check
//                                your connection and try again."
//                                (reuses style_boards_retry for the button)
//
// To point at your real endpoint, update StyleBoardBackendClient._kEndpoint.
//
// REPLACE / FIND SIMILAR — BACKEND-ONLY, NO LOCAL FALLBACK:
//   Both actions call StyleBoardBackendClient.fetchReplacementCandidates
//   (see _openItemPicker), which POSTs the anchor, wardrobe, occasion,
//   the item being swapped, and a similarOnly flag (true for "Find
//   Similar", false for "Replace"). The backend decides what counts as
//   a match — not a local category filter — so it can suggest pieces
//   beyond the user's own wardrobe as AiRecommendedBoardItems. The item
//   picker sheet shows a loading skeleton while this request is in
//   flight. If the backend call fails, there is NO fallback to the
//   local wardrobe — the sheet shows an error state (wifi-off icon +
//   style_boards_picker_load_error + retry button) instead. Shuffle
//   already used the backend (StyleBoardBackendClient.fetchBoards)
//   before this change and is unchanged here.
//   To point at your real endpoint, update
//   StyleBoardBackendClient._kReplaceEndpoint.
//
// GRID LAYOUT CHANGES:
//   - Occasion tabs (Casual/Office/Evening) above the board.
//   - "From Your Wardrobe" vs "AI Recommended" legend + per-card badge.
//   - AI-recommended cards without an image show a distinct icon + slot
//     label instead of the generic hanger icon, so they never look like
//     a broken photo.
//   - Loading state while boards are generated; simple error state with
//     retry if generation fails.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/app_localizations.dart';

// ============================================================
// PUBLIC ENTRY POINT
// ============================================================
void showStyleBoardsSheet(
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
      child: StyleBoardsScreen(
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
// A style-board slot is either a real wardrobe item, or (when the
// wardrobe has no compatible piece) an AI-recommended placeholder.
// Both expose the same fields so the grid/layout code never needs to
// know which one it's rendering.
// ============================================================
abstract class BoardDisplayItem {
  String get id;
  String get name;
  String get cat;
  String? get displayUrl;
  bool get isAiRecommended;
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
  bool get isAiRecommended => false;
  @override
  WardrobeItem? get wardrobeItem => item;
}

class AiRecommendedBoardItem implements BoardDisplayItem {
  @override
  final String id;
  @override
  final String name;
  @override
  final String cat;
  @override
  final String? displayUrl;
  @override
  final double matchScore;
  final String reason;

  AiRecommendedBoardItem({
    required this.id,
    required this.name,
    required this.cat,
    this.displayUrl,
    this.matchScore = 0,
    this.reason = '',
  });

  @override
  bool get isAiRecommended => true;
  @override
  WardrobeItem? get wardrobeItem => null;
}

// ============================================================
// MODEL CLASSES
// ============================================================
class StyleBoard {
  final String id;
  final String name;
  final String occasion; // 'casual' | 'office' | 'evening'
  final List<BoardDisplayItem> items;
  final String thumbnail;
  final DateTime createdAt;

  StyleBoard({
    required this.id,
    required this.name,
    required this.occasion,
    required this.items,
    required this.thumbnail,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class BoardHistory {
  final String id;
  final String occasion; // which occasion tab this belongs to
  final List<BoardDisplayItem> items;
  final DateTime createdAt;

  BoardHistory({
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
// CLOTHING SLOT
// Used only to label AI-recommended board items with a human-readable
// slot name (e.g. "Footwear") when the backend doesn't provide one.
// The local keyword-matching classification/scoring heuristic that
// used to live here has been removed — Style Board items are
// backend-only now, so there is nothing left locally to classify or
// score against.
// ============================================================
enum ClothingSlot { top, bottom, dress, outerwear, footwear, bag, accessory, other }

// ============================================================
// BACKEND CLIENT
// Wraps the real "generate style board" endpoint.
// Contract:
//   POST /api/style-boards/generate
//   Body:  { "anchor": { WardrobeItem fields }, "wardrobe": [...] }
//   Reply: { "boards": [ { "occasion", "items": [...] } ] }
//
// Each item in "items" is:
//   { "wardrobeItemId": "<id or null>",
//     "name": "<string>",
//     "category": "<string>",
//     "imageUrl": "<string|null>",
//     "isAiRecommended": <bool> }
//
// When wardrobeItemId is non-null the client re-hydrates it from the
// local wardrobe list so the full WardrobeItem model is available for
// lock/replace flows.
//
// The anchor item is ALWAYS injected at position 0 of every board by
// _rehydrateBoards regardless of what the backend returns, so there is
// no risk of the selected item being absent from the style board.
// ============================================================

/// Raw per-item DTO returned by the backend.
class _BackendBoardItemDto {
  final String? wardrobeItemId;
  final String name;
  final String category;
  final String? imageUrl;
  final bool isAiRecommended;

  const _BackendBoardItemDto({
    required this.wardrobeItemId,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.isAiRecommended,
  });

  factory _BackendBoardItemDto.fromJson(Map<String, dynamic> j) =>
      _BackendBoardItemDto(
        wardrobeItemId: j['wardrobeItemId'] as String?,
        name: (j['name'] as String?) ?? '',
        category: (j['category'] as String?) ?? '',
        imageUrl: j['imageUrl'] as String?,
        isAiRecommended: (j['isAiRecommended'] as bool?) ?? false,
      );
}

/// Raw per-board DTO returned by the backend.
class _BackendBoardDto {
  final String occasion;
  final List<_BackendBoardItemDto> items;

  const _BackendBoardDto({required this.occasion, required this.items});

  factory _BackendBoardDto.fromJson(Map<String, dynamic> j) =>
      _BackendBoardDto(
        occasion: (j['occasion'] as String?) ?? 'casual',
        items: ((j['items'] as List?) ?? [])
            .map((e) => _BackendBoardItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StyleBoardBackendClient {
  /// Replace [_kEndpoint] with your real API base URL.
  static const String _kEndpoint = 'https://api.example.com/api/style-boards/generate';

  /// Sends the selected item + full wardrobe to the backend and returns
  /// the raw board DTOs for all three occasions.
  ///
  /// Throws on any network / non-2xx error so the caller can surface a
  /// retry state.
  static Future<List<_BackendBoardDto>> fetchBoards({
    required WardrobeItem anchorItem,
    required List<WardrobeItem> wardrobe,
  }) async {
    final body = jsonEncode({
      'anchor': _wardrobeItemToJson(anchorItem),
      'wardrobe': wardrobe.map(_wardrobeItemToJson).toList(),
    });

    final response = await http.post(
      Uri.parse(_kEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Style board API returned ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final boardsJson = (decoded['boards'] as List?) ?? [];
    return boardsJson
        .map((e) => _BackendBoardDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Map<String, dynamic> _wardrobeItemToJson(WardrobeItem item) => {
    'id': item.id,
    'name': item.name,
    'cat': item.cat,
    'imageUrl': item.displayUrl,
  };

  /// Replace [_kReplaceEndpoint] with your real API base URL.
  ///
  /// Powers BOTH "Replace item" and "Find similar" — [similarOnly]
  /// tells the backend whether to constrain suggestions to close
  /// matches of [currentItem] (find similar) or return its normal
  /// slot-appropriate replacement pool (replace). Either way the
  /// backend — not a local category filter — decides what qualifies,
  /// so it can surface pieces beyond the user's own wardrobe.
  static const String _kReplaceEndpoint =
      'https://api.example.com/api/style-boards/replace';

  /// Requests replacement candidates for [currentItem] from the backend.
  ///
  /// [excludeIds] are ids already placed on the board (so the backend
  /// doesn't suggest a duplicate), and [occasion] lets the backend keep
  /// suggestions consistent with the board's slot plan for that tab.
  ///
  /// Throws on any network / non-2xx error so the caller can fall back
  /// to the local wardrobe filter.
  static Future<List<_BackendBoardItemDto>> fetchReplacementCandidates({
    required WardrobeItem anchorItem,
    required List<WardrobeItem> wardrobe,
    required String occasion,
    required BoardDisplayItem currentItem,
    required bool similarOnly,
    required Set<String> excludeIds,
  }) async {
    final body = jsonEncode({
      'anchor': _wardrobeItemToJson(anchorItem),
      'wardrobe': wardrobe.map(_wardrobeItemToJson).toList(),
      'occasion': occasion,
      'currentItem': {
        'wardrobeItemId': currentItem.wardrobeItem?.id,
        'name': currentItem.name,
        'category': currentItem.cat,
      },
      'similarOnly': similarOnly,
      'excludeIds': excludeIds.toList(),
    });

    final response = await http.post(
      Uri.parse(_kReplaceEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Style board replace API returned ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidatesJson = (decoded['candidates'] as List?) ?? [];
    return candidatesJson
        .map((e) => _BackendBoardItemDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================
// AI STYLING SERVICE
// Owns Steps 1-4 of the "Style This" flow described in the AHVI spec.
//
// generateStyleBoards calls the real backend (StyleBoardBackendClient)
// and re-hydrates the response into BoardDisplayItem lists while
// guaranteeing:
//   • The anchor item is ALWAYS at position 0 of every board.
//   • Backend items that carry a known wardrobeItemId are re-hydrated
//     as WardrobeBoardItems (full model available for lock/replace).
//   • Items with no wardrobeItemId surface as AiRecommendedBoardItems.
//   • Style Board items are BACKEND-ONLY. There is no local wardrobe
//     heuristic fallback — if the backend call fails, the exception
//     propagates to the caller so the screen can show its error state
//     (wifi-off icon + retry), exactly like Replace / Find Similar.
//
// To swap for a different backend, change StyleBoardBackendClient only;
// everything else in this file stays the same.
// ============================================================
class StyleBoardAIService {
  static const List<String> occasions = ['casual', 'office', 'evening'];

  static const int maxItemsPerBoard = 8;

  /// Generates style boards anchored on [anchorItem].
  ///
  /// Flow:
  ///   1. Call the real backend (StyleBoardBackendClient.fetchBoards).
  ///   2. Re-hydrate the response via [_rehydrateBoards], which
  ///      guarantees the anchor item appears at position 0 in every
  ///      board regardless of what the backend returned.
  ///
  /// BACKEND-ONLY: there is no local heuristic fallback. If the
  /// backend call fails for any reason, the exception is left to
  /// propagate — the caller (StyleBoardsScreen) catches it and shows
  /// the error state with a retry button, instead of a board silently
  /// generated from the local wardrobe.
  ///
  /// [boardNameFor] resolves the localized tab/title text for an
  /// occasion key ('casual' | 'office' | 'evening').
  /// [aiFillNameFor] / [aiFillReasonFor] fill in a label/reason for
  /// backend items returned without a name. [slotLabelFor] is kept for
  /// call-site compatibility.
  static Future<List<StyleBoard>> generateStyleBoards({
    required WardrobeItem anchorItem,
    required List<WardrobeItem> wardrobe,
    required String Function(String occasion) boardNameFor,
    required String Function(ClothingSlot slot) slotLabelFor,
    required String Function(String label) aiFillNameFor,
    required String Function(String label) aiFillReasonFor,
  }) async {
    final dtos = await StyleBoardBackendClient.fetchBoards(
      anchorItem: anchorItem,
      wardrobe: wardrobe,
    );

    return _rehydrateBoards(
      dtos: dtos,
      anchorItem: anchorItem,
      wardrobe: wardrobe,
      boardNameFor: boardNameFor,
      aiFillNameFor: aiFillNameFor,
      aiFillReasonFor: aiFillReasonFor,
      slotLabelFor: slotLabelFor,
    );
  }

  /// Converts the raw backend DTOs into [StyleBoard] objects.
  ///
  /// ANCHOR GUARANTEE:
  ///   The selected item is always injected at index 0 of every board's
  ///   item list.  If the backend already included it (matched by id),
  ///   the duplicate is removed before the anchor is prepended, so it
  ///   appears exactly once — always first.
  static List<StyleBoard> _rehydrateBoards({
    required List<_BackendBoardDto> dtos,
    required WardrobeItem anchorItem,
    required List<WardrobeItem> wardrobe,
    required String Function(String occasion) boardNameFor,
    required String Function(String label) aiFillNameFor,
    required String Function(String label) aiFillReasonFor,
    required String Function(ClothingSlot slot) slotLabelFor,
  }) {
    // Build a fast lookup: wardrobeItemId → WardrobeItem.
    final wardrobeById = {for (final w in wardrobe) w.id: w};

    // Ensure every occasion has a board, even if the backend omitted one.
    final dtoByOccasion = {for (final d in dtos) d.occasion: d};

    return [
      for (final occasion in occasions)
        _rehydrateBoard(
          dto: dtoByOccasion[occasion],
          occasion: occasion,
          anchorItem: anchorItem,
          wardrobeById: wardrobeById,
          boardName: boardNameFor(occasion),
          aiFillNameFor: aiFillNameFor,
          aiFillReasonFor: aiFillReasonFor,
          slotLabelFor: slotLabelFor,
        ),
    ];
  }

  static StyleBoard _rehydrateBoard({
    required _BackendBoardDto? dto,
    required String occasion,
    required WardrobeItem anchorItem,
    required Map<String, WardrobeItem> wardrobeById,
    required String boardName,
    required String Function(String label) aiFillNameFor,
    required String Function(String label) aiFillReasonFor,
    required String Function(ClothingSlot slot) slotLabelFor,
  }) {
    // If the backend returned no board for this occasion, produce an
    // anchor-only placeholder so the tab is never empty.
    if (dto == null) {
      return StyleBoard(
        id: occasion,
        name: boardName,
        occasion: occasion,
        items: [WardrobeBoardItem(anchorItem, matchScore: 1.0)],
        thumbnail: anchorItem.displayUrl ?? '',
      );
    }

    // Re-hydrate backend items, skipping any that duplicate the anchor.
    final rehydrated = <BoardDisplayItem>[];
    for (final itemDto in dto.items) {
      // Skip if this is the anchor — we'll prepend it explicitly below.
      if (itemDto.wardrobeItemId == anchorItem.id) continue;

      if (itemDto.wardrobeItemId != null &&
          wardrobeById.containsKey(itemDto.wardrobeItemId)) {
        // Known wardrobe item: use the full local model.
        final wardrobeItem = wardrobeById[itemDto.wardrobeItemId]!;
        rehydrated.add(WardrobeBoardItem(wardrobeItem, matchScore: 0.85));
      } else {
        // AI-suggested item not in the wardrobe.
        rehydrated.add(AiRecommendedBoardItem(
          id: 'ai_${occasion}_${itemDto.name}_${DateTime.now().microsecondsSinceEpoch}',
          name: itemDto.name.isNotEmpty
              ? itemDto.name
              : aiFillNameFor(itemDto.category),
          cat: itemDto.category,
          displayUrl: itemDto.imageUrl,
          matchScore: 0.75,
          reason: aiFillReasonFor(itemDto.category),
        ));
      }
    }

    // ANCHOR GUARANTEE: selected item is always first, always present.
    final rawItems = [
      WardrobeBoardItem(anchorItem, matchScore: 1.0),
      ...rehydrated,
    ].take(maxItemsPerBoard).toList();

    // PLACEMENT RULES: reorder so the grid layout receives items in the
    // correct slot order (anchor → bottomwear → second topwear → shoes →
    // watch → pocket square → belt → bag → wallet).
    final items = _applyPlacementRules(rawItems);

    return StyleBoard(
      id: occasion,
      name: boardName,
      occasion: occasion,
      items: items,
      thumbnail: anchorItem.displayUrl ?? '',
    );
  }

  // ============================================================
  // PLACEMENT RULES
  // Reorders a list of BoardDisplayItems so the adaptive grid layout
  // (_buildAdaptiveBoard / _buildRightSide) always receives items in
  // the correct slot positions:
  //
  //   Position 0  — Top Left   : anchor (selected item, always)
  //   Position 1  — Bottom Left: first Bottomwear item
  //   Position 2+ — Right side : second Topwear (if any), then Shoes,
  //                              Watch, Pocket Square, Belt, Bag, Wallet,
  //                              and any remaining items.
  //
  // The anchor at position 0 is guaranteed by _rehydrateBoard before
  // this method is called and is never moved.
  //
  // Category matching is keyword-based (case-insensitive) so it works
  // equally well for WardrobeBoardItems and AiRecommendedBoardItems.
  // ============================================================
  static List<BoardDisplayItem> _applyPlacementRules(
      List<BoardDisplayItem> items) {
    if (items.isEmpty) return items;

    // Position 0 is always the anchor — do not touch it.
    final anchor = items.first;
    final rest = items.skip(1).toList();

    // ── Category helpers ──────────────────────────────────────
    bool _isBottomwear(BoardDisplayItem i) {
      final c = i.cat.toLowerCase();
      return c.contains('bottom') ||
          c.contains('pant') ||
          c.contains('jean') ||
          c.contains('trouser') ||
          c.contains('skirt') ||
          c.contains('short') ||
          c.contains('chino');
    }

    bool _isTopwear(BoardDisplayItem i) {
      final c = i.cat.toLowerCase();
      return c.contains('top') ||
          c.contains('shirt') ||
          c.contains('tee') ||
          c.contains('blouse') ||
          c.contains('sweater') ||
          c.contains('jumper') ||
          c.contains('jacket') ||
          c.contains('coat') ||
          c.contains('hoodie') ||
          c.contains('outerwear') ||
          c.contains('blazer') ||
          c.contains('suit');
    }

    // Priority order for right-side slots (lower index = higher priority).
    const _rightSidePriority = [
      'shoe', 'footwear', 'sneaker', 'boot', 'heel', 'loafer', 'sandal', // shoes
      'watch',                                                              // watch
      'pocket square', 'handkerchief',                                     // pocket square
      'belt',                                                               // belt
      'bag', 'purse', 'tote', 'backpack', 'clutch',                        // bag
      'wallet',                                                             // wallet
    ];

    int _rightSideRank(BoardDisplayItem i) {
      final c = i.cat.toLowerCase();
      for (int r = 0; r < _rightSidePriority.length; r++) {
        if (c.contains(_rightSidePriority[r])) return r;
      }
      return _rightSidePriority.length; // unknown → append at end
    }

    // ── Partition ─────────────────────────────────────────────
    // Identify the first Bottomwear item (Bottom Left slot).
    BoardDisplayItem? bottomwear;
    final remaining = <BoardDisplayItem>[];

    for (final item in rest) {
      if (bottomwear == null && _isBottomwear(item)) {
        bottomwear = item;
      } else {
        remaining.add(item);
      }
    }

    // ── Right-side ordering ───────────────────────────────────
    // Pull out extra Topwear items first (they take the first right-side
    // slot(s)), then sort everything else by priority.
    final extraTopwear = <BoardDisplayItem>[];
    final accessories = <BoardDisplayItem>[];

    for (final item in remaining) {
      if (_isTopwear(item)) {
        extraTopwear.add(item);
      } else {
        accessories.add(item);
      }
    }

    accessories.sort((a, b) => _rightSideRank(a).compareTo(_rightSideRank(b)));

    // ── Assemble final list ───────────────────────────────────
    final ordered = <BoardDisplayItem>[
      anchor,
      if (bottomwear != null) bottomwear,
      ...extraTopwear,
      ...accessories,
    ];

    return ordered;
  }

  /// Converts backend replace/find-similar candidate DTOs into
  /// [BoardDisplayItem]s for the item picker sheet — known
  /// wardrobeItemIds re-hydrate to the full [WardrobeItem] model,
  /// anything else surfaces as an [AiRecommendedBoardItem] (a
  /// backend-suggested piece not currently in the wardrobe).
  static List<BoardDisplayItem> rehydrateCandidates({
    required List<_BackendBoardItemDto> dtos,
    required List<WardrobeItem> wardrobe,
    required String occasion,
  }) {
    final wardrobeById = {for (final w in wardrobe) w.id: w};

    return [
      for (final dto in dtos)
        if (dto.wardrobeItemId != null &&
            wardrobeById.containsKey(dto.wardrobeItemId))
          WardrobeBoardItem(wardrobeById[dto.wardrobeItemId]!,
              matchScore: 0.85)
        else
          AiRecommendedBoardItem(
            id: 'ai_replace_${occasion}_${dto.name}_${DateTime.now().microsecondsSinceEpoch}',
            name: dto.name.isNotEmpty ? dto.name : dto.category,
            cat: dto.category,
            displayUrl: dto.imageUrl,
            matchScore: 0.75,
            reason: '',
          ),
    ];
  }

}

// ============================================================
// MAIN SCREEN
// ============================================================
class StyleBoardsScreen extends StatefulWidget {
  final WardrobeItem selectedItem;
  final List<WardrobeItem> allItems;
  final VoidCallback? onStyleSelected;
  final VoidCallback? onItemReplaced;

  const StyleBoardsScreen({
    required this.selectedItem,
    required this.allItems,
    this.onStyleSelected,
    this.onItemReplaced,
  });

  @override
  State<StyleBoardsScreen> createState() => _StyleBoardsScreenState();
}

class _StyleBoardsScreenState extends State<StyleBoardsScreen> {
  List<StyleBoard> styleBoards = [];
  List<BoardHistory> boardHistory = [];
  int selectedBoardIndex = 0;
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
      _loadStyleBoards();
    }
  }

  /// Localized display label for a [ClothingSlot] — reuses the same
  /// `clothingSlot*` keys already used elsewhere in the app for this
  /// enum (wardrobe category filters, etc.) so the AI-recommended
  /// placeholder cards ("Top", "Bag", …) stay consistent app-wide.
  String _slotLabelFor(BuildContext context, ClothingSlot slot) {
    switch (slot) {
      case ClothingSlot.top:
        return AppLocalizations.t(context, 'clothingSlotTop');
      case ClothingSlot.bottom:
        return AppLocalizations.t(context, 'clothingSlotBottom');
      case ClothingSlot.dress:
        return AppLocalizations.t(context, 'clothingSlotDress');
      case ClothingSlot.outerwear:
        return AppLocalizations.t(context, 'clothingSlotOuterwear');
      case ClothingSlot.footwear:
        return AppLocalizations.t(context, 'clothingSlotFootwear');
      case ClothingSlot.bag:
        return AppLocalizations.t(context, 'clothingSlotBag');
      case ClothingSlot.accessory:
        return AppLocalizations.t(context, 'clothingSlotAccessory');
      case ClothingSlot.other:
        return AppLocalizations.t(context, 'clothingSlotOther');
    }
  }

  /// Localized name for an AI-recommended placeholder card, e.g.
  /// "Top pick" — [label] is the already-localized slot label.
  String _aiFillNameFor(BuildContext context, String label) {
    return AppLocalizations.t(context, 'style_boards_ai_fill_name')
        .replaceAll('{slot}', label);
  }

  /// Localized reason text for an AI-recommended placeholder card,
  /// e.g. "No matching Top in your wardrobe for this look".
  String _aiFillReasonFor(BuildContext context, String label) {
    return AppLocalizations.t(context, 'style_boards_ai_fill_reason')
        .replaceAll('{slot}', label);
  }

  // ── Data fetching (AI flow) ──────────────────────────────────

  Future<void> _loadStyleBoards() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final boards = await StyleBoardAIService.generateStyleBoards(
        anchorItem: widget.selectedItem,
        wardrobe: widget.allItems,
        boardNameFor: (occasion) {
          switch (occasion) {
            case 'casual':
              return AppLocalizations.t(context, 'style_boards_board_name_1');
            case 'office':
              return AppLocalizations.t(context, 'style_boards_board_name_2');
            default:
              return AppLocalizations.t(context, 'style_boards_board_name_3');
          }
        },
        slotLabelFor: (slot) => _slotLabelFor(context, slot),
        aiFillNameFor: (label) => _aiFillNameFor(context, label),
        aiFillReasonFor: (label) => _aiFillReasonFor(context, label),
      );

      if (!mounted) return;
      setState(() {
        styleBoards = boards;
        selectedBoardIndex = 0;
        lockedItemIds.clear();
        boardHistory = boards
            .map((b) => BoardHistory(
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
        _loadError = AppLocalizations.t(context, 'style_boards_load_error');
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

  /// Requests a fresh variation from the backend for the currently
  /// selected occasion, preserving any locked items.
  ///
  /// The backend already handles slot diversity and compatibility
  /// scoring, so we no longer derive candidates from the local wardrobe.
  /// Locked items are passed as hints so the backend can work around them.
  Future<void> _shuffleUnlockedPieces() async {
    final board = styleBoards[selectedBoardIndex];

    // Snapshot the locked items so the UI shows them as fixed while
    // the new variation is loading (the grid becomes non-interactive
    // via the _isLoading flag we set below).
    final lockedSnapshot = Set<String>.from(lockedItemIds);

    setState(() => _isLoading = true);

    try {
      final dtos = await StyleBoardBackendClient.fetchBoards(
        anchorItem: widget.selectedItem,
        wardrobe: widget.allItems,
      );

      if (!mounted) return;

      // Pick the DTO for the currently displayed occasion.
      final occasionDto = dtos.firstWhere(
            (d) => d.occasion == board.occasion,
        orElse: () => _BackendBoardDto(occasion: board.occasion, items: []),
      );

      // Re-hydrate the new variation while honouring locked items:
      // any slot whose id is in lockedSnapshot keeps its current entry;
      // every other slot is replaced by what the backend returned.
      final wardrobeById = {for (final w in widget.allItems) w.id: w};

      final newItems = <BoardDisplayItem>[
        // Anchor is always first and never shuffled.
        WardrobeBoardItem(widget.selectedItem, matchScore: 1.0),
      ];

      // Build a lookup of the current board's locked entries (by id)
      // so we can reuse the full BoardDisplayItem object for them.
      final lockedEntries = {
        for (final e in board.items)
          if (lockedSnapshot.contains(e.id) && e.id != widget.selectedItem.id) e.id: e,
      };

      // Append locked items first so their positions are stable.
      newItems.addAll(lockedEntries.values);

      // Fill remaining slots from the backend response (skip anchor
      // duplicates and any id already accounted for by a locked entry).
      for (final dto in occasionDto.items) {
        if (newItems.length >= StyleBoardAIService.maxItemsPerBoard) break;
        if (dto.wardrobeItemId == widget.selectedItem.id) continue;
        if (dto.wardrobeItemId != null && lockedEntries.containsKey(dto.wardrobeItemId)) continue;

        if (dto.wardrobeItemId != null && wardrobeById.containsKey(dto.wardrobeItemId)) {
          newItems.add(WardrobeBoardItem(wardrobeById[dto.wardrobeItemId]!, matchScore: 0.85));
        } else {
          newItems.add(AiRecommendedBoardItem(
            id: 'ai_${board.occasion}_${dto.name}_${DateTime.now().microsecondsSinceEpoch}',
            name: dto.name.isNotEmpty ? dto.name : dto.category,
            cat: dto.category,
            displayUrl: dto.imageUrl,
            matchScore: 0.75,
            reason: '',
          ));
        }
      }

      final now = DateTime.now();
      // Apply placement rules so the grid always receives items in the
      // correct slot order even after a shuffle (anchor → bottomwear →
      // extra topwear → shoes → watch → pocket square → belt → bag → wallet).
      final orderedItems = StyleBoardAIService._applyPlacementRules(
        newItems.take(StyleBoardAIService.maxItemsPerBoard).toList(),
      );
      final updatedBoard = StyleBoard(
        id: board.id,
        name: board.name,
        occasion: board.occasion,
        items: orderedItems,
        thumbnail: board.thumbnail,
        createdAt: now,
      );

      setState(() {
        styleBoards[selectedBoardIndex] = updatedBoard;
        lockedItemIds = lockedSnapshot; // restore locks after the update
        boardHistory.insert(
          0,
          BoardHistory(
            id: 'h_${now.millisecondsSinceEpoch}',
            occasion: board.occasion,
            items: updatedBoard.items,
            createdAt: now,
          ),
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // On failure restore the previous board so the user isn't left
      // with an empty screen; error toast / snackbar can be added here.
      setState(() => _isLoading = false);
    }
  }

  void _unlockAll() => setState(() => lockedItemIds.clear());

  /// Restores a history snapshot into the currently-selected occasion
  /// board (Casual/Office/Evening), instead of always overwriting the
  /// first board regardless of which tab is open.
  void _switchBoard(int historyIndex) {
    setState(() {
      final h = boardHistory[historyIndex];
      final board = styleBoards[selectedBoardIndex];

      styleBoards[selectedBoardIndex] = StyleBoard(
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
    final item = styleBoards[selectedBoardIndex]
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
          isAnchor: item.id == widget.selectedItem.id,
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
    // Never allow the anchor item to be replaced — it must always stay
    // in the board as the item the user originally tapped "Style This" on.
    if (oldId == widget.selectedItem.id) return;
    setState(() {
      final board = styleBoards[selectedBoardIndex];
      final idx = board.items.indexWhere((i) => i.id == oldId);
      if (idx == -1) return;

      final updated = List<BoardDisplayItem>.from(board.items)..[idx] = newItem;
      lockedItemIds.remove(oldId);

      final now = DateTime.now();

      styleBoards[selectedBoardIndex] = StyleBoard(
        id: board.id,
        name: board.name,
        occasion: board.occasion,
        items: updated,
        thumbnail: board.thumbnail,
        createdAt: board.createdAt,
      );

      boardHistory.insert(
        0,
        BoardHistory(
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

  /// Opens the Replace / Find Similar sheet and fills it with backend
  /// candidates.
  ///
  /// The sheet is shown immediately in a loading state (via
  /// [pickerState], a ValueNotifier watched by the builder below) so
  /// the user gets instant feedback, then StyleBoardBackendClient
  /// .fetchReplacementCandidates resolves the real list — [similarOnly]
  /// tells the backend whether this is "find similar" (close matches
  /// only) or a general "replace" pool.
  ///
  /// There is intentionally NO local-wardrobe fallback: candidates come
  /// from the backend only. If the request fails, the sheet shows an
  /// error state with a retry action instead of silently substituting
  /// locally-filtered wardrobe items.
  Future<void> _openItemPicker(BoardDisplayItem current,
      {required bool similarOnly}) async {
    final board = styleBoards[selectedBoardIndex];
    final usedIds = board.items.map((i) => i.id).toSet();

    final pickerState = ValueNotifier<_PickerLoadState>(
      const _PickerLoadState.loading(),
    );

    Future<void> load() async {
      pickerState.value = const _PickerLoadState.loading();
      try {
        final dtos = await StyleBoardBackendClient.fetchReplacementCandidates(
          anchorItem: widget.selectedItem,
          wardrobe: widget.allItems,
          occasion: board.occasion,
          currentItem: current,
          similarOnly: similarOnly,
          excludeIds: usedIds,
        );
        final resolved = StyleBoardAIService.rehydrateCandidates(
          dtos: dtos,
          wardrobe: widget.allItems,
          occasion: board.occasion,
        );
        pickerState.value = _PickerLoadState.loaded(resolved);
      } catch (_) {
        // Backend unavailable — surface an error state. No local
        // wardrobe fallback: candidates are backend-only.
        pickerState.value = const _PickerLoadState.error();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<_PickerLoadState>(
        valueListenable: pickerState,
        builder: (_, state, __) => _ItemPickerSheet(
          title: similarOnly
              ? AppLocalizations.t(context, 'style_boards_find_similar_title')
              : AppLocalizations.t(context, 'style_boards_replace_title'),
          isLoading: state.isLoading,
          hasError: state.hasError,
          candidates: state.candidates,
          onPicked: (picked) {
            Navigator.pop(ctx);
            _replaceItem(current.id, picked);
          },
          onRetry: load,
        ),
      ),
    );

    await load();
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
      body: _loadError != null
          ? _buildErrorState(context, t)
          : _isLoading
          ? _buildLoadingState(context, t)
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
                    // Grid container background matches the main Style Board background
                    // for a seamless, consistent look with no visible color difference.
                    decoration: BoxDecoration(
                      color: t.backgroundPrimary,
                      border: Border.all(color: t.cardBorder, width: 1.0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _buildSourceLegend(context, t),
                        _buildUnifiedGrid(
                            context, t, styleBoards[selectedBoardIndex].items),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildControlButtons(context, t),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _buildBoardHistorySection(context, t),
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
            AppLocalizations.t(context, 'style_boards_title'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          Text(
            _isLoading || _loadError != null || styleBoards.isEmpty
                ? ''
                : styleBoards[selectedBoardIndex].name,
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
    // Show a full skeleton that mirrors the real board layout so the UI
    // feels instantaneous: occasion tab chips + a 6-item grid skeleton +
    // control buttons, all shimmering with an animated opacity pulse.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Skeleton occasion tabs ─────────────────────────────────
            _SkeletonRow(
              children: [
                _SkeletonChip(width: 80, t: t),
                const SizedBox(width: 8),
                _SkeletonChip(width: 72, t: t),
                const SizedBox(width: 8),
                _SkeletonChip(width: 84, t: t),
              ],
            ),
            const SizedBox(height: 12),
            // ── Skeleton grid (6-item layout mirrors the real board) ───
            Container(
              decoration: BoxDecoration(
                color: t.backgroundPrimary,
                border: Border.all(color: t.cardBorder, width: 1.0),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(10),
              child: _SkeletonGrid(t: t),
            ),
            const SizedBox(height: 20),
            // ── Skeleton control buttons ───────────────────────────────
            Row(
              children: [
                Expanded(child: _SkeletonBox(height: 44, t: t)),
                const SizedBox(width: 12),
                Expanded(child: _SkeletonBox(height: 44, t: t)),
              ],
            ),
            const SizedBox(height: 28),
            // ── Skeleton history header + single card ──────────────────
            _SkeletonBox(height: 16, width: 120, t: t),
            const SizedBox(height: 12),
            _SkeletonBox(height: 110, t: t),
          ],
        ),
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
              onTap: _loadStyleBoards,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  AppLocalizations.t(context, 'style_boards_retry'),
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
  // Properly aligned chips with consistent spacing and wrapping support.

  Widget _buildOccasionTabs(BuildContext context, AppThemeTokens t) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: List.generate(styleBoards.length, (i) {
        final isSelected = i == selectedBoardIndex;
        return GestureDetector(
          onTap: () => setState(() {
            selectedBoardIndex = i;
            lockedItemIds.clear();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? t.accent.primary : t.backgroundSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? t.accent.primary : t.cardBorder,
              ),
            ),
            child: Text(
              styleBoards[i].name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : t.textPrimary,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Wardrobe vs AI-recommended legend ───────────────────────────

  Widget _buildSourceLegend(BuildContext context, AppThemeTokens t) {
    final hasAiItems = styleBoards[selectedBoardIndex].items.any((i) => i.isAiRecommended);
    if (!hasAiItems) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          _legendDot(t.accent.primary),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.t(context, 'style_boards_legend_wardrobe'),
            style: GoogleFonts.inter(fontSize: 11, color: t.mutedText),
          ),
          const SizedBox(width: 16),
          _legendDot(Colors.amber),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.t(context, 'style_boards_legend_ai'),
            style: GoogleFonts.inter(fontSize: 11, color: t.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  // ============================================================
  // LAYOUT DISPATCHER
  // Picks the exact sketch layout based on item count (1–8).
  //
  // GRID ITEM LIMITS & SPACING:
  //   - Minimum: 1 item (centered, no empty spaces)
  //   - Maximum: 8 items (no more than 8 shown)
  //   - If >8 items generated, only first 8 are displayed (take(8))
  //   - If <8 items available, layout adapts to show only what exists
  //   - No empty/placeholder cells are shown for missing items
  //   - All items maintain equal spacing & alignment per layout
  //
  // LAYOUT STRATEGY BY ITEM COUNT:
  //   1-2 items: Centered, equal-width columns
  //   3 items:   Asymmetric (large left, 2 stacked right)
  //   4 items:   2×2 grid
  //   5 items:   Mixed (large top-left, medium top-right, 3 bottom)
  //   6 items:   2×3 grid (two rows of three)
  //   7 items:   3-column layout (2+3+2 distribution)
  //   8 items:   3-column layout (3+3+2 distribution)
  //
  // Each layout is optimized for visual balance and maintains
  // consistent spacing (default 10px gap) between items.
  // ============================================================

  static const double _kGap = 10.0;

  // Caps how large any single grid cell in the 1/2/3/4-item layouts can
  // grow. Those layouts use half-width (or bigger) cells, which made
  // boards with only a few items look oversized on typical phone
  // widths. 5/6/7/8-item layouts already divide into three columns and
  // stay compact on their own, so they're left as-is.
  static const double _kMaxCardExtent = 140.0;

  double _cappedCellWidth(double totalWidth, double gap, int columns) {
    final raw = (totalWidth - gap * (columns - 1)) / columns;
    return raw < _kMaxCardExtent ? raw : _kMaxCardExtent;
  }

  Widget _buildUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    switch (items.length) {
      case 1:
      case 2:
        return _layoutSmall(context, t, items);
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 8:
        return _buildAdaptiveBoard(
            items, _kGap, (item) => _buildItemCard(context, item, t));
      default:
      // Maximum 8 items displayed; truncate if more are provided
        return _buildAdaptiveBoard(items.take(8).toList(), _kGap,
                (item) => _buildItemCard(context, item, t));
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
              childAspectRatio: 1.15,
            ),
            itemCount: n,
            itemBuilder: (_, i) => _buildItemCard(context, items[i], t),
          ),
        ),
      );
    });
  }

  // ─── Adaptive board (3–8 items) ────────────────────────────────────────
  // AHVI style-board layout spec: Topwear (items[0], always the anchor —
  // the selected wardrobe item — pinned to the top-left position) and
  // Bottomwear (items[1]) always sit stacked at equal height on the left,
  // regardless of item count or category. Only the right-side layout
  // adapts to the number of remaining items (3–8 total). Spacing, card
  // sizing, and the left-side structure are identical across every count
  // so the board reads as one consistent editorial template.
  Widget _buildAdaptiveBoard(List<BoardDisplayItem> items, double gap,
      Widget Function(BoardDisplayItem item) card) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      final g = gap;

      // Left and right columns are equal width; each Topwear/Bottomwear
      // cell is a square (colW × colW), so the total board height is
      // driven by that left-side stack — every right-side sub-layout
      // fills exactly this height.
      final colW = _cappedCellWidth(w, g, 2);
      final totalH = colW * 2 + g;

      final left = SizedBox(
        width: colW,
        height: totalH,
        child: Column(
          children: [
            SizedBox(height: colW, child: card(items[0])), // Topwear (anchor)
            SizedBox(height: g),
            SizedBox(height: colW, child: card(items[1])), // Bottomwear
          ],
        ),
      );

      final right = SizedBox(
        width: colW,
        height: totalH,
        child: _buildRightSide(items, colW, totalH, g, card),
      );

      return Center(
        child: SizedBox(
          width: colW * 2 + g,
          height: totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              SizedBox(width: g),
              right,
            ],
          ),
        ),
      );
    });
  }

  // Right-side layout for each item count, per the AHVI style-board
  // layout spec (PDF). Item order after the anchor/Topwear (0) and
  // Bottomwear (1):
  //   3: [Shoes]
  //   4: [Shoes, Watch]
  //   5: [Shoes, Watch, Pocket Square]
  //   6: [Shoes, Watch, Pocket Square, Belt]
  //   7: [Shoes, Watch, Pocket Square, Belt, Bag]
  //   8: [Shoes, Watch, Pocket Square, Belt, Bag, Wallet]
  Widget _buildRightSide(List<BoardDisplayItem> items, double colW,
      double totalH, double g, Widget Function(BoardDisplayItem item) card) {
    Widget pairRow(BoardDisplayItem a, BoardDisplayItem b, double h) {
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(child: card(a)),
            SizedBox(width: g),
            Expanded(child: card(b)),
          ],
        ),
      );
    }

    switch (items.length) {
      case 3: {
        // Single item spans the full right-side height.
        return card(items[2]);
      }

      case 4: {
        // Two items stacked, splitting the full height evenly.
        final rowH = (totalH - g) / 2;
        return Column(
          children: [
            SizedBox(height: rowH, child: card(items[2])),
            SizedBox(height: g),
            SizedBox(height: rowH, child: card(items[3])),
          ],
        );
      }

      case 5: {
        // Top: one item aligned with Topwear's row height.
        // Bottom: two items side by side, aligned with Bottomwear's row.
        return Column(
          children: [
            SizedBox(height: colW, child: card(items[2])),
            SizedBox(height: g),
            SizedBox(height: colW, child: pairRow(items[3], items[4], colW)),
          ],
        );
      }

      case 6: {
        // Top: one item (Topwear row height).
        // Bottom (Bottomwear row height), split into two sub-rows:
        // a pair, then a single item spanning the full width.
        final subH = (colW - g) / 2;
        return Column(
          children: [
            SizedBox(height: colW, child: card(items[2])),
            SizedBox(height: g),
            SizedBox(
              height: colW,
              child: Column(
                children: [
                  pairRow(items[3], items[4], subH),
                  SizedBox(height: g),
                  SizedBox(height: subH, child: card(items[5])),
                ],
              ),
            ),
          ],
        );
      }

      case 7: {
        // Top: one item (Topwear row height).
        // Bottom (Bottomwear row height): two pairs stacked.
        final subH = (colW - g) / 2;
        return Column(
          children: [
            SizedBox(height: colW, child: card(items[2])),
            SizedBox(height: g),
            SizedBox(
              height: colW,
              child: Column(
                children: [
                  pairRow(items[3], items[4], subH),
                  SizedBox(height: g),
                  pairRow(items[5], items[6], subH),
                ],
              ),
            ),
          ],
        );
      }

      case 8:
      default: {
        // Top: one item (Topwear row height).
        // Bottom (Bottomwear row height): two pairs, then a single item
        // spanning the full width.
        final subH = (colW - 2 * g) / 3;
        return Column(
          children: [
            SizedBox(height: colW, child: card(items[2])),
            SizedBox(height: g),
            SizedBox(
              height: colW,
              child: Column(
                children: [
                  pairRow(items[3], items[4], subH),
                  SizedBox(height: g),
                  pairRow(items[5], items[6], subH),
                  SizedBox(height: g),
                  SizedBox(height: subH, child: card(items[7])),
                ],
              ),
            ),
          ],
        );
      }
    }
  }

  Widget _buildItemCard(BuildContext context, BoardDisplayItem item, AppThemeTokens t) {
    final isLocked = lockedItemIds.contains(item.id);
    // The anchor is the originally selected wardrobe item that triggered
    // "Style This".  It is always position 0 in the board and must never
    // be removed, replaced, or unlocked by the user.
    final isAnchor = item.id == widget.selectedItem.id;

    // Anchor gets a distinct accent border; locked items get the same
    // border (they use accent.primary too); plain items get none.
    final borderColor = (isAnchor || isLocked) ? t.accent.primary : Colors.transparent;

    return GestureDetector(
      onTap: () => _selectItem(item.id),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
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
                fit: BoxFit.contain,
              ),
            )
                : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isAiRecommended ? Icons.auto_awesome : Icons.checkroom,
                    color: item.isAiRecommended ? Colors.amber : t.mutedText,
                    size: 28,
                  ),
                  if (item.isAiRecommended) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.cat,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 9, color: t.mutedText),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── Anchor badge (top-left, accent colour) ─────────────
            // Shown instead of the AI-pick badge when this card is the
            // item the user tapped "Style This" on.
            if (isAnchor)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accent.primary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.t(context, 'style_boards_anchor_badge'),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (item.isAiRecommended && !isAnchor)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.t(context, 'style_boards_ai_pick_badge'),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
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
                    AppLocalizations.t(context, 'style_boards_locked_badge'),
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

  Widget _buildBoardHistorySection(BuildContext context, AppThemeTokens t) {
    // Show only history entries that match the currently selected occasion tab
    final currentOccasion = styleBoards.isNotEmpty
        ? styleBoards[selectedBoardIndex].occasion
        : '';
    final filteredHistory = boardHistory
        .where((h) => h.occasion == currentOccasion)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "BOARD HISTORY" header — matches screenshot style (bold uppercase)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppLocalizations.t(context, 'style_boards_history_title'),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: t.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filteredHistory.isEmpty)
        // Empty state wrapped in the same bordered container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: t.cardBorder, width: 1.0),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.t(context, 'style_boards_no_history'),
                style: GoogleFonts.inter(fontSize: 13, color: t.mutedText),
              ),
            ),
          )
        else
        // Horizontal scrollable list of board history cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(filteredHistory.length, (i) {
                final h = filteredHistory[i];
                final isCurrent = i == 0;

                return Padding(
                  padding: EdgeInsets.only(
                    right: i == filteredHistory.length - 1 ? 0 : 12,
                  ),
                  // Board History cards are intentionally capped to a
                  // fixed max width — smaller than the main board's
                  // container — so they always read as compact
                  // previews, regardless of item count or layout.
                  child: ConstrainedBox(
                    constraints:
                    const BoxConstraints(maxWidth: _kHistoryCardMaxWidth),
                    child: GestureDetector(
                      onTap: () {
                        final realIndex = boardHistory.indexOf(h);
                        _switchBoard(realIndex);
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header row: timestamp label + current indicator
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
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
                                const SizedBox(width: 8),
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
                );
              }),
            ),
          ),
      ],
    );
  }

  // ── History mini-grid ────────────────────────────────────────
  // Renders the same layout as the main board but with cards that
  // have no interactive chrome (no lock icon, no AI badge tap).
  // Uses a FractionallySizedBox to constrain the grid to a compact
  // preview height without hard-coding pixel values.

  Widget _buildHistoryGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Scale factor: history cards are rendered at ~55% the width of
    // the main board area (accounting for the outer 16px side padding
    // and the card's own 10px internal padding on both sides).
    // Rather than re-computing exact pixel widths, we use a
    // LayoutBuilder inside each layout — the same _buildUnifiedGrid
    // family already does this — so we simply call it with a wrapper
    // that makes the widget non-interactive and visually quiet.
    return _buildHistoryUnifiedGrid(context, t, items);
  }

  Widget _buildHistoryUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // History grids follow the same layout logic as the main board grids,
    // supporting 1-8 items max with adaptive layouts for each count.
    // Maintains equal spacing (6px history gap) and alignment consistent
    // with main board while rendering at compact preview size.
    switch (items.length) {
      case 1:
      case 2:
        return _historyLayoutSmall(context, t, items);
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 8:
        return _buildAdaptiveBoard(
            items, _kHGap, (item) => _buildHistoryItemCard(context, item, t));
      default:
      // Maximum 8 items in history preview; truncate if more provided
        return _buildAdaptiveBoard(items.take(8).toList(), _kHGap,
                (item) => _buildHistoryItemCard(context, item, t));
    }
  }

  static const double _kHGap = 6.0; // tighter gap for the mini preview

  // Board History cards are always rendered smaller than the main
  // board — this caps their overall width regardless of layout (A, B,
  // or otherwise), so they read as compact previews rather than
  // full-size boards.
  static const double _kHistoryCardMaxWidth = 150.0;

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
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.checkroom, color: t.mutedText, size: 14),
          ),
        ),
      )
          : Center(
        child: Icon(
          item.isAiRecommended ? Icons.auto_awesome : Icons.checkroom,
          color: item.isAiRecommended ? Colors.amber : t.mutedText,
          size: 14,
        ),
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

}

// ============================================================
// ITEM DETAILS PANEL
// ============================================================
class _SelectedItemPanel extends StatelessWidget {
  final BoardDisplayItem item;
  final bool isLocked;
  final bool isAnchor;
  final VoidCallback onToggleLock;
  final VoidCallback onReplace;
  final VoidCallback? onFindSimilar;

  const _SelectedItemPanel({
    required this.item,
    required this.isLocked,
    required this.isAnchor,
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
                          item.isAiRecommended ? Icons.auto_awesome : Icons.checkroom,
                          color: item.isAiRecommended ? Colors.amber : t.mutedText,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name.isNotEmpty ? item.name : item.cat,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                          ),
                          if (item.isAiRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppLocalizations.t(context, 'style_boards_ai_pick_badge'),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                        ],
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
                      // Anchor item is fixed — hide mutating actions and
                      // show an explanatory note instead.
                      if (isAnchor) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: t.accent.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: t.accent.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.push_pin_outlined,
                                  color: t.accent.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppLocalizations.t(context,
                                      'style_boards_anchor_note'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: t.accent.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
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
                      ],
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
// PICKER LOAD STATE
// Tiny state holder for the Replace / Find Similar sheet: loading,
// loaded (with backend candidates), or errored (backend call failed —
// there is no local wardrobe fallback, so this is a real dead end that
// the sheet must show and offer a retry for).
// ============================================================
class _PickerLoadState {
  final bool isLoading;
  final bool hasError;
  final List<BoardDisplayItem> candidates;

  const _PickerLoadState.loading()
      : isLoading = true,
        hasError = false,
        candidates = const [];

  const _PickerLoadState.error()
      : isLoading = false,
        hasError = true,
        candidates = const [];

  const _PickerLoadState.loaded(this.candidates)
      : isLoading = false,
        hasError = false;
}

// ============================================================
// ITEM PICKER SHEET (Replace / Find Similar)
//
// Candidates now come from StyleBoardBackendClient.fetchReplacementCandidates
// (backend-scored replace / find-similar suggestions), with a local
// wardrobe-filter fallback if that call fails. Because the backend can
// suggest items that aren't in the wardrobe yet, candidates are
// BoardDisplayItem (covers both WardrobeBoardItem and
// AiRecommendedBoardItem) rather than raw WardrobeItem — picking either
// kind is handed straight back to _replaceItem.
//
// isLoading shows a skeleton grid while the backend request for this
// sheet is in flight; the same sheet instance is then rebuilt with the
// resolved candidates.
// ============================================================
class _ItemPickerSheet extends StatelessWidget {
  final String title;
  final bool isLoading;
  final List<BoardDisplayItem> candidates;
  final ValueChanged<BoardDisplayItem> onPicked;
  final bool hasError;
  final VoidCallback? onRetry;

  const _ItemPickerSheet({
    required this.title,
    required this.candidates,
    required this.onPicked,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
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
            child: hasError
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        color: t.mutedText, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.t(
                          context, 'style_boards_picker_load_error'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: t.mutedText),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: onRetry,
                        child: Text(
                          AppLocalizations.t(
                              context, 'style_boards_retry'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
                : isLoading
                ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: 9,
              itemBuilder: (_, __) => _SkeletonPulse(
                child: Container(
                  decoration: BoxDecoration(
                    color: t.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.cardBorder),
                  ),
                ),
              ),
            )
                : candidates.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.t(
                      context, 'style_boards_no_items_to_swap'),
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
                childAspectRatio: 1.0,
              ),
              itemCount: candidates.length,
              itemBuilder: (_, i) {
                final item = candidates[i];
                return GestureDetector(
                  onTap: () => onPicked(item),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: t.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                          color: t.backgroundPrimary,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: item.displayUrl != null
                            ? Image.network(item.displayUrl!,
                            fit: BoxFit.contain)
                            : Center(
                          child: Icon(
                            item.isAiRecommended
                                ? Icons.auto_awesome
                                : Icons.checkroom,
                            color: t.mutedText,
                            size: 24,
                          ),
                        ),
                      ),
                      if (item.isAiRecommended)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.backgroundPrimary
                                  .withOpacity(0.85),
                              borderRadius:
                              BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.auto_awesome,
                                size: 10, color: t.mutedText),
                          ),
                        ),
                    ],
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
// ============================================================
// SKELETON / LOADING PLACEHOLDER WIDGETS
//
// These mirror the real board's visual structure (tabs + grid +
// buttons + history) so the layout is stable from the first frame.
// They animate with a gentle opacity pulse via _SkeletonPulse so
// the user perceives activity without an intrusive spinner.
//
// _SkeletonGrid renders a fixed 6-item 2×3 layout — the most
// common board size — which avoids a chicken-and-egg problem of
// needing item count before data arrives.
// ============================================================

/// Drives an oscillating opacity for all skeleton children.
class _SkeletonPulse extends StatefulWidget {
  final Widget child;
  const _SkeletonPulse({required this.child});

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

/// A single rounded rectangle placeholder card.
class _SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final AppThemeTokens t;
  final BorderRadius borderRadius;

  const _SkeletonBox({
    required this.height,
    required this.t,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: t.backgroundSecondary,
          borderRadius: borderRadius,
          border: Border.all(color: t.cardBorder, width: 1),
        ),
      ),
    );
  }
}

/// A pill-shaped placeholder that mimics an occasion tab chip.
class _SkeletonChip extends StatelessWidget {
  final double width;
  final AppThemeTokens t;
  const _SkeletonChip({required this.width, required this.t});

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(
      width: width,
      height: 38,
      t: t,
      borderRadius: BorderRadius.circular(10),
    );
  }
}

/// A simple horizontal arrangement of skeleton children.
class _SkeletonRow extends StatelessWidget {
  final List<Widget> children;
  const _SkeletonRow({required this.children});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: children,
  );
}

/// A 2×3 skeleton grid (6 cells) that matches the most common
/// board layout so the placeholder occupies the same space as
/// the real grid, preventing layout jumps when data arrives.
class _SkeletonGrid extends StatelessWidget {
  final AppThemeTokens t;
  const _SkeletonGrid({required this.t});

  static const double _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final cw = (box.maxWidth - 2 * _gap) / 3;
      final ih = cw;
      return Column(
        children: [
          _skeletonRow3(cw, ih),
          const SizedBox(height: _gap),
          _skeletonRow3(cw, ih),
        ],
      );
    });
  }

  Widget _skeletonRow3(double cw, double ih) {
    return Row(
      children: [
        _SkeletonBox(height: ih, width: cw, t: t),
        const SizedBox(width: _gap),
        _SkeletonBox(height: ih, width: cw, t: t),
        const SizedBox(width: _gap),
        _SkeletonBox(height: ih, width: cw, t: t),
      ],
    );
  }
}