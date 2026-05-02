import 'package:flutter/material.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';

// ── Convenience function ───────────────────────────────────────────────────
void showAhviLensSheet(
  BuildContext context, {
  required AppThemeTokens t,
  VoidCallback? onVisualSearch,
  VoidCallback? onFindSimilar,
  VoidCallback? onAddToWardrobe,
}) {
  // Capture navigator BEFORE overlay insert — its context stays valid after overlay is removed
  final navigator = Navigator.of(context, rootNavigator: true);
  final effectiveOnAddToWardrobe = onAddToWardrobe ??
      () => showAddToWardrobeModal(navigator.context);

  final renderBox = context.findRenderObject() as RenderBox;
  final buttonPos = renderBox.localToGlobal(Offset.zero);
  final buttonSize = renderBox.size;

  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _AhviLensOverlay(
      buttonPos: buttonPos,
      buttonSize: buttonSize,
      t: t,
      onVisualSearch: onVisualSearch,
      onFindSimilar: onFindSimilar,
      onAddToWardrobe: effectiveOnAddToWardrobe,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

// ── Overlay wrapper ────────────────────────────────────────────────────────
class _AhviLensOverlay extends StatefulWidget {
  final Offset buttonPos;
  final Size buttonSize;
  final AppThemeTokens t;
  final VoidCallback? onVisualSearch;
  final VoidCallback? onFindSimilar;
  final VoidCallback? onAddToWardrobe;
  final VoidCallback onDismiss;

  const _AhviLensOverlay({
    required this.buttonPos,
    required this.buttonSize,
    required this.t,
    required this.onDismiss,
    this.onVisualSearch,
    this.onFindSimilar,
    this.onAddToWardrobe,
  });

  @override
  State<_AhviLensOverlay> createState() => _AhviLensOverlayState();
}

class _AhviLensOverlayState extends State<_AhviLensOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss({VoidCallback? afterDismiss}) async {
    await _ctrl.reverse();
    widget.onDismiss();
    if (afterDismiss != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => afterDismiss());
    }
  }

  @override
  Widget build(BuildContext context) {
    const popupWidth = 260.0;
    const gap = 8.0;
    final screenSize = MediaQuery.of(context).size;
    final bottom = screenSize.height - widget.buttonPos.dy + gap;
    final left =
        widget.buttonPos.dx.clamp(12.0, screenSize.width - popupWidth - 12.0);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          bottom: bottom,
          width: popupWidth,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _AhviLensMenu(
                t: widget.t,
                onVisualSearch: () =>
                    _dismiss(afterDismiss: widget.onVisualSearch),
                onFindSimilar: () =>
                    _dismiss(afterDismiss: widget.onFindSimilar),
                onAddToWardrobe: () {
                  // Skip animation — remove overlay immediately so dialog can open cleanly
                  _ctrl.stop();
                  widget.onDismiss(); // removes overlay entry right now
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onAddToWardrobe?.call();
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Menu card ─────────────────────────────────────────────────────────────
class _AhviLensMenu extends StatelessWidget {
  final AppThemeTokens t;
  final VoidCallback onVisualSearch;
  final VoidCallback onFindSimilar;
  final VoidCallback onAddToWardrobe;

  const _AhviLensMenu({
    required this.t,
    required this.onVisualSearch,
    required this.onFindSimilar,
    required this.onAddToWardrobe,
  });

  @override
  Widget build(BuildContext context) {
    final accent = t.accent.primary;
    final accentSecondary = t.accent.secondary;
    final textHeading = t.textPrimary;
    final textMuted = t.mutedText;
    final panel = t.panel;
    final surface = t.phoneShellInner;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: accent, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'AHVI Lens',
                    style: TextStyle(
                      color: textHeading,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            _Divider(color: accent),
            _LensTile(
              icon: Icons.image_search_rounded,
              label: AppLocalizations.t(context, 'lens_visual_ai_search'),
              desc: AppLocalizations.t(context, 'lens_visual_ai_desc'),
              iconColor: accent,
              textHeading: textHeading,
              textMuted: textMuted,
              panel: panel,
              accent: accent,
              onTap: onVisualSearch,
            ),
            _Divider(color: accent),
            _LensTile(
              icon: Icons.search_rounded,
              label: AppLocalizations.t(context, 'lens_find_similar'),
              desc: AppLocalizations.t(context, 'lens_find_similar_desc'),
              iconColor: accent,
              textHeading: textHeading,
              textMuted: textMuted,
              panel: panel,
              accent: accent,
              onTap: onFindSimilar,
            ),
            _Divider(color: accent),
            _LensTile(
              icon: Icons.add_photo_alternate_outlined,
              label: AppLocalizations.t(context, 'lens_add_wardrobe'),
              desc: AppLocalizations.t(context, 'lens_add_wardrobe_desc'),
              iconColor: accentSecondary,
              textHeading: textHeading,
              textMuted: textMuted,
              panel: panel,
              accent: accent,
              onTap: onAddToWardrobe,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thin divider ──────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: color.withValues(alpha: 0.12),
      indent: 14,
      endIndent: 14,
    );
  }
}

// ── Compact option tile ───────────────────────────────────────────────────
class _LensTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color iconColor;
  final Color textHeading;
  final Color textMuted;
  final Color panel;
  final Color accent;
  final VoidCallback onTap;

  const _LensTile({
    required this.icon,
    required this.label,
    required this.desc,
    required this.iconColor,
    required this.textHeading,
    required this.textMuted,
    required this.panel,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_LensTile> createState() => _LensTileState();
}

class _LensTileState extends State<_LensTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(widget.icon, color: widget.iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.textHeading,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.desc,
                    style: TextStyle(
                      color: widget.textMuted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}