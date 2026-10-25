import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:watchhive_mobile/features/scanner/widgets/user_qr_dialog.dart';
import 'package:watchhive_mobile/features/scanner/widgets/movie_qr_dialog.dart';

void main() {
  group('QR Dialogs Tests', () {
    testWidgets('UserQrDialog renders user name, handle, QR code, and actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserQrDialog(
              userId: 'user-uuid-123',
              name: 'Aditya Dasamantharao',
              username: 'aditya',
              isMe: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Header
      expect(find.text('My Hive Code'), findsOneWidget);

      // Verify User Details
      expect(find.text('Aditya Dasamantharao'), findsOneWidget);
      expect(find.text('@aditya'), findsOneWidget);

      // Verify QR Code image widget is present
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share Code'), findsOneWidget);
      expect(find.text('Scan Someone Else\'s Code'), findsOneWidget);
    });

    testWidgets('MovieQrDialog renders movie title, media type, QR code, and actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MovieQrDialog(
              tmdbId: 550,
              mediaType: 'movie',
              title: 'Fight Club',
              releaseYear: '1999',
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Header
      expect(find.text('Scan & View on Another Device'), findsOneWidget);

      // Verify Movie Details
      expect(find.text('Fight Club'), findsOneWidget);
      expect(find.text('MOVIE'), findsOneWidget);
      expect(find.text('1999'), findsOneWidget);

      // Verify QR Code image widget is present
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share Code'), findsOneWidget);
      expect(find.text('Open QR Scanner'), findsOneWidget);
    });

    testWidgets('MovieQrDialog displays recommender credit badge when user passes suggestor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MovieQrDialog(
              tmdbId: 550,
              mediaType: 'movie',
              title: 'Fight Club',
              suggestedByUsername: 'aditya',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Scanning credits @aditya as recommender'), findsOneWidget);
    });
  });
}
