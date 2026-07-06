/// Model for the AHVI "visual_board" backend response contract.
///
/// Backend returns this shape for Diet / Pack / Plan prompts:
/// {
///   "response_type": "visual_board",
///   "board_type": "diet_plan" | "packing_checklist" | "trip_prep",
///   "title": "...", "subtitle": "...",
///   "principles": [{"label": "", "value": ""}],
///   "sections": [{"title": "", "layout": "", "items": [...], "turn_into": []}],
///   "why_this_plan": "..."
/// }
library;

String _str(dynamic value) => (value ?? '').toString().trim();

List<String> _strList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) {
    if (e is Map) {
      return _str(e['label'] ?? e['name'] ?? e['title'] ?? e['text']);
    }
    return _str(e);
  })
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

class AhviBoardPrinciple {
  final String label;
  final String value;

  const AhviBoardPrinciple({required this.label, required this.value});

  factory AhviBoardPrinciple.fromJson(dynamic raw) {
    if (raw is Map) {
      return AhviBoardPrinciple(
        label: _str(raw['label'] ?? raw['title'] ?? raw['name']),
        value: _str(raw['value'] ?? raw['detail'] ?? raw['text']),
      );
    }
    return AhviBoardPrinciple(label: _str(raw), value: '');
  }

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

/// One row inside a section. Fields are layout-dependent; unused ones stay empty.
class AhviBoardItem {
  /// meal_options / simple_combinations
  final String name;
  final String pairing;

  /// checklist / timeline_checklist
  final String label;

  /// batch_prep
  final String category;
  final List<String> options;

  /// visual checklist thumbnails
  final String imageUrl;
  final String iconName;
  final String source;
  final bool checked;

  const AhviBoardItem({
    this.name = '',
    this.pairing = '',
    this.label = '',
    this.category = '',
    this.options = const [],
    this.imageUrl = '',
    this.iconName = '',
    this.source = '',
    this.checked = false,
  });

  factory AhviBoardItem.fromJson(dynamic raw) {
    if (raw is Map) {
      return AhviBoardItem(
        name: _str(raw['name']),
        pairing: _str(raw['pairing'] ?? raw['with']),
        label: _str(raw['label'] ?? raw['text'] ?? raw['title']),
        category: _str(raw['category']),
        options: _strList(raw['options']),
        imageUrl: _str(raw['imageUrl'] ?? raw['image_url']),
        iconName: _str(
          raw['iconName'] ??
              raw['icon_name'] ??
              raw['assetIcon'] ??
              raw['asset_icon'],
        ),
        source: _str(raw['source']),
        checked: raw['checked'] == true,
      );
    }
    return AhviBoardItem(label: _str(raw));
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'pairing': pairing,
    'label': label,
    'category': category,
    'options': options,
    'image_url': imageUrl,
    'icon_name': iconName,
    'source': source,
    'checked': checked,
  };

  /// Best single-line text for this item, used for plain-text fallbacks.
  String get displayText {
    if (label.isNotEmpty) return label;
    if (name.isNotEmpty) {
      return pairing.isNotEmpty ? '$name — $pairing' : name;
    }
    if (category.isNotEmpty) {
      return options.isNotEmpty ? '$category: ${options.join(', ')}' : category;
    }
    return '';
  }
}

class AhviBoardSection {
  final String title;

  /// meal_options | batch_prep | simple_combinations | checklist | timeline_checklist
  final String layout;
  final List<AhviBoardItem> items;
  final List<String> turnInto;

  const AhviBoardSection({
    required this.title,
    required this.layout,
    required this.items,
    this.turnInto = const [],
  });

  factory AhviBoardSection.fromJson(dynamic raw) {
    if (raw is! Map) {
      return AhviBoardSection(
        title: _str(raw),
        layout: 'checklist',
        items: const [],
      );
    }
    final rawItems = raw['items'];
    return AhviBoardSection(
      title: _str(raw['title'] ?? raw['name']),
      layout: _str(raw['layout']).isEmpty ? 'checklist' : _str(raw['layout']),
      items: rawItems is List
          ? rawItems
          .map(AhviBoardItem.fromJson)
          .where((i) => i.displayText.isNotEmpty)
          .toList(growable: false)
          : const [],
      turnInto: _strList(raw['turn_into'] ?? raw['turnInto']),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'layout': layout,
    'items': items.map((i) => i.toJson()).toList(),
    'turn_into': turnInto,
  };
}

class AhviVisualBoard {
  final String boardType;
  final String title;
  final String subtitle;
  final List<AhviBoardPrinciple> principles;
  final List<AhviBoardSection> sections;
  final String whyThisPlan;

  const AhviVisualBoard({
    required this.boardType,
    required this.title,
    required this.subtitle,
    required this.principles,
    required this.sections,
    required this.whyThisPlan,
  });

  bool get isEmpty => title.isEmpty && sections.isEmpty;

  /// True when a backend response carries a visual board.
  static bool isVisualBoard(Map? response) {
    if (response == null) return false;
    if (_str(response['response_type']) == 'visual_board') return true;
    final vb = response['visual_board'];
    if (vb is Map && _str(vb['response_type']) == 'visual_board') return true;
    final data = response['data'];
    if (data is Map && data['visual_board'] is Map) return true;
    return false;
  }

  /// Accepts the full backend envelope OR a bare visual_board map.
  factory AhviVisualBoard.fromJson(Map<String, dynamic> json) {
    Map src = json;
    if (json['sections'] is! List) {
      final vb = json['visual_board'];
      if (vb is Map) {
        src = vb;
      } else {
        final data = json['data'];
        if (data is Map && data['visual_board'] is Map) {
          src = data['visual_board'] as Map;
        }
      }
    }

    final principles = src['principles'];
    final sections = src['sections'];
    return AhviVisualBoard(
      boardType: _str(src['board_type']),
      title: _str(src['title']),
      subtitle: _str(src['subtitle']),
      principles: principles is List
          ? principles
          .map(AhviBoardPrinciple.fromJson)
          .where((p) => p.label.isNotEmpty)
          .toList(growable: false)
          : const [],
      sections: sections is List
          ? sections
          .map(AhviBoardSection.fromJson)
          .where((s) => s.title.isNotEmpty || s.items.isNotEmpty)
          .toList(growable: false)
          : const [],
      whyThisPlan: _str(src['why_this_plan'] ?? src['whyThisPlan']),
    );
  }

  /// Round-trips with [AhviVisualBoard.fromJson] — same key shape as the
  /// backend envelope, so this can be saved and later reloaded from storage.
  Map<String, dynamic> toJson() => {
    'board_type': boardType,
    'title': title,
    'subtitle': subtitle,
    'principles': principles.map((p) => p.toJson()).toList(),
    'sections': sections.map((s) => s.toJson()).toList(),
    'why_this_plan': whyThisPlan,
  };
}
