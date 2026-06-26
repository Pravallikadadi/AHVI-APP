import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'board_models.dart';

class EditorialBoardItem extends StatelessWidget {
  final StyleBoardItem item;
  final double rotation;

  const EditorialBoardItem({super.key, required this.item, this.rotation = 0});

  @override
  Widget build(BuildContext context) {
    final garment = Image.network(
      item.imageUrl,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 22,
          color: Colors.black26,
        ),
      ),
    );
    return Transform.rotate(
      angle: rotation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft drop-shadow so a light/white cutout (white trousers, white
          // sneakers, off-white shirt) stays visible on the off-white board
          // canvas. The bare Image had zero separation and vanished into the
          // background, making the board look empty.
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 4),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  color: Colors.black.withValues(alpha: 0.22),
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          garment,
        ],
      ),
    );
  }
}
