import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:myapp/widgets/ahvi_home_text.dart';
import 'package:myapp/theme/theme_tokens.dart';

/// ── AhviHeader ──────────────────────────────────────────────────────────────
/// One reusable, STATIC header used by Home, Chat, Boards, and Wardrobe.
///
/// Rules that keep it perfectly stable:
///   • It is a StatelessWidget — same props → Flutter skips rebuild entirely.
///   • It uses MediaQuery.sizeOf() for the font-size branch (size-only,
///     no viewInsets subscription → keyboard can't trigger a rebuild here).
///   • It must always be the FIRST child of a Column, NEVER inside
///     AnimatedBuilder / ValueListenableBuilder / setState-heavy widgets.
///
/// Usage examples
/// ──────────────
/// Home (inside Positioned, top: 0):
///   AhviHeader(right: _buildProfileAvatar())
///
/// Chat:
///   AhviHeader(showBack: true, right: IconButton(...historyDrawer))
///
/// Boards / Wardrobe:
///   const AhviHeader()
class AhviHeader extends StatelessWidget {
  /// Show the back-arrow on the left (Chat, detail screens).
  final bool showBack;

  /// Custom back handler. Falls back to Navigator.pop() when null.
  final VoidCallback? onBack;

  /// Optional widget pinned to the right (profile avatar, history icon, etc.).
  final Widget? right;

  /// Draw a hairline bottom border (matches Wardrobe / Chat header style).
  final bool showBorder;

  /// Slight frosted-glass bg so content scrolls cleanly underneath.
  final bool frosted;

  const AhviHeader({
    super.key,
    this.showBack = false,
    this.onBack,
    this.right,
    this.showBorder = false,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    // Use sizeOf — subscribes ONLY to size changes, not viewInsets.
    // Keyboard open/close never triggers a rebuild of this widget.
    final screenH = MediaQuery.sizeOf(context).height;
    final double topPad = screenH < 700 ? 12.0 : 16.0;
    final double botPad = screenH < 700 ? 4.0 : 6.0;
    final double logoSize = screenH < 700 ? 26.0 : 30.0;

    // NOT a Hero. The tag 'ahvi_logo' lived only in this shared header, so it
    // never had a counterpart on another screen to animate to — every
    // navigation just placed two identical-tag heroes in one transition
    // subtree, throwing "multiple heroes share the same tag" -> red error
    // flash on open. The Hero gave no benefit, only collisions.
    Widget logo = AhviHomeText(
      color: t.textPrimary,
      fontSize: logoSize,
      letterSpacing: 3.2,
      fontWeight: FontWeight.w400,
    );

    return SafeArea(
      bottom: false,
      child: ClipRect(
        child: BackdropFilter(
          // frosted=true → blur; frosted=false → ImageFilter.matrix identity (no-op)
          filter: frosted
              ? ImageFilter.blur(sigmaX: 18, sigmaY: 18)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // frosted=true → very subtle tint (no hard edge), false → fully transparent
              color: frosted
                  ? t.backgroundPrimary.withValues(alpha: 0.55)
                  : Colors.transparent,
              border: showBorder
                  ? Border(bottom: BorderSide(color: t.cardBorder, width: 0.5))
                  : null,
            ),
            child: SizedBox(
              height: topPad + logoSize + botPad,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPad, 20, botPad),
                child: Row(
                  children: [
                    if (showBack) ...[
                      GestureDetector(
                        onTap: onBack ?? () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: t.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                    logo,
                    const Spacer(),
                    // ✏️ FIX: The Row here gets a TIGHT height constraint of just
                    // `logoSize` (26–30px). A raw UnconstrainedBox let a taller
                    // `right` widget (e.g. the 40×40 profile avatar) render at its
                    // full size, which fixed the oval-squish but then overflowed/
                    // clipped against this header's fixed overall height on
                    // smaller screens. Wrapping in a SizedBox(logoSize × logoSize)
                    // + FittedBox instead scales `right` down uniformly (preserving
                    // its aspect ratio, so circles stay circles) to exactly fit the
                    // available space — no squish, no overflow.
                    if (right != null)
                      SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: right!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}