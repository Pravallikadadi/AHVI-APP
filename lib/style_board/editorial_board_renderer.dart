import 'package:flutter/material.dart';

import 'board_models.dart';
import 'editorial_board_layout_engine.dart';
import 'editorial_board_widgets.dart';

/// Inner canvas only: no save/share bar, no item boxes.
/// Put this inside the existing AHVI board card body.
class EditorialBoardCanvas extends StatelessWidget {
  final StyleBoardData board;

  const EditorialBoardCanvas({super.key, required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final layout = EditorialBoardLayoutEngine.resolve(
            board,
            width: w,
            height: h,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              const _EditorialBackgroundDecor(),
              ...layout.placements.map((p) {
                return Positioned(
                  left: p.x,
                  top: p.y,
                  width: p.width,
                  height: p.height,
                  child: EditorialBoardItem(item: p.item, rotation: p.rotation),
                );
              }),
              Positioned(
                left: w * 0.03,
                bottom: h * 0.035,
                width: w * 0.42,
                child: const Text(
                  'Refined.\nRelaxed.',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.05,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A6A78),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditorialBackgroundDecor extends StatelessWidget {
  const _EditorialBackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _EditorialBackgroundPainter()),
      ),
    );
  }
}

class _EditorialBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final softPink = Paint()
      ..color = const Color(0xFFFFE8EE).withValues(alpha: 0.62);
    final softLilac = Paint()
      ..color = const Color(0xFFEFE5FA).withValues(alpha: 0.72);
    final softCream = Paint()
      ..color = const Color(0xFFFFF3D9).withValues(alpha: 0.58);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.28, size.height * 0.30),
        width: size.width * 0.52,
        height: size.height * 0.38,
      ),
      softPink,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.72, size.height * 0.45),
        width: size.width * 0.46,
        height: size.height * 0.50,
      ),
      softLilac,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.36, size.height * 0.82),
        width: size.width * 0.58,
        height: size.height * 0.30,
      ),
      softCream,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
