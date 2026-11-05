import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/widgets/danger_zone_card.dart';
import 'package:watchhive_mobile/features/profile/widgets/data_management_card.dart';
import 'package:watchhive_mobile/features/profile/widgets/offline_sync_card.dart';

void main() {
  group('Profile Screen Collapsible Cards Tests', () {
    testWidgets('DangerZoneCard is collapsed by default and expands on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DangerZoneCard(onExportRequested: () {}),
            ),
          ),
        ),
      );

      // Header should be visible
      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.text('IRREVERSIBLE'), findsOneWidget);

      // Collapsed: delete account button is not yet visible
      expect(find.text('Delete Account Permanently'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('Danger Zone'));
      await tester.pumpAndSettle();

      // Expanded: delete account button is now visible
      expect(find.text('Delete Account Permanently'), findsOneWidget);
      expect(find.text('Important: Back up your Hive data first'), findsOneWidget);

      // Tap header again to collapse
      await tester.tap(find.text('Danger Zone'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account Permanently'), findsNothing);
    });

    testWidgets('DataManagementCard is collapsed by default, expands on tap, and programmatically', (tester) async {
      final key = GlobalKey<DataManagementCardState>();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DataManagementCard(key: key),
              ),
            ),
          ),
        ),
      );

      // Header is visible
      expect(find.text('Data Management'), findsOneWidget);

      // Collapsed: export formats and checkboxes are hidden
      expect(find.text('DATA TYPES TO INCLUDE'), findsNothing);
      expect(find.text('Export Data'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('Data Management'));
      await tester.pumpAndSettle();

      expect(find.text('DATA TYPES TO INCLUDE'), findsOneWidget);
      expect(find.text('Export Data'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Data Management'));
      await tester.pumpAndSettle();

      expect(find.text('Export Data'), findsNothing);

      // Test programmatic expansion (e.g. from Danger Zone redirect)
      key.currentState?.expand();
      await tester.pumpAndSettle();

      expect(find.text('Export Data'), findsOneWidget);
    });

    testWidgets('OfflineSyncCard is collapsed by default and expands on tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OfflineSyncCard(),
              ),
            ),
          ),
        ),
      );

      // Header is visible
      expect(find.text('Offline & Local Storage'), findsOneWidget);

      // Collapsed: sync action buttons are not visible
      expect(find.text('Sync Now'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('Offline & Local Storage'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });
  });
}
