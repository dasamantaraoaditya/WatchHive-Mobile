import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/widgets/avatar_viewer_dialog.dart';

void main() {
  group('AvatarViewerDialog Tests', () {
    testWidgets('renders name and handle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarViewerDialog(
              imageUrl: null,
              name: 'John Doe',
              username: 'johndoe',
            ),
          ),
        ),
      );

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('@johndoe'), findsOneWidget);
      expect(find.text('Pinch to zoom'), findsOneWidget);
      expect(find.text('Remove Profile Photo'), findsNothing);
    });

    testWidgets('shows Remove Profile Photo button when imageUrl and onRemoveAvatar are present', (tester) async {
      bool removeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarViewerDialog(
              imageUrl: 'https://example.com/avatar.jpg',
              name: 'John Doe',
              username: 'johndoe',
              onRemoveAvatar: () {
                removeCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Remove Profile Photo'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.tap(find.text('Remove Profile Photo'));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
    });

    testWidgets('hides Remove Profile Photo button when onRemoveAvatar is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarViewerDialog(
              imageUrl: 'https://example.com/avatar.jpg',
              name: 'Jane Doe',
              username: 'janedoe',
              onRemoveAvatar: null,
            ),
          ),
        ),
      );

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Remove Profile Photo'), findsNothing);
    });

    testWidgets('hides Remove Profile Photo button when imageUrl is null or empty', (tester) async {
      bool removeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarViewerDialog(
              imageUrl: '',
              name: 'John Doe',
              username: 'johndoe',
              onRemoveAvatar: () {
                removeCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Remove Profile Photo'), findsNothing);
      expect(removeCalled, isFalse);
    });
  });
}
