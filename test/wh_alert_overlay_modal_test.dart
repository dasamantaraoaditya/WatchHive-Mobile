import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/router/app_router.dart';
import 'package:watchhive_mobile/shared/widgets/wh_alert.dart';

void main() {
  testWidgets('WHAlert toast and confirm dialog display in front of open modal bottom sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (sheetContext) => Container(
                      height: 400,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text('Modal Bottom Sheet Content'),
                          ElevatedButton(
                            onPressed: () {
                              WHAlert.showWarning(sheetContext, 'Start time cannot be in the future.');
                            },
                            child: const Text('Trigger Warning from Sheet'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await WHAlert.confirm(
                                sheetContext,
                                title: 'Discard Changes?',
                                message: 'Are you sure you want to discard your edits?',
                                confirmText: 'Discard',
                                cancelText: 'Keep Editing',
                                severity: WHAlertSeverity.danger,
                              );
                            },
                            child: const Text('Trigger Confirm from Sheet'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Modal Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Open the modal bottom sheet
    await tester.tap(find.text('Open Modal Sheet'));
    await tester.pumpAndSettle();

    // Verify modal bottom sheet is currently open
    expect(find.text('Modal Bottom Sheet Content'), findsOneWidget);

    // 2. Trigger floating warning toast from inside the sheet
    await tester.tap(find.text('Trigger Warning from Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // Animation

    // Toast must be rendered and visible even while modal sheet is open!
    expect(find.text('Start time cannot be in the future.'), findsOneWidget);

    // Tap close icon on the toast to dismiss it
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start time cannot be in the future.'), findsNothing);

    // 3. Trigger WHAlert.confirm dialog from inside the sheet
    await tester.tap(find.text('Trigger Confirm from Sheet'));
    await tester.pumpAndSettle();

    // Confirm dialog must be rendered on the root navigator in front of the sheet
    expect(find.text('Discard Changes?'), findsOneWidget);
    expect(find.text('Are you sure you want to discard your edits?'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Keep Editing'), findsOneWidget);

    // Tap Cancel / Keep Editing to dismiss the confirm dialog
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();

    // Confirm dialog is gone, bottom sheet is still intact
    expect(find.text('Discard Changes?'), findsNothing);
    expect(find.text('Modal Bottom Sheet Content'), findsOneWidget);
  });
}
