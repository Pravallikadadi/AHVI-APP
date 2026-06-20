// ============================================================
// ahvi_3step_upload_flow.dart
// 3-Step progressive modal for single & multi-item wardrobe uploads.
//
// UI-ONLY DTO: UploadPreviewItem. This does NOT replace the existing private
// _DetectedItem detection flow in wardrobe.dart — the graft point maps a
// detected item into UploadPreviewItem just for this modal's presentation.
// `id` mirrors the source detected-item id so the host can map the user's
// selection back to the real items on confirm.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/theme_tokens.dart';

// ============================================================
// UI-ONLY DTO
// ============================================================
class UploadPreviewItem {
  final String id; // mirrors the source _DetectedItem.id
  String name;
  String color;
  String style;
  String category;
  List<String> occasions;
  final List<String> pairsWith;
  final String? imageUrl;
  final Uint8List? previewBytes;
  final String validationStatus;
  final String? rejectionReason;
  final bool selectedByDefault;
  final double? cropQualityScore;
  final String? detectionMode;
  final String? regenProvider;
  final String? inputType;
  bool isSelected;

  UploadPreviewItem({
    required this.id,
    required this.name,
    this.color = '',
    this.style = '',
    this.category = '',
    this.occasions = const [],
    this.pairsWith = const [],
    this.imageUrl,
    this.previewBytes,
    String validationStatus = 'ok',
    this.rejectionReason,
    bool? selectedByDefault,
    this.cropQualityScore,
    this.detectionMode,
    this.regenProvider,
    this.inputType,
    bool? isSelected,
  }) : validationStatus = validationStatus.trim().toLowerCase().isEmpty
           ? 'ok'
           : validationStatus.trim().toLowerCase(),
       selectedByDefault =
           selectedByDefault ?? validationStatus.trim().toLowerCase() == 'ok',
       isSelected =
           isSelected ??
           (selectedByDefault ?? validationStatus.trim().toLowerCase() == 'ok');

  bool get isApproved => validationStatus == 'ok';
  bool get isNeedsReview => validationStatus == 'needs_review';
  bool get isRejected => validationStatus == 'rejected';
  bool get isSaveable => isApproved;
  String? get statusLabel {
    if (isNeedsReview) return 'Needs review';
    if (isRejected) return 'Rejected';
    return null;
  }
}

// ============================================================
// MAIN MODAL
// ============================================================
class Ahvi3StepUploadModal extends StatefulWidget {
  final List<UploadPreviewItem> items;
  final VoidCallback onClose;
  final void Function(List<UploadPreviewItem> selected) onConfirm;
  final String? originalImageUrl;

  const Ahvi3StepUploadModal({
    super.key,
    required this.items,
    required this.onClose,
    required this.onConfirm,
    this.originalImageUrl,
  });

  @override
  State<Ahvi3StepUploadModal> createState() => _Ahvi3StepUploadModalState();
}

class _Ahvi3StepUploadModalState extends State<Ahvi3StepUploadModal> {
  // 0 = Understanding, 1 = Reveal, 2 = Insight
  int _currentStep = 0;
  int _currentItemIndex = 0;
  bool _advanced = false;

  late final PageController _carouselCtrl;
  late final List<UploadPreviewItem> _items;

  final List<String> _detectionChecks = [
    'Item type detected',
    'Color identified',
    'Style profile analyzed',
    'Occasion suitability assessed',
  ];
  late List<bool> _checklistComplete;

  @override
  void initState() {
    super.initState();
    _carouselCtrl = PageController();
    _items = List.of(widget.items);
    _checklistComplete = List.filled(_detectionChecks.length, false);
    _startStep1Animation();
  }

  @override
  void dispose() {
    _carouselCtrl.dispose();
    super.dispose();
  }

  void _startStep1Animation() {
    for (int i = 0; i < _detectionChecks.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + (i * 150)), () {
        if (mounted) setState(() => _checklistComplete[i] = true);
      });
    }
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !_advanced) _goToStep(1);
    });
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      if (step >= 1) _advanced = true;
    });
  }

  void _onItemSelected(int index) {
    if (!_items[index].isSaveable) return;
    setState(() => _items[index].isSelected = !_items[index].isSelected);
  }

  void _submitSelection() {
    final selected = _items.where((i) => i.isSelected && i.isSaveable).toList();
    if (selected.isEmpty) return;
    widget.onConfirm(selected);
    widget.onClose();
  }

  Future<void> _editItem(UploadPreviewItem item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final categoryCtrl = TextEditingController(text: item.category);
    final styleCtrl = TextEditingController(text: item.style);
    final occasionCtrl = TextEditingController(text: item.occasions.join(', '));
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: styleCtrl,
                  decoration: const InputDecoration(labelText: 'Sub-category'),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: occasionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags / occasions',
                    hintText: 'Work, casual, festive',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop({
                  'name': nameCtrl.text.trim(),
                  'category': categoryCtrl.text.trim(),
                  'style': styleCtrl.text.trim(),
                  'occasions': occasionCtrl.text
                      .split(',')
                      .map((v) => v.trim())
                      .where((v) => v.isNotEmpty)
                      .toList(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    nameCtrl.dispose();
    categoryCtrl.dispose();
    styleCtrl.dispose();
    occasionCtrl.dispose();
    if (result == null || !mounted) return;
    setState(() {
      final nextName = (result['name'] ?? '').toString().trim();
      final nextCategory = (result['category'] ?? '').toString().trim();
      final nextStyle = (result['style'] ?? '').toString().trim();
      item.name = nextName.isNotEmpty ? nextName : item.name;
      item.category = nextCategory.isNotEmpty ? nextCategory : item.category;
      item.style = nextStyle.isNotEmpty ? nextStyle : item.style;
      item.occasions = List<String>.from(
        result['occasions'] as List? ?? const [],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSingleItem = _items.length == 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Step content — AnimatedSwitcher replaces the dead
                    // _stepTransitionCtrl; cross-fades between steps.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildStepBody(isSingleItem),
                      ),
                    ),

                    // Close button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black26,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // Back button (Reveal/Insight)
                    if (_currentStep >= 1)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => _goToStep(_currentStep - 1),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentStep == 2
                                  ? Colors.black26
                                  : Colors.black12,
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: _currentStep == 2
                                  ? Colors.white
                                  : Colors.black87,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(bool isSingleItem) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Understanding();
      case 1:
        return _buildStep2Reveal(isSingleItem);
      default:
        return _buildStep3Insight(isSingleItem);
    }
  }

  // ============================================================
  // STEP 1: UNDERSTANDING
  // ============================================================
  Widget _buildStep1Understanding() {
    final t = Theme.of(context).extension<AppThemeTokens>()!;

    return Container(
      width: 400,
      height: 800,
      decoration: BoxDecoration(
        image: widget.originalImageUrl != null
            ? DecorationImage(
                image: NetworkImage(widget.originalImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
        color: const Color(0xFF1a1a1a),
      ),
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: 0.6)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _AnimatingSparkle(),
                const SizedBox(height: 24),
                Text(
                  'AHVI is understanding\nthis piece...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Column(
                  children: List.generate(
                    _detectionChecks.length,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          AnimatedOpacity(
                            opacity: _checklistComplete[index] ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.accent.primary,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _detectionChecks[index],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Analyzing visual features...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.accent.primary, t.accent.secondary],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2: EDITORIAL REVEAL (working multi-item carousel)
  // ============================================================
  Widget _buildStep2Reveal(bool isSingleItem) {
    final t = Theme.of(context).extension<AppThemeTokens>()!;

    return Container(
      width: 400,
      height: 800,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 56),
          // Counter + dots (multi-item)
          if (!isSingleItem) ...[
            Text(
              '${_currentItemIndex + 1} / ${_items.length}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_items.length, (i) {
                final active = i == _currentItemIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? t.accent.primary : const Color(0xFFD8D8E0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],

          // Carousel — PageView.builder drives image/name/specs/dots/counter.
          Expanded(
            child: PageView.builder(
              controller: _carouselCtrl,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _currentItemIndex = i),
              itemBuilder: (_, i) => _revealPage(_items[i], t),
            ),
          ),

          // Prev / Next + CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                if (!isSingleItem)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _carouselArrow(
                        icon: Icons.chevron_left_rounded,
                        enabled: _currentItemIndex > 0,
                        onTap: () => _carouselCtrl.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                      _carouselArrow(
                        icon: Icons.chevron_right_rounded,
                        enabled: _currentItemIndex < _items.length - 1,
                        onTap: () => _carouselCtrl.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: MaterialButton(
                    onPressed: () => _goToStep(2),
                    color: t.accent.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carouselArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF2F2F7),
          ),
          child: Icon(icon, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _revealPage(UploadPreviewItem item, AppThemeTokens t) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFEFEFF7),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _itemImage(item, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _editItem(item),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit label / tags'),
                ),
                if (item.statusLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      item.statusLabel!,
                      if ((item.rejectionReason ?? '').trim().isNotEmpty)
                        item.rejectionReason!.trim(),
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  [
                    item.color,
                    item.style,
                  ].where((s) => s.trim().isNotEmpty).join(' • '),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: AHVI INSIGHT (HTML layout — hero + gradient + floating card)
  // ============================================================
  Widget _buildStep3Insight(bool isSingleItem) {
    final t = Theme.of(context).extension<AppThemeTokens>()!;
    final item = _items[_currentItemIndex];
    final selectedCount = _items
        .where((i) => i.isSelected && i.isSaveable)
        .length;
    final bestFor = _bestForOccasions(item);

    return Container(
      width: 400,
      height: 800,
      color: const Color(0xFF1a1a1a),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Hero image + dark gradient overlay ----
            SizedBox(
              height: 320,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _itemImage(item, fit: BoxFit.cover),
                  // Dark gradient overlay (top subtle, bottom heavy).
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black26,
                          Colors.transparent,
                          Color(0xFF1a1a1a),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // Item name over hero bottom.
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if ([
                          item.color,
                          item.style,
                        ].where((s) => s.trim().isNotEmpty).isNotEmpty)
                          Text(
                            [
                              item.color,
                              item.style,
                            ].where((s) => s.trim().isNotEmpty).join(' • '),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- Floating AHVI Insight card (margin:-60 equivalent) ----
            Transform.translate(
              offset: const Offset(0, -60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const _AnimatingSparkle(size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'AHVI Insight',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: t.accent.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Clear intelligence. No stylist, just insight.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ---- Best For (dynamic from occasions) ----
                      if (bestFor.isNotEmpty) ...[
                        _sectionLabel('Best For'),
                        const SizedBox(height: 12),
                        Row(
                          children: bestFor
                              .map(
                                (o) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _occasionBadge(
                                      _iconForOccasion(o),
                                      o,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ---- Pairs Well With ----
                      if (item.pairsWith.isNotEmpty) ...[
                        _sectionLabel('Pairs Well With'),
                        const SizedBox(height: 12),
                        ...item.pairsWith
                            .take(4)
                            .map(
                              (pair) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: t.accent.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      pair,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        const SizedBox(height: 24),
                      ],

                      // ---- Multi-item selection ----
                      if (!isSingleItem && _items.length > 1) ...[
                        _sectionLabel('Add to Wardrobe'),
                        const SizedBox(height: 12),
                        ...List.generate(_items.length, (index) {
                          final it = _items[index];
                          final saveable = it.isSaveable;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: GestureDetector(
                              onTap: saveable
                                  ? () => _onItemSelected(index)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: it.isSelected
                                        ? t.accent.primary
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      it.isSelected && saveable
                                          ? Icons.check_box_rounded
                                          : saveable
                                          ? Icons.check_box_outline_blank
                                          : Icons.block_rounded,
                                      size: 20,
                                      color: it.isSelected && saveable
                                          ? t.accent.primary
                                          : Colors.white38,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            it.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: saveable
                                                  ? Colors.white
                                                  : Colors.white60,
                                            ),
                                          ),
                                          if (it.statusLabel != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              [
                                                it.statusLabel!,
                                                if ((it.rejectionReason ?? '')
                                                    .trim()
                                                    .isNotEmpty)
                                                  it.rejectionReason!.trim(),
                                              ].join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      // ---- Confirm CTA ----
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: MaterialButton(
                          onPressed: selectedCount > 0
                              ? _submitSelection
                              : null,
                          color: selectedCount > 0
                              ? t.accent.primary
                              : const Color(0xFF3A3A3A),
                          disabledColor: const Color(0xFF3A3A3A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 4,
                          disabledElevation: 0,
                          child: Text(
                            isSingleItem
                                ? (selectedCount > 0
                                      ? 'Add 1 approved item'
                                      : 'No approved items to add')
                                : selectedCount == 0
                                ? 'No approved items to add'
                                : 'Add $selectedCount approved item${selectedCount != 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: selectedCount > 0
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---- Privacy note ----
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Your data is private and secure',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
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

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _itemImage(UploadPreviewItem item, {required BoxFit fit}) {
    if (item.previewBytes != null && item.previewBytes!.isNotEmpty) {
      return Image.memory(item.previewBytes!, fit: fit);
    }
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return Image.network(
        item.imageUrl!,
        fit: fit,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => Container(
    color: const Color(0xFFEFEFF7),
    child: const Icon(Icons.checkroom, size: 48, color: Color(0xFFBFBFD6)),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.white70,
      letterSpacing: 0.5,
    ),
  );

  Widget _occasionBadge(String emoji, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // Dynamic Best For: from item.occasions, suitability-guarded.
  // Never surfaces office/event/formal labels for sleepwear, underwear,
  // or gym-only garments.
  List<String> _bestForOccasions(UploadPreviewItem item) {
    final blob = '${item.category} ${item.name} ${item.style}'.toLowerCase();
    final isPrivate =
        blob.contains('innerwear') ||
        blob.contains('underwear') ||
        blob.contains('lingerie') ||
        blob.contains('sleep') ||
        blob.contains('night') ||
        blob.contains('pajama') ||
        blob.contains('pyjama') ||
        blob.contains('boxer') ||
        blob.contains('brief');
    final isActive =
        blob.contains('gym') ||
        blob.contains('sport') ||
        blob.contains('active') ||
        blob.contains('track');

    const formalish = [
      'office',
      'work',
      'meeting',
      'event',
      'evening',
      'formal',
      'wedding',
      'party',
      'dinner',
      'business',
    ];

    var occ = item.occasions
        .map(_titleCase)
        .where((o) => o.trim().isNotEmpty)
        .toSet()
        .toList();

    if (isPrivate || isActive) {
      occ = occ
          .where((o) => !formalish.any((f) => o.toLowerCase().contains(f)))
          .toList();
      if (occ.isEmpty) {
        occ = isPrivate ? ['Loungewear'] : ['Workout'];
      }
    }
    if (occ.isEmpty) {
      occ = ['Everyday'];
    }
    return occ.take(3).toList();
  }

  String _iconForOccasion(String occasion) {
    final o = occasion.toLowerCase();
    // Active first so "Workout" doesn't fall into the office/work branch.
    if (o.contains('gym') ||
        o.contains('workout') ||
        o.contains('sport') ||
        o.contains('active')) {
      return '🏋️';
    }
    if (o.contains('office') ||
        o.contains('work') ||
        o.contains('business') ||
        o.contains('meeting')) {
      return '💼';
    }
    if (o.contains('smart')) {
      return '🎯';
    }
    if (o.contains('evening') || o.contains('event') || o.contains('party')) {
      return '🎭';
    }
    if (o.contains('date')) {
      return '💕';
    }
    if (o.contains('travel')) {
      return '✈️';
    }
    if (o.contains('beach') || o.contains('resort')) {
      return '🏖️';
    }
    if (o.contains('wedding')) {
      return '💍';
    }
    if (o.contains('formal')) {
      return '🤵';
    }
    if (o.contains('loung') || o.contains('sleep') || o.contains('night')) {
      return '🛋️';
    }
    if (o.contains('casual') ||
        o.contains('daily') ||
        o.contains('weekend') ||
        o.contains('everyday')) {
      return '☕';
    }
    return '👔';
  }

  String _titleCase(String s) {
    final v = s.trim();
    if (v.isEmpty) return v;
    return v
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

// ============================================================
// ANIMATED SPARKLE
// ============================================================
class _AnimatingSparkle extends StatefulWidget {
  final double size;
  const _AnimatingSparkle({this.size = 32});

  @override
  State<_AnimatingSparkle> createState() => _AnimatingSparkleState();
}

class _AnimatingSparkleState extends State<_AnimatingSparkle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * 2 * 3.14159,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: widget.size,
          color: Colors.amber[400],
        ),
      ),
    );
  }
}
