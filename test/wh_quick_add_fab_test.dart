import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/widgets/wh_quick_add_fab.dart';

void main() {
  group('WHQuickAddFAB Hit-testing Tests', () {
    testWidgets('Tapping outside when closed reaches underlying widgets', (tester) async {
      bool backgroundTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Background tappable area right above bottom right
                Positioned(
                  bottom: 84,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => backgroundTapped = true,
                    child: const SizedBox(
                      width: 150,
                      height: 50,
                      child: Text('Underlying Card'),
                    ),
                  ),
                ),
                const WHQuickAddFAB(),
              ],
            ),
          ),
        ),
      );

      // Verify FAB is present
      expect(find.byType(WHQuickAddFAB), findsOneWidget);

      // Tap on the area at bottom 84, right 16 (where invisible actions used to live)
      await tester.tap(find.text('Underlying Card'));
      await tester.pump();

      // Background widget should receive the tap cleanly!
      expect(backgroundTapped, isTrue);
    });
  });
}
