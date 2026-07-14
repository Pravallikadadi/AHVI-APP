// ============================================================
// lib/widgets/build_outfit_screen.dart
// Build Outfit – Same layout as Style Boards (without AI)
//
// Features:
//   - Select items from wardrobe to build an outfit
//   - Same asymmetric grid layout as style_boards
//   - Responsive layouts for 1-8 items
//   - Organize by clothing slots
//   - Save and manage outfits
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
      required WardrobeItem? initialItem,
      required List<WardrobeItem> allItems,
      VoidCallback? onOutfitCreated,
    }) {
  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog.fullscreen(
      child: BuildOutfitScreen(
        initialItem: initialItem,
        allItems: allItems,
        onOutfitCreated: onOutfitCreated,
      ),
    ),
  );
}

// ============================================================
// OUTFIT DATA MODEL
// ============================================================
class Outfit {
  final String id;
  final String name;
  final List<WardrobeItem> items;
  final DateTime createdAt;

  Outfit({
    required this.id,
    required this.name,
    required this.items,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // NOTE: 'Untitled Outfit' fallback is intentionally kept here as this is a
  // data-model getter without BuildContext. Use l10n.buildOutfitUntitled in
  // UI code wherever a localised fallback is needed.
  String get displayName => name.isEmpty ? 'Untitled Outfit' : name;
}

// ============================================================
// CLOTHING SLOT ENUM
// ============================================================
enum ClothingSlot { top, bottom, dress, outerwear, footwear, bag, accessory, other }

extension ClothingSlotExt on ClothingSlot {
  /// Non-localised fallback label – use [localizedLabel] in widget code.
  String get label {
    switch (this) {
      case ClothingSlot.top:
        return 'Top';
      case ClothingSlot.bottom:
        return 'Bottom';
      case ClothingSlot.dress:
        return 'Dress';
      case ClothingSlot.outerwear:
        return 'Outerwear';
      case ClothingSlot.footwear:
        return 'Footwear';
      case ClothingSlot.bag:
        return 'Bag';
      case ClothingSlot.accessory:
        return 'Accessory';
      case ClothingSlot.other:
        return 'Other';
    }
  }

  /// Localised label for use inside widget build methods.
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ClothingSlot.top:
        return l10n.clothingSlotTop;
      case ClothingSlot.bottom:
        return l10n.clothingSlotBottom;
      case ClothingSlot.dress:
        return l10n.clothingSlotDress;
      case ClothingSlot.outerwear:
        return l10n.clothingSlotOuterwear;
      case ClothingSlot.footwear:
        return l10n.clothingSlotFootwear;
      case ClothingSlot.bag:
        return l10n.clothingSlotBag;
      case ClothingSlot.accessory:
        return l10n.clothingSlotAccessory;
      case ClothingSlot.other:
        return l10n.clothingSlotOther;
    }
  }
}

class ItemSlotAnalyzer {
  static ClothingSlot getSlot(String? name, String category) {
    final text = '${(name ?? '').toLowerCase()} ${category.toLowerCase()}';

    if (text.contains('dress') || text.contains('gown') || text.contains('jumpsuit')) {
      return ClothingSlot.dress;
    }
    if (text.contains('shirt') ||
        text.contains('blouse') ||
        text.contains('top') ||
        text.contains('tshirt') ||
        text.contains('t-shirt') ||
        text.contains('sweater') ||
        text.contains('kurta') ||
        text.contains('tunic')) {
      return ClothingSlot.top;
    }
    if (text.contains('pant') ||
        text.contains('trouser') ||
        text.contains('jeans') ||
        text.contains('skirt') ||
        text.contains('legging')) {
      return ClothingSlot.bottom;
    }
    if (text.contains('jacket') ||
        text.contains('coat') ||
        text.contains('blazer') ||
        text.contains('cardigan') ||
        text.contains('shawl')) {
      return ClothingSlot.outerwear;
    }
    if (text.contains('shoe') ||
        text.contains('sneaker') ||
        text.contains('heel') ||
        text.contains('boot') ||
        text.contains('sandal') ||
        text.contains('loafer') ||
        text.contains('footwear')) {
      return ClothingSlot.footwear;
    }
    if (text.contains('bag') || text.contains('purse') || text.contains('tote')) {
      return ClothingSlot.bag;
    }
    if (text.contains('earring') ||
        text.contains('necklace') ||
        text.contains('bracelet') ||
        text.contains('ring') ||
        text.contains('watch') ||
        text.contains('hat') ||
        text.contains('scarf') ||
        text.contains('accessory')) {
      return ClothingSlot.accessory;
    }

    return ClothingSlot.other;
  }
}

// ============================================================
// BUILD OUTFIT SCREEN
// ============================================================
class BuildOutfitScreen extends StatefulWidget {
  final WardrobeItem? initialItem;
  final List<WardrobeItem> allItems;
  final VoidCallback? onOutfitCreated;

  const BuildOutfitScreen({
    this.initialItem,
    required this.allItems,
    this.onOutfitCreated,
  });

  @override
  State<BuildOutfitScreen> createState() => _BuildOutfitScreenState();
}

class _BuildOutfitScreenState extends State<BuildOutfitScreen> {
  late List<WardrobeItem> selectedItems;
  final TextEditingController outfitNameController = TextEditingController();
  ClothingSlot? selectedSlotFilter;

  @override
  void initState() {
    super.initState();
    selectedItems = widget.initialItem != null ? [widget.initialItem!] : [];
  }

  @override
  void dispose() {
    outfitNameController.dispose();
    super.dispose();
  }

  void toggleItemSelection(WardrobeItem item) {
    setState(() {
      if (selectedItems.contains(item)) {
        selectedItems.remove(item);
      } else {
        selectedItems.add(item);
      }
    });
  }

  List<WardrobeItem> getFilteredItems() {
    if (selectedSlotFilter == null) {
      return widget.allItems;
    }
    return widget.allItems.where((item) {
      final slot = ItemSlotAnalyzer.getSlot(item.name, item.cat);
      return slot == selectedSlotFilter;
    }).toList();
  }

  void saveOutfit() {
    if (selectedItems.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.buildOutfitSelectAtLeastOneItem)),
      );
      return;
    }

    final outfit = Outfit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: outfitNameController.text,
      items: selectedItems,
    );

    Navigator.pop(context, outfit);
    widget.onOutfitCreated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>()!;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: t.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: t.backgroundPrimary,
        elevation: 0,
        title: Text(
          l10n.buildOutfitTitle,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Outfit name input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: outfitNameController,
              decoration: InputDecoration(
                hintText: l10n.buildOutfitNameHint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: t.mutedText,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: t.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: t.accent.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: t.textPrimary,
              ),
            ),
          ),

          // Slot filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.buildOutfitFilterAll,
                  isSelected: selectedSlotFilter == null,
                  onTap: () => setState(() => selectedSlotFilter = null),
                  t: t,
                ),
                ...ClothingSlot.values.map((slot) {
                  return _FilterChip(
                    label: slot.localizedLabel(context),
                    isSelected: selectedSlotFilter == slot,
                    onTap: () => setState(() => selectedSlotFilter = slot),
                    t: t,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Selected items preview (compact)
          if (selectedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.buildOutfitSelectedItems(selectedItems.length),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.accent.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedItems.map((item) {
                      return Chip(
                        label: Text(
                          item.name ?? item.cat,
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => toggleItemSelection(item),
                        backgroundColor: t.accent.primary.withValues(alpha: 0.1),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          color: t.accent.primary,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Items grid with style_boards layout
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildUnifiedGrid(context, t, getFilteredItems()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.cardBorder)),
          color: t.backgroundPrimary,
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.buildOutfitCancel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: selectedItems.isEmpty ? null : saveOutfit,
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent.primary,
                  disabledBackgroundColor: t.accent.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.buildOutfitSaveOutfit,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

  // ============================================================
  // LAYOUT DISPATCHER (from style_boards)
  // ============================================================
  static const double _kGap = 10.0;

  Widget _buildUnifiedGrid(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    if (items.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.buildOutfitNoItemsAvailable,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: t.mutedText,
            ),
          ),
        ),
      );
    }

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

  // 1–2 items: equal columns
  Widget _layoutSmall(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: items.length,
        crossAxisSpacing: _kGap,
        mainAxisSpacing: _kGap,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildItemCard(context, items[i], t),
    );
  }

  // 3 items: 52% left column (2 items), right side (1 big item)
  Widget _layout3(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final lw = w * 0.52 - g / 2;
      final rw = w - lw - g;
      final ih = lw * 0.95;
      final totalH = ih * 2 + g;

      return SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: lw,
              child: Column(
                children: [
                  SizedBox(height: ih, child: _buildItemCard(context, items[0], t)),
                  SizedBox(height: g),
                  SizedBox(height: ih, child: _buildItemCard(context, items[1], t)),
                ],
              ),
            ),
            SizedBox(width: g),
            SizedBox(
              width: rw,
              height: totalH,
              child: _buildItemCard(context, items[2], t),
            ),
          ],
        ),
      );
    });
  }

  // 4 items: 2x2 grid
  Widget _layout4(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final cw = (w - g) / 2;
      final ih = cw;

      return Column(
        children: [
          _row2(context, t, items[0], items[1], cw, ih),
          SizedBox(height: g),
          _row2(context, t, items[2], items[3], cw, ih),
        ],
      );
    });
  }

  // 5 items: top 2 (responsive), bottom 3
  Widget _layout5(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
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

  // 6 items: Left 2 BIG, Right 2 MEDIUM, Bottom 3 EQUAL
  Widget _layout6(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      // Left column: 2 big items
      final leftW = w * 0.45 - g / 2;
      final leftItemH = (leftW - g) / 2;  // Each item gets half height, minus gap

      // Right column: 2 medium items
      final rightW = w - leftW - g;
      final rightItemH = leftItemH;  // Same height as left items

      // Total height of top section
      final topH = leftItemH * 2 + g;

      // Bottom row: 3 equal items
      final botCw = (w - 2 * g) / 3;
      final botH = botCw;

      return Column(
        children: [
          // Top section: Left 2 big, Right 2 medium
          SizedBox(
            height: topH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left column: 2 stacked big items
                SizedBox(
                  width: leftW,
                  child: Column(
                    children: [
                      SizedBox(height: leftItemH, child: _buildItemCard(context, items[0], t)),
                      SizedBox(height: g),
                      SizedBox(height: leftItemH, child: _buildItemCard(context, items[1], t)),
                    ],
                  ),
                ),
                SizedBox(width: g),
                // Right column: 2 stacked medium items
                SizedBox(
                  width: rightW,
                  child: Column(
                    children: [
                      SizedBox(height: rightItemH, child: _buildItemCard(context, items[2], t)),
                      SizedBox(height: g),
                      SizedBox(height: rightItemH, child: _buildItemCard(context, items[3], t)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: g),
          // Bottom section: 3 equal items
          Row(
            children: [
              SizedBox(width: botCw, height: botH, child: _buildItemCard(context, items[4], t)),
              SizedBox(width: g),
              SizedBox(width: botCw, height: botH, child: _buildItemCard(context, items[5], t)),
              SizedBox(width: g),
              SizedBox(width: botCw, height: botH, child: _buildItemCard(context, items[6], t)),
            ],
          ),
        ],
      );
    });
  }

  // 7 items: top 3, bottom 4
  Widget _layout7(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      final topCw = (w - 2 * g) / 3;
      final topH = topCw;
      final botCw = (w - 3 * g) / 4;
      final botH = botCw;

      return Column(
        children: [
          _row3(context, t, items[0], items[1], items[2], topCw, topH),
          SizedBox(height: g),
          _row4(context, t, items[3], items[4], items[5], items[6], botCw, botH),
        ],
      );
    });
  }

  // 8 items: Left 2 BIG (stacked full height), Right 6 (3x2 grid)
  Widget _layout8(
      BuildContext context, AppThemeTokens t, List<WardrobeItem> items) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      const double g = _kGap;

      // Left column: 2 big items (stacked, full height)
      final leftW = w * 0.45 - g / 2;
      final leftItemH = (leftW * 1.3) / 2;  // Taller items

      // Right side: 6 items in 3 rows × 2 columns
      final rightW = w - leftW - g;
      final rightColW = (rightW - g) / 2;
      final rightRowH = (leftItemH * 2 + g) / 3;  // 3 rows total

      final totalHeight = leftItemH * 2 + g;

      return SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: 2 stacked big items
            SizedBox(
              width: leftW,
              child: Column(
                children: [
                  SizedBox(height: leftItemH, child: _buildItemCard(context, items[0], t)),
                  SizedBox(height: g),
                  SizedBox(height: leftItemH, child: _buildItemCard(context, items[1], t)),
                ],
              ),
            ),
            SizedBox(width: g),
            // Right section: 6 items in 3 rows × 2 columns
            SizedBox(
              width: rightW,
              child: Column(
                children: [
                  // Row 1
                  Row(
                    children: [
                      SizedBox(width: rightColW, height: rightRowH, child: _buildItemCard(context, items[2], t)),
                      SizedBox(width: g),
                      SizedBox(width: rightColW, height: rightRowH, child: _buildItemCard(context, items[3], t)),
                    ],
                  ),
                  SizedBox(height: g),
                  // Row 2
                  Row(
                    children: [
                      SizedBox(width: rightColW, height: rightRowH, child: _buildItemCard(context, items[4], t)),
                      SizedBox(width: g),
                      SizedBox(width: rightColW, height: rightRowH, child: _buildItemCard(context, items[5], t)),
                    ],
                  ),
                  SizedBox(height: g),
                  // Row 3
                  Row(
                    children: [
                      SizedBox(width: rightColW, height: rightRowH, child: _buildItemCard(context, items[6], t)),
                      SizedBox(width: g),
                      SizedBox(width: rightColW, height: rightRowH, child: _buildItemCard(context, items[7], t)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // Helper: 2-item row
  Widget _row2(BuildContext context, AppThemeTokens t, WardrobeItem a,
      WardrobeItem b, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, a, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, b, t)),
      ],
    );
  }

  // Helper: 3-item row
  Widget _row3(BuildContext context, AppThemeTokens t, WardrobeItem a,
      WardrobeItem b, WardrobeItem c, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, a, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, b, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, c, t)),
      ],
    );
  }

  // Helper: 4-item row
  Widget _row4(BuildContext context, AppThemeTokens t, WardrobeItem a,
      WardrobeItem b, WardrobeItem c, WardrobeItem d, double cw, double ih) {
    return Row(
      children: [
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, a, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, b, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, c, t)),
        SizedBox(width: _kGap),
        SizedBox(width: cw, height: ih, child: _buildItemCard(context, d, t)),
      ],
    );
  }

  // Item card widget
  Widget _buildItemCard(BuildContext context, WardrobeItem item, AppThemeTokens t) {
    final isSelected = selectedItems.contains(item);
    final slot = ItemSlotAnalyzer.getSlot(item.name, item.cat);

    return GestureDetector(
      onTap: () => toggleItemSelection(item),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? t.accent.primary : t.cardBorder,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? t.accent.primary.withValues(alpha: 0.08) : t.backgroundPrimary,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Item image
            Positioned.fill(
              child: Container(
                color: const Color(0xFFF5F5F7),
                child: item.displayUrl != null && item.displayUrl!.isNotEmpty
                    ? Image.network(
                  item.displayUrl!,
                  fit: BoxFit.cover,
                )
                    : Icon(
                  Icons.checkroom,
                  color: t.mutedText,
                  size: 32,
                ),
              ),
            ),
            // Selection overlay
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: t.accent.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            // Item info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name ?? item.cat,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      slot.localizedLabel(context),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
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
// FILTER CHIP WIDGET
// ============================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeTokens t;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: t.backgroundPrimary,
        selectedColor: t.accent.primary.withValues(alpha: 0.15),
        side: BorderSide(
          color: isSelected ? t.accent.primary : t.cardBorder,
          width: isSelected ? 2 : 1,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? t.accent.primary : t.textPrimary,
        ),
      ),
    );
  }
}