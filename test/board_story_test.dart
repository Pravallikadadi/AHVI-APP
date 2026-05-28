import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/style_board/board_models.dart';

void main() {
  group('BoardStory.fromJson', () {
    test('returns empty story when JSON is null', () {
      final story = BoardStory.fromJson(null);
      expect(story.isEmpty, true);
      expect(story.hasExpandableContent, false);
    });

    test('parses every documented field', () {
      final story = BoardStory.fromJson(<String, dynamic>{
        'headline': 'Minimal Executive',
        'summary': 'Sharp, composed, and client-ready.',
        'why': 'The structured layer gives presence while the darker base keeps it grounded.',
        'personal_note': 'This stays close to your cleaner minimal choices.',
        'occasion_fit': 'Strong for client-facing settings because nothing reads too casual.',
        'tip': 'Keep accessories restrained — one strong finisher is enough.',
        'role': 'Safest polished option',
      });

      expect(story.headline, 'Minimal Executive');
      expect(story.summary, 'Sharp, composed, and client-ready.');
      expect(story.why, isNotNull);
      expect(story.personalNote, isNotNull);
      expect(story.occasionFit, isNotNull);
      expect(story.tip, isNotNull);
      expect(story.role, 'Safest polished option');
      expect(story.isEmpty, false);
      expect(story.hasExpandableContent, true);
    });

    test('treats empty strings as null', () {
      final story = BoardStory.fromJson(<String, dynamic>{
        'headline': '',
        'summary': '   ',
        'why': 'real reason',
      });
      expect(story.headline, isNull);
      expect(story.summary, isNull);
      expect(story.why, 'real reason');
    });
  });

  group('StyleBoardData fallback getters', () {
    test('story summary wins over whyItWorks and occasion', () {
      final data = StyleBoardData(
        title: 't',
        occasion: 'office',
        whyItWorks: 'legacy reason',
        items: const [],
        story: BoardStory.fromJson(<String, dynamic>{
          'summary': 'story summary',
          'why': 'story why',
          'tip': 'story tip',
          'role': 'Safest polished option',
        }),
      );
      expect(data.summaryText, 'story summary');
      expect(data.whyText, 'story why');
      expect(data.tipText, 'story tip');
      expect(data.roleLabel, 'Safest polished option');
    });

    test('falls back to legacy fields when story is absent', () {
      const data = StyleBoardData(
        title: 't',
        occasion: 'date_night',
        whyItWorks: 'legacy why',
        stylingTip: 'legacy tip',
        items: [],
      );
      expect(data.summaryText, 'legacy why');
      expect(data.whyText, 'legacy why');
      expect(data.tipText, 'legacy tip');
      expect(data.roleLabel, 'date_night');
    });
  });
}
