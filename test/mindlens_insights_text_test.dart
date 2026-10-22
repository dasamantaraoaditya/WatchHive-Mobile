import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/mindlens/screens/mindlens_screen.dart';

void main() {
  group('MindLensScreen.formatInsightText tests', () {
    testWidgets('properly renders bold viewing pattern in insight text', (tester) async {
      const insight = 'Your overall viewing pattern leans strongly toward **Escapism**.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindLensScreen.formatInsightText(insight),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children?.cast<TextSpan>() ?? [];

      expect(spans.length, equals(3));
      expect(spans[0].text, equals('Your overall viewing pattern leans strongly toward '));
      expect(spans[0].style?.fontWeight, equals(FontWeight.w500));

      // The viewing pattern should be present, bold, and have textPrimary color
      expect(spans[1].text, equals('Escapism'));
      expect(spans[1].style?.fontWeight, equals(FontWeight.w900));

      expect(spans[2].text, equals('.'));
      expect(spans[2].style?.fontWeight, equals(FontWeight.w500));
    });

    testWidgets('properly renders bold @username at start of insight text', (tester) async {
      const insight = '**@aditya** is your #1 Cinematic Influencer on WatchHive!';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindLensScreen.formatInsightText(insight),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children?.cast<TextSpan>() ?? [];

      expect(spans.length, equals(2));
      // First span must be the bold @username
      expect(spans[0].text, equals('@aditya'));
      expect(spans[0].style?.fontWeight, equals(FontWeight.w900));

      expect(spans[1].text, equals(' is your #1 Cinematic Influencer on WatchHive!'));
      expect(spans[1].style?.fontWeight, equals(FontWeight.w500));
    });

    testWidgets('properly renders multiple bold tokens in insight text', (tester) async {
      const insight = 'You love **Sci-Fi** and **Thriller** equally.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindLensScreen.formatInsightText(insight),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children?.cast<TextSpan>() ?? [];

      expect(spans.length, equals(5));
      expect(spans[0].text, equals('You love '));
      expect(spans[1].text, equals('Sci-Fi'));
      expect(spans[1].style?.fontWeight, equals(FontWeight.w900));
      expect(spans[2].text, equals(' and '));
      expect(spans[3].text, equals('Thriller'));
      expect(spans[3].style?.fontWeight, equals(FontWeight.w900));
      expect(spans[4].text, equals(' equally.'));
    });

    testWidgets('renders plain text when no bold markdown tokens are present', (tester) async {
      const insight = 'High late-night viewing detected. You tend to reclaim personal reflection time during late hours.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindLensScreen.formatInsightText(insight),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children?.cast<TextSpan>() ?? [];

      expect(spans.length, equals(1));
      expect(spans[0].text, equals(insight));
      expect(spans[0].style?.fontWeight, equals(FontWeight.w500));
    });
  });
}
