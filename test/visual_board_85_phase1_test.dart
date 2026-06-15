import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/feature/chat/widgets/blocks/visual_directions/visual_direction_carousel.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

final _direction = <String, dynamic>{
  'direction_name': 'Sunlit Traditional',
  'occasion': 'Haldi',
  'adjectives': ['Festive', 'Relaxed', 'Bright'],
  'hero_piece': 'Marigold Yellow Cotton Kurta',
  'image_url': null,
  'items': ['Marigold Yellow Cotton Kurta', 'Cream Churidar Trousers'],
  'complete_the_look': [
    {
      'asset_id': 'bottom-1',
      'name': 'Cream Churidar Trousers',
      'category': 'bottom',
    },
    {
      'asset_id': 'shoe-1',
      'name': 'Embroidered Mojaris',
      'category': 'footwear',
    },
    {'asset_id': 'bag-1', 'name': 'Ivory Potli Bag', 'category': 'bag'},
    {'asset_id': 'watch-1', 'name': 'Festive Gold Watch', 'category': 'watch'},
  ],
  'short_note':
      'This deliberately long explanation must not appear on the Phase 1 card.',
  'styling_tip':
      'This deliberately long styling tip must not appear on the Phase 1 card.',
  'badge': {'occasion_fit': 'Inspiring', 'wardrobe_match_pct': 88},
  'owned_items': [
    {'name': 'Existing Cream Trousers', 'category': 'bottom'},
  ],
  'missing_piece': {
    'name': 'Ethnic Footwear',
    'category': 'footwear',
    'reason': 'Completes the festive look.',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Phase 1 keeps the board and removes report-style content', (
    tester,
  ) async {
    await _pumpBoard(tester, use85Layout: true, width: 320);

    expect(find.text('Sunlit Traditional'), findsOneWidget);
    expect(find.text('Legacy Editorial Cover'), findsNothing);
    expect(find.text('Haldi'), findsOneWidget);
    expect(find.text('Festive'), findsOneWidget);
    expect(find.text('Relaxed'), findsNothing);
    expect(find.text('Marigold Yellow Cotton Kurta'), findsOneWidget);
    expect(find.text('Embroidered Mojaris'), findsOneWidget);

    expect(find.text('Recommended'), findsNothing);
    expect(find.textContaining('Occasion Fit'), findsNothing);
    expect(find.textContaining('Wardrobe Match'), findsNothing);
    expect(
      find.textContaining('This deliberately long explanation'),
      findsNothing,
    );
    expect(
      find.textContaining('This deliberately long styling tip'),
      findsNothing,
    );
    expect(find.text('Existing Cream Trousers'), findsNothing);
    expect(find.text('Missing: Ethnic Footwear'), findsNothing);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Style This'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shuffle reuses the existing backend action', (tester) async {
    final sent = <String>[];
    await _pumpBoard(tester, use85Layout: true, onSendMessage: sent.add);

    await tester.tap(find.text('Shuffle'));
    await tester.pump();

    expect(sent, ['Show more looks like Sunlit Traditional']);
  });

  testWidgets('Style This and Missing retain chat actions', (tester) async {
    final sent = <String>[];
    await _pumpBoard(tester, use85Layout: true, onSendMessage: sent.add);

    await tester.tap(find.text('Style This'));
    await tester.tap(find.text('Missing'));
    await tester.pump();

    expect(sent, [
      'Use my wardrobe for: Sunlit Traditional',
      'Show shopping ideas for: Ethnic Footwear',
    ]);
  });

  testWidgets('Phase 1 card has no overflow on a small phone width', (
    tester,
  ) async {
    final longName = Map<String, dynamic>.from(_direction)
      ..['direction_name'] =
          'A Very Long Festive Direction Name That Must Never Resize The Card'
      ..['hero_piece'] =
          'Marigold Yellow Hand Embroidered Cotton Silk Celebration Kurta';

    await _pumpBoard(
      tester,
      use85Layout: true,
      width: 286,
      direction: longName,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('golden: legacy visual direction card', (tester) async {
    await _pumpGolden(tester, use85Layout: false);
    await expectLater(
      find.byKey(const ValueKey('visual-board-golden')),
      matchesGoldenFile('goldens/visual_board_phase1_before.png'),
    );
  });

  testWidgets('golden: Phase 1 board-first card', (tester) async {
    await _pumpGolden(tester, use85Layout: true);
    await expectLater(
      find.byKey(const ValueKey('visual-board-golden')),
      matchesGoldenFile('goldens/visual_board_phase1_after.png'),
    );
  });
}

Future<void> _pumpBoard(
  WidgetTester tester, {
  required bool use85Layout,
  double width = 320,
  Map<String, dynamic>? direction,
  ValueChanged<String>? onSendMessage,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _testApp(
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: VisualDirectionCarousel(
            directions: [direction ?? _direction],
            cardWidth: width,
            curationReveal: false,
            use85Layout: use85Layout,
            onSendMessage: onSendMessage ?? (_) {},
            editorialCover: const {
              'direction_name': 'Legacy Editorial Cover',
              'occasion_label': 'Haldi',
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpGolden(
  WidgetTester tester, {
  required bool use85Layout,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _testApp(
      child: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('visual-board-golden'),
          child: ColoredBox(
            color: const Color(0xFFF8F6FA),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: VisualDirectionCarousel(
                directions: [_direction],
                cardWidth: 390,
                curationReveal: false,
                use85Layout: use85Layout,
                onSendMessage: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _testApp({required Widget child}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      extensions: [AppThemeTokens.light(_accent)],
    ),
    home: child,
  );
}
