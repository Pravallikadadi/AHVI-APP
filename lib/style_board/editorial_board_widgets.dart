import 'package:flutter/material.dart';

import 'board_models.dart';

class EditorialBoardItem extends StatelessWidget {
  final StyleBoardItem item;
  final double rotation;

  const EditorialBoardItem({
    super.key,
    required this.item,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Image.network(
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
      ),
    );
  }
}
