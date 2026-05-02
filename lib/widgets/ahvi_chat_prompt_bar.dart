import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/wardrobe.dart';
import 'package:myapp/widgets/ahvi_lens_sheet.dart';

class AhviChatPromptBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool? hasText;
  final ValueListenable<TextEditingValue>? hasTextListenable;
  final Color surface;
  final Color border;
  final Color accent;
  final Color accentSecondary;
  final Color textHeading;
  final Color textMuted;
  final Color shadowMedium;
  final Color onAccent;
  final EdgeInsetsGeometry padding;

  /// Called with the trimmed message text after send is confirmed.
  /// Parent should navigate to chat page inside this callback.
  final ValueChanged<String> onSendMessage;

  // ── Lens sheet (plus button తో trigger అవుతుంది) ──────────────────────
  final AppThemeTokens themeTokens;
  final VoidCallback? onVisualSearch;
  final VoidCallback? onFindSimilar;
  final VoidCallback? onAddToWardrobe;

  // ── Plus button override (optional — if null, lens sheet opens by default) ──
  final VoidCallback? onPlusTap;

  // ── Voice ─────────────────────────────────────────────────────────────
  final VoidCallback? onVoiceTap;
  final bool isListening;

  const AhviChatPromptBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.hasText,
    this.hasTextListenable,
    required this.surface,
    required this.border,
    required this.accent,
    required this.accentSecondary,
    required this.textHeading,
    required this.textMuted,
    required this.shadowMedium,
    required this.onAccent,
    required this.onSendMessage,
    required this.themeTokens,
    this.onVisualSearch,
    this.onFindSimilar,
    this.onAddToWardrobe,
    this.onPlusTap,
    this.onVoiceTap,
    this.isListening = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  State<AhviChatPromptBar> createState() => _AhviChatPromptBarState();
}

class _AhviChatPromptBarState extends State<AhviChatPromptBar> {
  LinearGradient get _accentGradient2 => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [widget.accent, widget.accentSecondary],
      );

  void _openLensSheet(BuildContext context) {
    final capturedContext = context;
    debugPrint('🔍 [LensSheet] opening, capturedContext mounted: ${capturedContext.mounted}');
    showAhviLensSheet(
      context,
      t: widget.themeTokens,
      onVisualSearch: widget.onVisualSearch,
      onFindSimilar: widget.onFindSimilar,
      onAddToWardrobe: widget.onAddToWardrobe ?? () {
        debugPrint('👗 [LensSheet] onAddToWardrobe tapped, context mounted: ${capturedContext.mounted}');
        showAddToWardrobeModal(capturedContext);
      },
    );
  }

  void _trySend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.controller.clear();
    widget.onSendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: widget.padding,
        child: Container(
          decoration: BoxDecoration(
            color: widget.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: widget.shadowMedium,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 260;
              return Row(
                children: [
                  // ── Plus button ───────────────────────────────────
                  if (!compact) ...[
                    Builder(
                      builder: (btnCtx) => _ChatPromptPressable(
                        scalePressed: 0.88,
                        onTap: () {
                          if (widget.onPlusTap != null) {
                            widget.onPlusTap!();
                          } else {
                            _openLensSheet(btnCtx);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.accent.withValues(alpha: 0.18),
                                widget.accentSecondary.withValues(alpha: 0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.add_rounded,
                              color: widget.accent, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // ── Text field ────────────────────────────────────
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      style: TextStyle(
                        color: widget.textHeading,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: widget.textMuted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      cursorColor: widget.accent,
                      cursorWidth: 1.5,
                      cursorRadius: const Radius.circular(1),
                      onSubmitted: (_) => _trySend(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── Voice button ──────────────────────────────────
                  _ChatPromptPressable(
                    scalePressed: 0.90,
                    onTap: widget.onVoiceTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: widget.isListening
                            ? const LinearGradient(
                                colors: [
                                  Colors.redAccent,
                                  Color(0xFFB71C1C)
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  widget.accent.withValues(alpha: 0.18),
                                  widget.accentSecondary
                                      .withValues(alpha: 0.18),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: widget.isListening
                            ? [
                                BoxShadow(
                                  color: Colors.redAccent
                                      .withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: widget.isListening
                          ? const _PulsingMicIcon()
                          : Icon(
                              Icons.mic_none_rounded,
                              color: widget.accent,
                              size: 18,
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── Send button ───────────────────────────────────
                  _ChatPromptPressable(
                    liftY: -1.5,
                    scalePressed: 0.90,
                    onTap: _trySend,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable:
                          widget.hasTextListenable ?? widget.controller,
                      builder: (context, value, _) {
                        final effectiveHasText =
                            widget.hasText ?? value.text.trim().isNotEmpty;
                        final iconColor =
                            widget.accent.computeLuminance() > 0.4
                                ? const Color(0xFF1A1A2E)
                                : Colors.white;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: effectiveHasText
                                ? _accentGradient2
                                : LinearGradient(
                                    colors: [
                                      widget.accent.withValues(alpha: 0.35),
                                      widget.accentSecondary
                                          .withValues(alpha: 0.35),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: effectiveHasText
                                ? [
                                    BoxShadow(
                                      color:
                                          widget.accent.withValues(alpha: 0.45),
                                      blurRadius: 22,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: widget.accentSecondary
                                          .withValues(alpha: 0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: iconColor,
                            size: 16,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}

// ── Pressable wrapper ──────────────────────────────────────────────────────
class _ChatPromptPressable extends StatefulWidget {
  final Widget? child;
  final Widget Function(bool isHovered, bool isPressed)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final double liftY;
  final double scaleHover;
  final double scalePressed;

  const _ChatPromptPressable({
    this.child,
    this.builder,
    this.onTap,
    this.onTapDown,
    this.liftY = 0.0,
    this.scaleHover = 1.0,
    this.scalePressed = 0.97,
  }) : assert(child != null || builder != null);

  @override
  State<_ChatPromptPressable> createState() => _ChatPromptPressableState();
}

class _ChatPromptPressableState extends State<_ChatPromptPressable> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    double dy = 0.0;
    if (_isPressed) {
      scale = widget.scalePressed;
    } else if (_isHovered) {
      scale = widget.scaleHover;
      dy = -widget.liftY;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) {
          widget.onTapDown?.call();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: _isPressed
              ? const Duration(milliseconds: 80)
              : const Duration(milliseconds: 340),
          curve: _isPressed
              ? const Cubic(0.4, 0.0, 1.0, 1.0)
              : const Cubic(0.34, 1.40, 0.64, 1.0),
          transform:
              Matrix4.translationValues(0.0, _isPressed ? 0.0 : dy, 0.0)
                ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
          transformAlignment: Alignment.center,
          child: widget.builder != null
              ? widget.builder!(_isHovered, _isPressed)
              : widget.child!,
        ),
      ),
    );
  }
}

// ── Pulsing mic icon when listening ───────────────────────────────────────
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
    );
  }
}

// ── Usage example (parent widget లో ఇలా వాడండి) ──────────────────────────
//
// AhviChatPromptBar(
//   controller: _controller,
//   focusNode: _focusNode,
//   hintText: 'Search or ask anything...',
//   onSendMessage: (message) {
//     // 1. Chat page కి navigate చేయండి
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ChatPage(initialMessage: message),
//       ),
//     );
//   },
//   // ... other required params
// )