// ============================================================
// lib/widgets/build_outfit_screen.dart
// Build Outfit – Style Board items are fetched from the backend
//
// Updated with:
//   - Backend-driven Style Board items only (with skeleton loading)
//   - Horizontal scroll Board History (latest first)
//
// This screen used to be a fully separate manual builder (add item /
// remove item / save outfit). That's gone. Build Outfit now populates
// its Style Board (Casual / Office / Evening tabs) entirely from the
// backend:
//
// STYLE BOARD DATA FLOW:
//   Step 1: selected item = ANCHOR, sent to the backend as context.
//   Step 2: call the backend (_fetchStyleBoardsFromBackend) to
//           generate/retrieve the Style Board outfits for this anchor.
//   Step 3: while the request is in flight, render skeleton
//           placeholders (SkeletonBoardItem) in each occasion tab.
//   Step 4: once the response arrives, replace the skeletons with the
//           real items from the backend (BackendBoardItem, parsed via
//           Outfit.fromJson). The local wardrobe is never used to
//           populate the Style Board.
//
// Shuffle, Replace, and Find Similar are also fully backend-driven:
//   - Shuffle (_fetchShuffledItemsFromBackend) sends the current
//     board's item ids + locked item ids and gets back a fresh set of
//     items for the unlocked slots.
//   - Replace / Find Similar (_fetchReplacementCandidatesFromBackend)
//     asks the backend for candidate items for a given slot/occasion
//     and renders whatever it returns in the picker sheet.
// None of these three actions read from widget.allItems (the local
// wardrobe) anymore — every item shown anywhere on the Style Board
// comes from a backend response.
//
// Screen features:
//   - Occasion tabs (Casual/Office/Evening) above the outfit.
//   - Lock/unlock individual items, shuffle unlocked items (re-ranked
//     against the anchor by the backend).
//   - Outfit history, scoped per occasion tab.
//   - Tap an item to see details: lock/unlock, replace, find similar.
//   - Loading state (skeletons) while the backend Style Board loads;
//     error state with retry.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
// Every Style Board item comes from the backend now — see
// BackendBoardItem below. The wardrobeItem getter is kept on the
// interface only so a future feature (e.g. tapping through to a
// matching wardrobe item) has somewhere to hang that data; nothing
// in this screen constructs a wardrobe-backed board item anymore.
// ============================================================
abstract class BoardDisplayItem {
  String get id;
  String get name;
  String get cat;
  String? get displayUrl;
  double get matchScore;
  WardrobeItem? get wardrobeItem;
}

// ============================================================
// SKELETON LOADING ITEM (Placeholder for backend loading)
// ============================================================
class SkeletonBoardItem implements BoardDisplayItem {
  final String skeletonId;

  SkeletonBoardItem(this.skeletonId);

  @override
  String get id => skeletonId;
  @override
  String get name => '';
  @override
  String get cat => '';
  @override
  String? get displayUrl => null;
  @override
  double get matchScore => 0;
  @override
  WardrobeItem? get wardrobeItem => null;
}

// ============================================================
// BACKEND BOARD ITEM
// Represents a Style Board item exactly as returned by the backend.
// This is intentionally NOT backed by a WardrobeItem — Style Board
// items come solely from the backend response. (WardrobeItem is
// still used elsewhere, e.g. the Replace / Find Similar picker,
// which searches the user's wardrobe rather than populating the
// board itself.)
// ============================================================
class BackendBoardItem implements BoardDisplayItem {
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

  BackendBoardItem({
    required this.id,
    required this.name,
    required this.cat,
    this.displayUrl,
    this.matchScore = 0,
  });

  @override
  WardrobeItem? get wardrobeItem => null;

  factory BackendBoardItem.fromJson(Map<String, dynamic> json) {
    return BackendBoardItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cat: json['category']?.toString() ?? json['cat']?.toString() ?? '',
      displayUrl:
      json['imageUrl']?.toString() ?? json['displayUrl']?.toString(),
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0,
    );
  }
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

  /// Parses a single Style Board out of the backend response.
  /// Every item in [json]['items'] becomes a [BackendBoardItem] —
  /// Style Board items are never sourced from the local wardrobe.
  factory Outfit.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List?) ?? const [];
    return Outfit(
      id: json['id']?.toString() ?? json['occasion']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      occasion: json['occasion']?.toString() ?? '',
      items: itemsJson
          .map((e) => BackendBoardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      thumbnail: json['thumbnail']?.toString() ?? '',
    );
  }
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
  // TODO: Wire these up to the app's real config/auth service
  // (e.g. an environment config and a session/auth manager) instead
  // of hardcoding them here.
  static const String _apiBaseUrl =
  String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com');
  final String? _authToken = null;

  List<Outfit> outfits = [];
  List<OutfitHistory> outfitHistory = [];
  int selectedOutfitIndex = 0;
  String? selectedItemId;
  Set<String> lockedItemIds = {};
  bool _boardsInitialized = false;
  bool _isLoading = true;
  bool _isShuffling = false;
  String? _loadError;
  List<int> _skeletonIndices = []; // Track which outfits are still loading skeleton items

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

  // ── Data fetching (Backend-driven with skeleton loading) ──────────────────

  Future<void> _loadOutfits() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      // Initialize with skeleton placeholders for each outfit variation
      // These will be replaced with backend data
      outfits = [
        Outfit(
          id: 'casual',
          name: AppLocalizations.t(context, 'style_boards_board_name_1'),
          occasion: 'casual',
          items: _createSkeletonItems(6), // Show 6 skeleton items initially
          thumbnail: '',
        ),
        Outfit(
          id: 'office',
          name: AppLocalizations.t(context, 'style_boards_board_name_2'),
          occasion: 'office',
          items: _createSkeletonItems(6),
          thumbnail: '',
        ),
        Outfit(
          id: 'evening',
          name: AppLocalizations.t(context, 'style_boards_board_name_3'),
          occasion: 'evening',
          items: _createSkeletonItems(6),
          thumbnail: '',
        ),
      ];
      selectedOutfitIndex = 0;
      lockedItemIds.clear();
      outfitHistory = [];
      _skeletonIndices = [0, 1, 2]; // Mark all as skeleton
    });

    try {
      // Style Board data (initial load, shuffle, replace, find-similar) all
      // come from the backend now — the wardrobe is not used to populate,
      // shuffle, or refill the board.
      final boards = await _fetchStyleBoardsFromBackend();

      if (!mounted) return;

      // Replace skeleton placeholders with real backend data
      setState(() {
        outfits = boards;
        selectedOutfitIndex = 0;
        lockedItemIds.clear();

        // Initialize history with the first snapshot of each occasion
        outfitHistory = boards
            .map((b) => OutfitHistory(
          id: 'h_${b.occasion}_${DateTime.now().millisecondsSinceEpoch}',
          occasion: b.occasion,
          items: b.items,
          createdAt: DateTime.now(),
        ))
            .toList();

        _isLoading = false;
        _skeletonIndices.clear(); // Clear skeleton tracking
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = AppLocalizations.t(context, 'buildOutfitLoadError');
        _isLoading = false;
      });
    }
  }

  /// Fetch style boards from backend.
  ///
  /// The backend returns pre-generated style board outfits that are
  /// ready to display. Each outfit contains a curated list of items
  /// that work well together for the specific occasion.
  ///
  /// The local wardrobe is never used to generate or fill in the
  /// Style Board — every item rendered on the board, including
  /// shuffled and replaced items, comes from a backend response.
  /// widget.allItems is kept on this widget only for API compatibility
  /// with existing callers; it is not read anywhere in this screen.
  Future<List<Outfit>> _fetchStyleBoardsFromBackend() async {
    final response = await http
        .post(
      Uri.parse('$_apiBaseUrl/v1/style-boards/generate'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({
        'anchorItemId': widget.selectedItem.id,
        'occasions': ['casual', 'office', 'evening'],
      }),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final boardsJson = (data['boards'] as List?) ?? const [];

      return boardsJson
          .map((board) => Outfit.fromJson(board as Map<String, dynamic>))
          .map((board) {
        // If the backend didn't localize the board name, fall back to
        // the local display name for the given occasion.
        if (board.name.isNotEmpty) return board;
        return Outfit(
          id: board.id,
          name: _occasionDisplayName(board.occasion),
          occasion: board.occasion,
          items: board.items,
          thumbnail: board.thumbnail,
        );
      }).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else if (response.statusCode == 500) {
      throw Exception('Server error: Please try again later');
    } else {
      throw Exception(
          'Failed to generate style boards: ${response.statusCode}');
    }
  }

  String _occasionDisplayName(String occasion) {
    switch (occasion) {
      case 'casual':
        return AppLocalizations.t(context, 'style_boards_board_name_1');
      case 'office':
        return AppLocalizations.t(context, 'style_boards_board_name_2');
      case 'evening':
        return AppLocalizations.t(context, 'style_boards_board_name_3');
      default:
        return occasion;
    }
  }

  /// Creates a list of skeleton placeholder items for loading state
  List<BoardDisplayItem> _createSkeletonItems(int count) {
    return List.generate(
      count,
          (i) => SkeletonBoardItem('skeleton_$i'),
    );
  }

  // ── State mutations ──────────────────────────────────────────

  void _toggleItemLock(String itemId) {
    setState(() {
      lockedItemIds.contains(itemId)
          ? lockedItemIds.remove(itemId)
          : lockedItemIds.add(itemId);
    });
  }

  /// Asks the backend to re-rank/replace the unlocked, non-anchor items
  /// on the currently selected Style Board against the anchor item.
  /// Locked items are sent along so the backend can keep them in place;
  /// the wardrobe is never used to generate the new items.
  Future<List<BoardDisplayItem>> _fetchShuffledItemsFromBackend() async {
    final board = outfits[selectedOutfitIndex];

    final response = await http
        .post(
      Uri.parse('$_apiBaseUrl/v1/style-boards/shuffle'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({
        'anchorItemId': widget.selectedItem.id,
        'occasion': board.occasion,
        'currentItemIds': board.items.map((i) => i.id).toList(),
        'lockedItemIds': lockedItemIds.toList(),
      }),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final itemsJson = (data['items'] as List?) ?? const [];
      return itemsJson
          .map((e) => BackendBoardItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else if (response.statusCode == 500) {
      throw Exception('Server error: Please try again later');
    } else {
      throw Exception('Failed to shuffle style board: ${response.statusCode}');
    }
  }

  /// Re-ranks unlocked, non-anchor items against the anchor via the
  /// backend — intentionally not a local wardrobe shuffle.
  Future<void> _shuffleUnlockedPieces() async {
    if (_isShuffling) return;
    setState(() => _isShuffling = true);

    try {
      final updated = await _fetchShuffledItemsFromBackend();
      if (!mounted) return;

      final board = outfits[selectedOutfitIndex];
      final now = DateTime.now();

      setState(() {
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

        _isShuffling = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isShuffling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t(context, 'buildOutfitShuffleError')),
        ),
      );
    }
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

  /// Asks the backend for candidate items to replace [current] with
  /// (or, when [similarOnly] is true, items similar to it). The local
  /// wardrobe is never used here — every candidate shown in the
  /// Replace / Find Similar picker comes from this response.
  Future<List<BackendBoardItem>> _fetchReplacementCandidatesFromBackend({
    required BoardDisplayItem current,
    required bool similarOnly,
  }) async {
    final board = outfits[selectedOutfitIndex];
    final usedIds = board.items.map((i) => i.id).toSet();

    final response = await http
        .post(
      Uri.parse('$_apiBaseUrl/v1/style-boards/candidates'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({
        'anchorItemId': widget.selectedItem.id,
        'occasion': board.occasion,
        'itemId': current.id,
        'category': current.cat,
        'mode': similarOnly ? 'similar' : 'replace',
        'excludeItemIds': usedIds.toList(),
      }),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final candidatesJson = (data['candidates'] as List?) ?? const [];
      return candidatesJson
          .map((e) => BackendBoardItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again');
    } else if (response.statusCode == 500) {
      throw Exception('Server error: Please try again later');
    } else {
      throw Exception(
          'Failed to fetch replacement candidates: ${response.statusCode}');
    }
  }

  void _openItemPicker(BoardDisplayItem current, {required bool similarOnly}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemPickerSheet(
        title: similarOnly
            ? AppLocalizations.t(context, 'style_boards_find_similar_title')
            : AppLocalizations.t(context, 'style_boards_replace_title'),
        fetchCandidates: () => _fetchReplacementCandidatesFromBackend(
          current: current,
          similarOnly: similarOnly,
        ),
        onPicked: (picked) {
          Navigator.pop(ctx);
          _replaceItem(current.id, picked);
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
                      color: t.backgroundSecondary,
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
            AppLocalizations.t(context, 'buildOutfitTitle'),
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
            AppLocalizations.t(context, 'style_boards_loading'),
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

  // ── Category Chips (3 style variations: Classic Professional / Business Casual / Evening Elegance) ────────────────
  // Maps occasion keys to localised display names for category chips
  String _occasionChipName(BuildContext context, String occasion) {
    switch (occasion) {
      case 'casual':
        return AppLocalizations.t(context, 'buildOutfitOccasionCasual');
      case 'office':
        return AppLocalizations.t(context, 'buildOutfitOccasionOffice');
      case 'evening':
        return AppLocalizations.t(context, 'buildOutfitOccasionEvening');
      default:
        return occasion;
    }
  }

  Widget _buildOccasionTabs(BuildContext context, AppThemeTokens t) {
    return Wrap(
      spacing: 8.0, // Horizontal gap between chips
      runSpacing: 8.0, // Vertical gap if chips wrap (shouldn't on normal devices)
      alignment: WrapAlignment.start, // Align chips to start
      children: List.generate(
        outfits.length,
            (i) {
          final isSelected = i == selectedOutfitIndex;
          final occasion = outfits[i].occasion;
          final displayName = _occasionChipName(context, occasion);

          return GestureDetector(
            onTap: () => setState(() {
              selectedOutfitIndex = i;
              lockedItemIds.clear();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? t.accent.primary : t.backgroundSecondary,
                borderRadius: BorderRadius.circular(20), // Pill-shaped chips
                border: Border.all(
                  color: isSelected ? t.accent.primary : t.cardBorder,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Text(
                displayName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : t.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // LAYOUT DISPATCHER
  // Renders style boards with 1–8 items using responsive grid layouts.
  //
  // MAXIMUM ITEMS: 8
  // ─────────────
  // The style board is capped at 8 items to maintain visual balance
  // and consistent UI performance. If the backend returns more than
  // 8 items, only the first 8 are displayed (see _buildUnifiedGrid).
  //
  // ITEM COUNT HANDLING (per AHVI Style Board Layouts spec):
  // ───────────────────
  // • 1–2 items:  Equal-width columns, centered
  // • 3–8 items:  Topwear + Bottomwear ALWAYS stacked on the left,
  //               equal height. Only the right-side layout changes
  //               based on item count:
  //     3 items → right side: 1 item, full height
  //     4 items → right side: 2 items stacked (top/bottom)
  //     5 items → right side: 1 on top, 2 side-by-side on bottom
  //     6 items → right side: 1 on top, (2 + 1) on bottom
  //     7 items → right side: 1 on top, 2×2 grid on bottom
  //     8 items → right side: 1 on top, (2 + 2 + 1) on bottom
  //
  // The selected wardrobe item (the anchor the board was built from)
  // is always pinned to the top-left ("Topwear") position and
  // Bottomwear to bottom-left. Every other item — Shoes, an extra
  // Topwear piece, Watch, Belt, Bag, etc. — simply fills the right
  // side in priority order; no category owns a fixed slot there, so
  // nothing the backend returns is ever dropped. See
  // _placeBoardItems for the full priority order.
  //
  // NO EMPTY SPACES: Each layout is tailored to fit exactly N items
  // without awkward gaps or unfilled grid cells. All items maintain
  // equal visual weight and spacing regardless of count.
  // ============================================================

  static const double _kGap = 16.0;

  // Maximum number of items to display in the style board
  static const int _kMaxBoardItems = 8;

  // Caps how large any single grid cell in the 1/2/4-item layouts can
  // grow. Those layouts use half-width (or bigger) cells, which made
  // outfits with only a few items look oversized on typical phone
  // widths. 5/6/7/8-item layouts already divide into three columns and
  // stay compact on their own, so they're left as-is. (3–8 item
  // layouts share _styleBoardLayout below, which derives its own
  // column width the same way via _cappedCellWidth.)
  static const double _kMaxCardExtent = 180.0;

  double _cappedCellWidth(double totalWidth, double gap, int columns,
      {double maxExtent = _kMaxCardExtent}) {
    final raw = (totalWidth - gap * (columns - 1)) / columns;
    return raw < maxExtent ? raw : maxExtent;
  }

  /// Builds the style board grid layout, selecting the optimal layout
  /// for the given item count (1–8). If more than 8 items are provided,
  /// only the first 8 are used.
  ///
  /// Returns SizedBox.shrink() if items list is empty.
  Widget _buildUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Enforce maximum item count; discard any items beyond the cap
    final capped = items.length > _kMaxBoardItems
        ? items.take(_kMaxBoardItems).toList()
        : items;

    // Places every item on the board: selected item pinned top-left,
    // actual Bottomwear bottom-left, and everything else filling the
    // right side in priority order — nothing is ever dropped.
    final displayItems = _placeBoardItems(capped);

    switch (displayItems.length) {
      case 1:
      case 2:
        return _layoutSmall(context, t, displayItems);
      default:
      // 3–8 items all share the same left column (Topwear +
      // Bottomwear, equal height) with only the right side varying.
        return _styleBoardLayout(context, t, displayItems);
    }
  }

  // ── Placement rules ──────────────────────────────────────────
  // Only two positions are ever fixed:
  //   1. Selected item (anchor)  → always top-left.
  //   2. Bottomwear item         → always bottom-left, if the backend
  //                              returned one.
  // Everything else — Shoes, extra Topwear, Watch, Pocket Square,
  // Belt, Bag, Wallet, and anything uncategorized — simply fills the
  // right side, top-to-bottom / left-to-right, in that priority
  // order. No category owns a fixed slot on the right, so nothing is
  // ever dropped: whatever the backend returns (up to _kMaxBoardItems)
  // ends up somewhere on the board, and the layout picked in
  // _buildUnifiedGrid already sizes itself to however many items
  // that turns out to be.
  //
  // Category matching is a best-effort, case-insensitive keyword
  // match against BoardDisplayItem.cat — adjust the keyword lists
  // below (_kBottomwearKw etc.) if the backend's actual category
  // strings differ.
  static bool _isCat(BoardDisplayItem i, List<String> keywords) {
    final c = i.cat.toLowerCase();
    return keywords.any((k) => c.contains(k));
  }

  static const _kBottomwearKw = [
    'bottomwear', 'bottom wear', 'pants', 'trouser', 'jeans', 'shorts', 'skirt',
  ];
  static const _kTopwearKw = [
    'topwear', 'top wear', 'shirt', 'tee', 't-shirt', 'jacket', 'blazer',
    'sweater', 'hoodie', 'top',
  ];
  static const _kShoesKw = ['shoe', 'footwear', 'sneaker', 'boot', 'sandal'];
  static const _kWatchKw = ['watch'];
  static const _kPocketSquareKw = ['pocket square', 'pocketsquare', 'pocket_square'];
  static const _kBeltKw = ['belt'];
  static const _kBagKw = ['bag', 'purse', 'handbag'];
  static const _kWalletKw = ['wallet'];

  List<BoardDisplayItem> _placeBoardItems(List<BoardDisplayItem> items) {
    if (items.isEmpty) return items;

    final anchorId = widget.selectedItem.id;
    final pool = List<BoardDisplayItem>.from(items);
    final anchorIndex = pool.indexWhere((i) => i.id == anchorId);
    // If the anchor isn't in the list yet (e.g. still loading), fall
    // back to whatever's first rather than leaving top-left empty.
    final anchor = pool.removeAt(anchorIndex >= 0 ? anchorIndex : 0);

    // Bottom-left: the actual Bottomwear item, if present.
    final bottomwearIdx = pool.indexWhere((i) => _isCat(i, _kBottomwearKw));
    final bottomwear =
    bottomwearIdx >= 0 ? pool.removeAt(bottomwearIdx) : null;

    List<BoardDisplayItem> take(List<String> keywords) {
      final matches = pool.where((i) => _isCat(i, keywords)).toList();
      pool.removeWhere((i) => _isCat(i, keywords));
      return matches;
    }

    // Right side: everything that isn't the anchor or Bottomwear,
    // filled in priority order — Shoes, extra Topwear (e.g. a second
    // jacket alongside the selected shirt), Watch, Pocket Square,
    // Belt, Bag, Wallet, then anything uncategorized (kept in
    // original relative order). No item in `pool` is ever discarded
    // here — `...pool` at the end catches anything the keyword lists
    // above didn't match.
    final rightSide = [
      ...take(_kShoesKw),
      ...take(_kTopwearKw),
      ...take(_kWatchKw),
      ...take(_kPocketSquareKw),
      ...take(_kBeltKw),
      ...take(_kBagKw),
      ...take(_kWalletKw),
      ...pool,
    ];

    return [
      anchor,
      if (bottomwear != null) bottomwear,
      ...rightSide,
    ];
  }

  // ─── 1–2 items: equal-width columns, centered ──────────────────────────────
  // Layout: items laid out side-by-side in equal-width columns.
  // Spacing: _kGap (16.0) between items.
  // Alignment: Centered within parent container.
  // Cell sizing: Capped at _kMaxCardExtent (180.0) to prevent oversizing.
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

  // ─── 3–8 items: AHVI Style Board layout ────────────────────────────────────
  // Shared structure for every count from 3 to 8 (matches the "Common
  // Flutter Structure" in the AHVI Style Board Layouts spec):
  //
  //   Row(
  //     Expanded(Column(Topwear, gap, Bottomwear)),   <- always equal height
  //     gap,
  //     Expanded(RightSideLayout()),                  <- only this changes
  //   )
  //
  // Topwear/Bottomwear (items[0]/items[1] after anchor-pinning) are
  // always stacked on the left at equal height. The right side is the
  // only part that varies by item count:
  //   3 items → right side: 1 item spanning the full height
  //   4 items → right side: 2 items stacked (top/bottom)
  //   5 items → right side: 1 on top, 2 side-by-side on bottom
  //   6 items → right side: 1 on top, (2 side-by-side + 1 full-width) on bottom
  //   7 items → right side: 1 on top, 2×2 grid on bottom
  //   8 items → right side: 1 on top, (2 + 2 + 1 full-width) on bottom
  //
  // Sizing: left/right columns are equal width (matching the spec's
  // Expanded/Expanded with no flex override). Total board height is
  // derived from that column width so Topwear/Bottomwear render as
  // squares, then every cell on the right side fills its share of
  // that same fixed height via Expanded — no per-cell pixel math
  // needed beyond the initial column width.
  Widget _styleBoardLayout(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      const double g = _kGap;
      final colW = _cappedCellWidth(box.maxWidth, g, 2);
      final totalH = colW * 2 + g;

      return Center(
        child: SizedBox(
          width: colW * 2 + g,
          height: totalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Topwear + Bottomwear, always stacked, equal height.
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _buildItemCard(context, items[0], t)),
                    SizedBox(height: g),
                    Expanded(child: _buildItemCard(context, items[1], t)),
                  ],
                ),
              ),
              SizedBox(width: g),
              // Right: layout varies by item count.
              Expanded(child: _rightSideLayout(context, t, items)),
            ],
          ),
        ),
      );
    });
  }

  /// Right-side layout for the 3–8 item Style Board. `items[2]` always
  /// takes the top-right cell (matching Topwear's height); for 3 items
  /// there is no bottom cell, so the single item spans the full height
  /// instead. `items[3..]`, if any, are arranged in the bottom-right
  /// cell (matching Bottomwear's height) by [_bottomRightArea].
  Widget _rightSideLayout(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.length == 3) {
      // 3 items: single card spans the full right-side height.
      return _buildItemCard(context, items[2], t);
    }
    return Column(
      children: [
        Expanded(child: _buildItemCard(context, items[2], t)),
        const SizedBox(height: _kGap),
        Expanded(
            child: _bottomRightArea(context, t, items.sublist(3))),
      ],
    );
  }

  /// Arranges the items below "Shoes" on the right side, sized to
  /// match Bottomwear's height. The sub-layout grows with the count:
  ///   1 item  (4 total) → single full-width card
  ///   2 items (5 total) → 2 side-by-side
  ///   3 items (6 total) → (2 side-by-side) + (1 full-width)
  ///   4 items (7 total) → 2×2 grid
  ///   5 items (8 total) → (2) + (2) + (1 full-width)
  Widget _bottomRightArea(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> rest) {
    const double g = _kGap;
    switch (rest.length) {
      case 1:
        return _buildItemCard(context, rest[0], t);
      case 2:
        return Row(
          children: [
            Expanded(child: _buildItemCard(context, rest[0], t)),
            SizedBox(width: g),
            Expanded(child: _buildItemCard(context, rest[1], t)),
          ],
        );
      case 3:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemCard(context, rest[0], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildItemCard(context, rest[1], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(child: _buildItemCard(context, rest[2], t)),
          ],
        );
      case 4:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemCard(context, rest[0], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildItemCard(context, rest[1], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemCard(context, rest[2], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildItemCard(context, rest[3], t)),
                ],
              ),
            ),
          ],
        );
      case 5:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemCard(context, rest[0], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildItemCard(context, rest[1], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildItemCard(context, rest[2], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildItemCard(context, rest[3], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(child: _buildItemCard(context, rest[4], t)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Item card (skeleton-aware) ───────────────────────────────

  Widget _buildItemCard(BuildContext context, BoardDisplayItem item, AppThemeTokens t) {
    // Check if this is a skeleton item
    if (item is SkeletonBoardItem) {
      return _buildSkeletonCard(context, t);
    }

    return GestureDetector(
      onTap: () => _selectItem(item.id),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: t.cardBorder),
          borderRadius: BorderRadius.circular(12),
          color: t.backgroundSecondary,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.displayUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(
                item.displayUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.checkroom, color: t.mutedText, size: 32),
              ),
            )
                : Icon(Icons.checkroom, color: t.mutedText, size: 32),
            if (lockedItemIds.contains(item.id))
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Skeleton card for loading state
  Widget _buildSkeletonCard(BuildContext context, AppThemeTokens t) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.cardBorder),
        borderRadius: BorderRadius.circular(12),
        color: t.backgroundSecondary,
      ),
      child: Center(
        child: _buildShimmer(t),
      ),
    );
  }

  /// Shimmer/pulse effect for skeleton loading
  Widget _buildShimmer(AppThemeTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 0.7),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        builder: (_, value, __) {
          return Container(
            decoration: BoxDecoration(
              color: t.mutedText.withOpacity(value * 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
        onEnd: () {}, // Loop the animation naturally with TweenAnimationBuilder
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
          onTap: _isShuffling ? null : _shuffleUnlockedPieces,
          t: t,
          isPrimary: true,
          isLoading: _isShuffling,
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
        required VoidCallback? onTap,
        required AppThemeTokens t,
        bool isPrimary = false,
        bool isLoading = false,
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
              isLoading
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? t.accent.primary : t.textPrimary,
                ),
              )
                  : Icon(icon,
                  color: isPrimary ? t.accent.primary : t.textPrimary,
                  size: 18),
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

  // ── Board history section (HORIZONTAL SCROLL) ────────────────

  Widget _buildOutfitHistorySection(BuildContext context, AppThemeTokens t) {
    // Show only history entries that match the currently selected occasion tab
    final currentOccasion = outfits.isNotEmpty
        ? outfits[selectedOutfitIndex].occasion
        : '';
    final filteredHistory = outfitHistory
        .where((h) => h.occasion == currentOccasion)
        .toList();

    // Sort so the latest is first (already in order from insert(0, ...))
    // Reverse to show latest first in horizontal scroll
    final sortedHistory = filteredHistory.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
          // Empty state
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
          // Horizontal scrollable history cards
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Generate cards for each history item (latest first)
                  ...List.generate(sortedHistory.length, (index) {
                    final h = sortedHistory[index];
                    final isCurrent = index == 0; // First item is current
                    final realIndex = outfitHistory.indexOf(h);

                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == sortedHistory.length - 1 ? 0 : 12,
                      ),
                      child: GestureDetector(
                        onTap: () => _switchOutfit(realIndex),
                        child: Container(
                          width: _kHistoryCardWidth, // Fixed width for horizontal scroll
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isCurrent ? t.accent.primary : t.cardBorder,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: isCurrent
                                ? t.accent.primary.withOpacity(0.06)
                                : null,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header: timestamp + current indicator
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
                                            fontSize: 11,
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
                                            fontSize: 9,
                                            color: t.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Current indicator
                                  if (isCurrent)
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: t.accent.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Mini-grid preview
                              IgnorePointer(
                                child: _buildHistoryGrid(context, t, h.items),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
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

  static const double _kHistoryCardWidth = 220.0;

  Widget _buildHistoryGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildHistoryUnifiedGrid(context, t, items);
  }

  Widget _buildHistoryUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final capped = items.length > 8 ? items.take(8).toList() : items;
    // Same placement rules as the main board, so history previews
    // stay visually consistent with the current Style Board.
    final displayItems = _placeBoardItems(capped);

    switch (displayItems.length) {
      case 1:
      case 2:
        return _historyLayoutSmall(context, t, displayItems);
      default:
      // 3–8 items share the same left column (Topwear + Bottomwear,
      // equal height) with only the right side varying.
        return _historyStyleBoardLayout(context, t, displayItems);
    }
  }

  static const double _kHGap = 8.0; // tighter gap for the mini preview

  Widget _buildHistoryItemCard(
      BuildContext context, BoardDisplayItem item, AppThemeTokens t) {
    // Skip skeleton items in history
    if (item is SkeletonBoardItem) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: t.backgroundSecondary,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: t.backgroundSecondary,
      ),
      child: item.displayUrl != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          item.displayUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.checkroom, color: t.mutedText, size: 12),
          ),
        ),
      )
          : Center(
        child: Icon(Icons.checkroom, color: t.mutedText, size: 12),
      ),
    );
  }

  // History layout variants (simplified versions)
  Widget _historyLayoutSmall(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    final n = items.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: n,
        crossAxisSpacing: _kHGap,
        mainAxisSpacing: _kHGap,
        childAspectRatio: 0.9,
      ),
      itemCount: n,
      itemBuilder: (_, i) => _buildHistoryItemCard(context, items[i], t),
    );
  }

  // ─── 3–8 items: AHVI Style Board layout (history mini-grid) ────────────────
  // Mirrors _styleBoardLayout on the main board exactly, just with the
  // tighter _kHGap spacing and history item cards (no lock icon, no
  // tap handler — taps fall through via the caller's IgnorePointer).
  Widget _historyStyleBoardLayout(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    return LayoutBuilder(builder: (_, box) {
      const double g = _kHGap;
      final colW = (box.maxWidth - g) / 2;
      final totalH = colW * 2 + g;

      return SizedBox(
        width: colW * 2 + g,
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Topwear + Bottomwear, always stacked, equal height.
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildHistoryItemCard(context, items[0], t)),
                  SizedBox(height: g),
                  Expanded(child: _buildHistoryItemCard(context, items[1], t)),
                ],
              ),
            ),
            SizedBox(width: g),
            // Right: layout varies by item count.
            Expanded(child: _historyRightSideLayout(context, t, items)),
          ],
        ),
      );
    });
  }

  /// Right-side layout for the history mini-grid — see
  /// [_rightSideLayout] for the main-board equivalent this mirrors.
  Widget _historyRightSideLayout(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> items) {
    if (items.length == 3) {
      return _buildHistoryItemCard(context, items[2], t);
    }
    return Column(
      children: [
        Expanded(child: _buildHistoryItemCard(context, items[2], t)),
        const SizedBox(height: _kHGap),
        Expanded(
            child: _historyBottomRightArea(context, t, items.sublist(3))),
      ],
    );
  }

  /// See [_bottomRightArea] for the main-board equivalent this mirrors.
  Widget _historyBottomRightArea(
      BuildContext context, AppThemeTokens t, List<BoardDisplayItem> rest) {
    const double g = _kHGap;
    switch (rest.length) {
      case 1:
        return _buildHistoryItemCard(context, rest[0], t);
      case 2:
        return Row(
          children: [
            Expanded(child: _buildHistoryItemCard(context, rest[0], t)),
            SizedBox(width: g),
            Expanded(child: _buildHistoryItemCard(context, rest[1], t)),
          ],
        );
      case 3:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildHistoryItemCard(context, rest[0], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildHistoryItemCard(context, rest[1], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(child: _buildHistoryItemCard(context, rest[2], t)),
          ],
        );
      case 4:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildHistoryItemCard(context, rest[0], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildHistoryItemCard(context, rest[1], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildHistoryItemCard(context, rest[2], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildHistoryItemCard(context, rest[3], t)),
                ],
              ),
            ),
          ],
        );
      case 5:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildHistoryItemCard(context, rest[0], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildHistoryItemCard(context, rest[1], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildHistoryItemCard(context, rest[2], t)),
                  SizedBox(width: g),
                  Expanded(child: _buildHistoryItemCard(context, rest[3], t)),
                ],
              ),
            ),
            SizedBox(height: g),
            Expanded(child: _buildHistoryItemCard(context, rest[4], t)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ============================================================
// ITEM DETAILS PANEL (Bottom Sheet)
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

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: t.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: t.backgroundPrimary,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: t.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
            ],
          ),
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
// Candidates are fetched from the backend — never from the local
// wardrobe. Picking one always produces a BackendBoardItem back on
// the board.
// ============================================================
class _ItemPickerSheet extends StatefulWidget {
  final String title;
  final Future<List<BackendBoardItem>> Function() fetchCandidates;
  final ValueChanged<BackendBoardItem> onPicked;

  const _ItemPickerSheet({
    required this.title,
    required this.fetchCandidates,
    required this.onPicked,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  List<BackendBoardItem>? _candidates;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final candidates = await widget.fetchCandidates();
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'error';
        _isLoading = false;
      });
    }
  }

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
                  widget.title,
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
          Expanded(child: _buildBody(context, t)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppThemeTokens t) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: t.accent.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.t(context, 'buildOutfitPickerError'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: t.mutedText),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _load,
                child: Text(
                  AppLocalizations.t(context, 'style_boards_retry'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.accent.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final candidates = _candidates ?? const [];
    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.t(context, 'style_boards_no_items_to_swap'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: t.mutedText),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: candidates.length,
      itemBuilder: (_, i) {
        final item = candidates[i];
        return GestureDetector(
          onTap: () => widget.onPicked(item),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: t.cardBorder),
              borderRadius: BorderRadius.circular(8),
              color: t.backgroundPrimary,
            ),
            clipBehavior: Clip.antiAlias,
            child: item.displayUrl != null
                ? Image.network(item.displayUrl!, fit: BoxFit.contain)
                : Icon(Icons.checkroom, color: t.mutedText, size: 24),
          ),
        );
      },
    );
  }
}