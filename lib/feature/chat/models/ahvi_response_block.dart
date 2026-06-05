enum AhviBlockType {
  text,
  visualInspiration,
  visualDirections,
  styleBoards,
  visualBoard,
  moduleCards,
  wardrobeGap,
  missingPiece,
  checklist,
  plan,
  image,
  unknown,
}

class AhviResponseBlock {
  final AhviBlockType type;
  final Map<String, dynamic> data;

  const AhviResponseBlock({required this.type, required this.data});
}

class AhviParsedResponse {
  final String text;
  final List<dynamic> chips;
  final List<AhviResponseBlock> blocks;
  final String? boardId;
  final String? packId;

  const AhviParsedResponse({
    required this.text,
    required this.chips,
    required this.blocks,
    this.boardId,
    this.packId,
  });
}
