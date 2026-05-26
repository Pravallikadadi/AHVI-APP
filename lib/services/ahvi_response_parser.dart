class AhviChip {
  final String label;
  final String value;

  const AhviChip({required this.label, required this.value});

  factory AhviChip.fromDynamic(dynamic raw) {
    if (raw is Map) {
      final label =
          (raw['label'] ?? raw['title'] ?? raw['text'] ?? raw['name'] ?? '')
              .toString()
              .trim();
      final value = (raw['value'] ?? raw['id'] ?? raw['key'] ?? label)
          .toString()
          .trim();
      return AhviChip(label: label.isEmpty ? value : label, value: value);
    }
    final text = (raw ?? '').toString().trim();
    return AhviChip(label: text, value: text);
  }

  Map<String, String> toJson() => {'label': label, 'value': value};
}

class AhviSection {
  final String title;
  final List<String> items;

  const AhviSection({required this.title, required this.items});

  factory AhviSection.fromDynamic(dynamic raw) {
    if (raw is Map) {
      final title = (raw['title'] ?? raw['name'] ?? raw['label'] ?? 'Plan')
          .toString()
          .trim();
      final items = _stringList(
        raw['items'] ?? raw['steps'] ?? raw['tasks'] ?? raw['checklist'],
      );
      return AhviSection(title: title.isEmpty ? 'Plan' : title, items: items);
    }
    final text = (raw ?? '').toString().trim();
    return AhviSection(title: text.isEmpty ? 'Plan' : text, items: const []);
  }
}

class AhviResponse {
  final String messageText;
  final String type;
  final List<AhviChip> chips;
  final List<Map<String, dynamic>> cards;
  final Map<String, dynamic> data;
  final Map<String, dynamic> meta;
  final List<AhviSection> planSections;
  final List<AhviSection> prepSections;
  final List<String> checklistItems;

  const AhviResponse({
    required this.messageText,
    required this.type,
    required this.chips,
    required this.cards,
    required this.data,
    required this.meta,
    required this.planSections,
    required this.prepSections,
    required this.checklistItems,
  });

  factory AhviResponse.fromMap(Map<String, dynamic> response) {
    final data = _map(response['data']);
    final meta = _map(response['meta']);
    final type = (response['type'] ?? meta['mode'] ?? '').toString().trim();
    final plan = _map(data['plan']);
    final prep = _map(data['prep']);
    final checklist = _map(data['checklist']);

    final cards = _mapList(response['cards']);
    final planSections = _sections(plan['sections'] ?? data['plan_sections']);
    final prepSections = _sections(
      prep['sections'] ?? checklist['sections'] ?? data['prep_sections'],
    );
    final checklistItems = <String>[
      ..._stringList(checklist['items'] ?? prep['items']),
      ..._checklistItemsFromCards(cards),
    ];

    final rawChips = response['chips'] is List
        ? response['chips'] as List
        : const [];
    final rawQuickActions = response['quick_actions'] is List
        ? response['quick_actions'] as List
        : const [];
    final chipSource = rawQuickActions.isNotEmpty ? rawQuickActions : rawChips;

    return AhviResponse(
      messageText: _messageText(response),
      type: type,
      chips: chipSource
          .map(AhviChip.fromDynamic)
          .where((chip) => chip.label.isNotEmpty)
          .toList(growable: false),
      cards: cards,
      data: data,
      meta: meta,
      planSections: planSections,
      prepSections: prepSections,
      checklistItems: checklistItems,
    );
  }

  bool get isClarification => type == 'clarification';
  bool get isPlan => type == 'plan' || meta['mode'] == 'plan';
  bool get isPrep =>
      type == 'prep' || type == 'checklist' || meta['mode'] == 'prep';
}

String _messageText(Map<String, dynamic> response) {
  final raw = response['message'];
  final text =
      response['message_text'] ??
      (raw is Map ? raw['content'] : raw) ??
      response['response'] ??
      '';
  return text.toString().trim();
}

Map<String, dynamic> _map(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<AhviSection> _sections(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(AhviSection.fromDynamic)
      .where((section) => section.title.isNotEmpty || section.items.isNotEmpty)
      .toList(growable: false);
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        if (item is Map) {
          return (item['label'] ??
                  item['title'] ??
                  item['name'] ??
                  item['text'] ??
                  '')
              .toString()
              .trim();
        }
        return (item ?? '').toString().trim();
      })
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _checklistItemsFromCards(List<Map<String, dynamic>> cards) {
  final items = <String>[];
  for (final card in cards) {
    final kind = (card['kind'] ?? card['type'] ?? '').toString().toLowerCase();
    final hasChecklistShape =
        kind.contains('checklist') ||
        card.containsKey('checklist') ||
        card.containsKey('steps');
    if (!hasChecklistShape) continue;
    final title = (card['title'] ?? card['label'] ?? '').toString().trim();
    if (title.isNotEmpty) items.add(title);
    items.addAll(
      _stringList(card['items'] ?? card['steps'] ?? card['checklist']),
    );
  }
  return items.toSet().take(12).toList(growable: false);
}
