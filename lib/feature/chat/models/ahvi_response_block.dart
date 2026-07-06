enum AhviBlockType {
  text,
  styleAdvice,
  transitionPlan,
  stylistReasoning,
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

  Map<String, dynamic> toJson() => {'type': type.name, 'data': data};

  factory AhviResponseBlock.fromJson(Map<String, dynamic> json) {
    return AhviResponseBlock(
      type: AhviBlockType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => AhviBlockType.unknown,
      ),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
    );
  }
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
