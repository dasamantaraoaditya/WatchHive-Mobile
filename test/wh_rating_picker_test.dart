import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/widgets/wh_rating_picker.dart';

void main() {
  group('WHRatingPicker Tests', () {
    test('getMoodInfo returns accurate sentiment and color', () {
      expect(WHRatingPicker.getMoodInfo(0.0).text, contains('Tap or drag stars'));
      expect(WHRatingPicker.getMoodInfo(2.0).text, contains('Disaster'));
      expect(WHRatingPicker.getMoodInfo(4.0).text, contains('Poor'));
      expect(WHRatingPicker.getMoodInfo(5.0).text, contains('Mediocre'));
      expect(WHRatingPicker.getMoodInfo(7.0).text, contains('Decent'));
      expect(WHRatingPicker.getMoodInfo(8.5).text, contains('Excellent'));
      expect(WHRatingPicker.getMoodInfo(9.5).text, contains('Outstanding'));
      expect(WHRatingPicker.getMoodInfo(10.0).text, contains('Masterpiece'));
    });

    testWidgets('renders score and reacts to preset chips', (tester) async {
      double currentRating = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return WHRatingPicker(
                  rating: currentRating,
                  onRatingChanged: (newVal) {
                    setState(() => currentRating = newVal);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('—.—'), findsOneWidget);
      expect(find.text('/ 10'), findsOneWidget);

      // Tap preset chip '8.5 Great'
      final greatPreset = find.text('🔥 Great');
      expect(greatPreset, findsOneWidget);
      await tester.tap(greatPreset);
      await tester.pumpAndSettle();

      expect(currentRating, 8.5);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('Excellent / Highly Recommended 🔥'), findsOneWidget);

      // Tap Increment (+0.5) button
      final addBtn = find.byTooltip('+0.5');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(currentRating, 9.0);
      expect(find.text('9.0'), findsOneWidget);
    });
  });
}
