import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/widgets/danger_zone_card.dart';

void main() {
  group('DangerZoneCard & Account Deletion Safety UX Tests', () {
    testWidgets('renders Danger Zone card with irreversible warning and backup guidance', (tester) async {
      bool exportTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneCard(
                  onExportRequested: () {
                    exportTriggered = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Verify header and irreversible badge
      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.text('IRREVERSIBLE'), findsOneWidget);
      expect(
        find.textContaining('Deleting your account permanently erases your profile'),
        findsOneWidget,
      );

      // Verify backup advisory callout box
      expect(find.text('Important: Back up your Hive data first'), findsOneWidget);
      expect(
        find.textContaining('Your watch history, reviews, and ratings are deeply valuable'),
        findsOneWidget,
      );
      expect(find.text('Go to Data Management for Export'), findsOneWidget);

      // Tap on Export button in advisory callout
      await tester.tap(find.text('Go to Data Management for Export'));
      await tester.pump();
      expect(exportTriggered, isTrue);

      // Verify primary destructive action button
      expect(find.text('Delete Account Permanently'), findsOneWidget);
    });

    testWidgets('opens double-lock deletion safety sheet with consequences, safe exit, and typed confirmation', (tester) async {
      bool exportTriggered = false;

      // Set a larger test surface to accommodate bottom sheet content
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneCard(
                  onExportRequested: () {
                    exportTriggered = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Open the deletion bottom sheet
      await tester.tap(find.text('Delete Account Permanently'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title & safety consequences
      expect(find.text('Permanently Delete Account?'), findsOneWidget);
      expect(find.text('THIS ACTION CANNOT BE UNDONE'), findsOneWidget);
      expect(
        find.text('All movie logs, watched dates, ratings, and written reviews'),
        findsOneWidget,
      );
      expect(
        find.text('All custom watchlists, stacks, and ranked collections'),
        findsOneWidget,
      );

      // Verify safe exit / backup CTA inside sheet
      expect(find.text('Take your data with you first'), findsOneWidget);
      expect(
        find.text('Cancel & Export My Data First (Recommended)'),
        findsOneWidget,
      );

      // Verify double-lock: Acknowledgement checkbox and typed confirmation
      expect(
        find.textContaining('I understand that this action is permanent'),
        findsOneWidget,
      );
      expect(find.text('To confirm, please type "DELETE" below:'), findsOneWidget);

      // Verify the final destructive button starts disabled
      final deleteBtnFinder = find.widgetWithText(
        ElevatedButton,
        'Permanently Delete Account',
      );
      expect(deleteBtnFinder, findsOneWidget);
      final initialButton = tester.widget<ElevatedButton>(deleteBtnFinder);
      expect(initialButton.onPressed, isNull);

      // Check the acknowledgement checkbox
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pump();

      // Still disabled because "DELETE" has not been entered
      final buttonAfterCheckbox = tester.widget<ElevatedButton>(deleteBtnFinder);
      expect(buttonAfterCheckbox.onPressed, isNull);

      // Enter "DELETE" into the text field
      final textFieldFinder = find.byType(TextField);
      await tester.ensureVisible(textFieldFinder);
      await tester.enterText(textFieldFinder, 'DELETE');
      await tester.pump();

      // Now the button should be active and enabled!
      final enabledButton = tester.widget<ElevatedButton>(deleteBtnFinder);
      expect(enabledButton.onPressed, isNotNull);

      // Test the safe exit CTA
      final safeExitBtn = find.text('Cancel & Export My Data First (Recommended)');
      await tester.ensureVisible(safeExitBtn);
      await tester.tap(safeExitBtn);
      await tester.pumpAndSettle();

      expect(exportTriggered, isTrue);
      // Sheet should be dismissed
      expect(find.text('Permanently Delete Account?'), findsNothing);
    });
  });
}
