import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myapp/theme/theme_tokens.dart';

/// One-shot premium loader that gates a visual-directions block reveal.
///
/// Shows "Curating Your Looks" with a staggered checklist (Venue, Occasion,
/// Wardrobe, Personal Style) for ~1.6s, then animates the [child] into view.
/// Subsequent rebuilds (e.g. theme changes, scroll) re-display the child
/// directly — the reveal animation only fires the first time this widget
/// is built for a given response.
class CurationReveal extends StatefulWidget {
  final String occasionLabel;
  final String venueLabel;
  final Widget child;
  final Duration duration;
  final bool enabled;

  const CurationReveal({
    super.key,
    required this.child,
    this.occasionLabel = '',
    this.venueLabel = '',
    this.duration = const Duration(milliseconds: 1700),
    this.enabled = true,
  });

  @override
  State<CurationReveal> createState() => _CurationRevealState();
}

class _CurationRevealState extends State<CurationReveal>
    with SingleTickerProviderStateMixin {
  late final List<bool> _ticks = [false, false, false, false];
  bool _revealed = false;
  Timer? _revealTimer;
  final List<Timer> _tickTimers = [];

  static const _labels = <String>[
    'Venue',
    'Occasion',
    'Wardrobe',
    'Personal Style',
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _revealed = true;
      return;
    }
    final ms = widget.duration.inMilliseconds;
    // Stagger ticks across ~80% of the loader window so the final tick
    // lands just before the reveal.
    for (var i = 0; i < _ticks.length; i++) {
      final delay = ((ms * 0.18) + (i * ms * 0.18)).round();
      _tickTimers.add(
        Timer(Duration(milliseconds: delay), () {
          if (!mounted) return;
          setState(() => _ticks[i] = true);
        }),
      );
    }
    _revealTimer = Timer(widget.duration, () {
      if (!mounted) return;
      setState(() => _revealed = true);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    for (final timer in _tickTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: _revealed
          ? KeyedSubtree(key: const ValueKey('revealed'), child: widget.child)
          : _LoaderCard(
              key: const ValueKey('loader'),
              occasionLabel: widget.occasionLabel,
              venueLabel: widget.venueLabel,
              ticks: _ticks,
              labels: _labels,
            ),
    );
  }
}

class _LoaderCard extends StatelessWidget {
  final String occasionLabel;
  final String venueLabel;
  final List<bool> ticks;
  final List<String> labels;

  const _LoaderCard({
    super.key,
    required this.occasionLabel,
    required this.venueLabel,
    required this.ticks,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 18, color: t.accent.primary),
              const SizedBox(width: 8),
              Text(
                'CURATING YOUR LOOKS',
                style: TextStyle(
                  color: t.mutedText,
                  fontSize: 11.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (occasionLabel.isNotEmpty)
            Text(
              occasionLabel,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          if (venueLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              venueLabel,
              style: TextStyle(
                color: t.mutedText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'ANALYZING',
            style: TextStyle(
              color: t.mutedText,
              fontSize: 9.5,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < labels.length; i++) ...[
            _CheckRow(label: labels[i], on: ticks[i], tokens: t),
            if (i != labels.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool on;
  final dynamic tokens;

  const _CheckRow({required this.label, required this.on, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      style: TextStyle(
        color: on ? t.textPrimary : t.mutedText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: on
                ? Icon(Icons.check_circle_rounded,
                    key: const ValueKey('on'),
                    size: 17,
                    color: t.accent.primary)
                : Icon(Icons.radio_button_unchecked_rounded,
                    key: const ValueKey('off'),
                    size: 17,
                    color: t.mutedText.withValues(alpha: 0.45)),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
