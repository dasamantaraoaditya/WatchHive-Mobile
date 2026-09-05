import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/feed/repositories/comments_repository.dart';
import 'package:watchhive_mobile/features/feed/widgets/comments_sheet.dart';
import 'package:watchhive_mobile/shared/models/comment.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/shared/widgets/app_shell.dart';
import 'package:watchhive_mobile/shared/widgets/wh_quick_add_fab.dart';

class _FakeCommentsRepository implements CommentsRepository {
  final List<Comment> comments;
  bool addCommentCalled = false;
  String? addedContent;

  _FakeCommentsRepository({required this.comments});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Comment>> getComments(String entryId) async => comments;

  @override
  Future<({Comment comment, int commentCount})> addComment(
    String entryId,
    String content, {
    String? parentCommentId,
  }) async {
    addCommentCalled = true;
    addedContent = content;
    final newComment = Comment(
      id: 'new-c-1',
      entryId: entryId,
      userId: 'test-user-id',
      content: content,
      createdAt: DateTime.now(),
    );
    return (comment: newComment, commentCount: comments.length + 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    id: 'test-user-id',
    username: 'bee_keeper',
    displayName: 'Bee Keeper',
    email: 'bee@example.com',
    createdAt: DateTime(2025, 1, 1),
  );

  group('CommentsSheet & WHQuickAddFAB Accessibility & Layout Tests', () {
    testWidgets('WHQuickAddFAB hides when keyboard is open', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: 300), // Keyboard open!
              ),
              child: Stack(
                children: [
                  WHQuickAddFAB(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Since keyboard is open and FAB is not expanded, WHQuickAddFAB returns SizedBox.shrink()
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('WHQuickAddFAB shows when keyboard is closed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                viewInsets: EdgeInsets.zero, // Keyboard closed
              ),
              child: Stack(
                children: [
                  WHQuickAddFAB(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('CommentsSheet.show opens above AppShell and comment submit button is clickable', (tester) async {
      final fakeRepo = _FakeCommentsRepository(comments: []);

      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_comments_btn'),
                      onPressed: () {
                        CommentsSheet.show(
                          context,
                          entryId: 'entry-123',
                          entryTitle: 'Interstellar',
                          entryAuthorId: 'author-456',
                        );
                      },
                      child: const Text('Open Comments'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commentsRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith(
              () => _MockAuthNotifier(AuthState(user: testUser, isAuthenticated: true)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Before opening comments: FAB is visible, comments sheet is not
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byKey(const Key('comment_submit_button')), findsNothing);

      // Tap open comments button
      await tester.tap(find.byKey(const Key('open_comments_btn')));
      await tester.pumpAndSettle();

      // CommentsSheet is open
      expect(find.text('Discussion'), findsOneWidget);
      expect(find.text('Interstellar'), findsOneWidget);

      final submitBtnFinder = find.byKey(const Key('comment_submit_button'));
      expect(submitBtnFinder, findsOneWidget);

      // Type a comment into the input field
      await tester.enterText(find.byType(TextField), 'Amazing cinematography!');
      await tester.pump();

      // Tap the submit button directly
      // If the FAB were rendered on top of the modal sheet, this tap would fail or hit the FAB!
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeRepo.addCommentCalled, isTrue);
      expect(fakeRepo.addedContent, 'Amazing cinematography!');
    });
  });
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  Future<AuthState> build() async => _initialState;
}
