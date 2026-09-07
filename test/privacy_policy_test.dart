import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/screens/privacy_policy_screen.dart';

void main() {
  group('Privacy Policy Screen Tests', () {
    testWidgets('renders all essential privacy policy sections & guarantee', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      // Verify header and last updated badge
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('LAST UPDATED: JUNE 2, 2026'), findsOneWidget);

      // Verify action buttons
      expect(find.byTooltip('Open Web Version'), findsOneWidget);

      // Verify core sections
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('The Data We Collect'), findsOneWidget);
      expect(find.text('Core Feature Analytics & MindLens'), findsOneWidget);
      expect(find.text('MindLens Data Guarantee'), findsOneWidget);
      expect(find.text('Swarm Feed & Visibility Controls'), findsOneWidget);
      expect(find.text('Local Cache & Offline Logging'), findsOneWidget);
      expect(find.text('Google OAuth Integration'), findsOneWidget);
      expect(find.text('Data Security & Encryption'), findsOneWidget);
      expect(find.text('Your Data Rights & Deletion'), findsOneWidget);

      // Verify data types categorized
      expect(find.text('Identity Data'), findsOneWidget);
      expect(find.text('Contact Data'), findsOneWidget);
      expect(find.text('Profile & Watch Data'), findsOneWidget);
      expect(find.text('Psychology Metrics'), findsOneWidget);

      // Verify contact button
      expect(find.text('Contact ${PrivacyPolicyScreen.contactEmail}'), findsOneWidget);
    });

    testWidgets('MindLens data guarantee emphasizes privacy to users', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      expect(
        find.textContaining('We do NOT sell, rent, or distribute your MindLens datasets'),
        findsOneWidget,
      );
    });

    test('static URLs and contact email are valid', () {
      expect(PrivacyPolicyScreen.webPrivacyPolicyUrl, 'https://watchhive-web.vercel.app/privacy');
      expect(PrivacyPolicyScreen.contactEmail, 'privacy@watchhive.app');
    });
  });
}
