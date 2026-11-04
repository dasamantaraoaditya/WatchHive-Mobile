import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/widgets/wh_alert.dart';
import 'package:watchhive_mobile/core/router/app_router.dart';

void main() {
  testWidgets('WHAlert.showSuccessWithAction renders message, Share action, and close icon', (tester) async {
    bool shareTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  WHAlert.showSuccessWithAction(
                    context,
                    message: 'Added "Oppenheimer" to Currently Watching.',
                    actionLabel: 'Share',
                    actionIcon: Icons.share_rounded,
                    onAction: () {
                      shareTapped = true;
                    },
                  );
                },
                child: const Text('Trigger Toast'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap button to trigger the alert
    await tester.tap(find.text('Trigger Toast'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish animation

    // Verify message is visible
    expect(find.text('Added "Oppenheimer" to Currently Watching.'), findsOneWidget);

    // Verify Share action button and icon are visible
    expect(find.text('Share'), findsOneWidget);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);

    // Verify close icon (✕) is visible
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tap Share and verify callback is called
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(shareTapped, isTrue);

    // Close button tap dismisses the snackbar
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
