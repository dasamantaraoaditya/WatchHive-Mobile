import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/mindlens/repositories/mindlens_repository.dart';
import 'package:watchhive_mobile/features/mindlens/screens/mindlens_screen.dart';

class MockMindLensRepository implements MindLensRepository {
  final Map<String, dynamic> mockData;

  MockMindLensRepository(this.mockData);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> getInsights() async {
    return mockData;
  }
}

void main() {
  testWidgets('MindLens badges render without overflowing on narrow mobile screens (360px)', (tester) async {
    FlutterErrorDetails? errorDetails;
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errorDetails = details;
    };
    addTearDown(() {
      FlutterError.onError = oldHandler;
    });

    // Set a narrow mobile screen width (360px)
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockData = {
      'hasEnoughData': true,
      'affectiveState': {
        'mood': 'Contemplative & Melancholic',
        'status': 'Elevated',
        'description': 'Deep emotional resonance with slow-burn narratives',
        'icon': '🎬',
        'confidence': 94,
        'quadrant': 'Low Valence / High Arousal (Tension)',
        'recentTitles': ['Blade Runner 2049', 'Drive', 'Arrival'],
      },
      'archetype': {
        'name': 'The Contemplative Eudaimonist',
        'tagline': 'Seeker of Cinematic Truth',
        'description': 'Prefers deep narratives',
        'traits': ['Philosophical', 'Introspective', 'High Valence Sensitivity'],
      },
      'entropy': {
        'entropy': 2.45,
        'entropyScore': 0.82,
        'label': 'Eclectic Connoisseur',
        'description': 'Even distribution across complex genres',
        'genreDistribution': [
          {'genre': 'Sci-Fi', 'percentage': 40},
          {'genre': 'Drama', 'percentage': 35},
        ],
      },
      'behavioralTrails': [
        {
          'title': 'Night Owl Explorer',
          'value': '84%',
          'subtitle': 'Circadian Peak 11PM-3AM',
          'description': 'Watches during late night',
          'color': '#FFB700',
        },
      ],
      'suggestionAnalytics': {
        'summary': {
          'overallConversionRate': 76,
          'totalSuggestionsWatched': 14,
          'totalSuggestionsReceived': 20,
        },
        'recommenders': [
          {
            'userId': 'user123',
            'displayName': 'Christopher Nolan Enthusiast Super Long Name',
            'username': 'nolanfan_extra_long_handle_overflow_test',
            'badge': 'Primary Tastemaker',
            'trustScore': 98,
            'conversionRate': 85.0,
            'watchedCount': 14,
            'avgRating': 4.8,
          },
        ],
      },
    };

    final mockRepo = MockMindLensRepository(mockData);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mindLensRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: MindLensScreen(),
        ),
      ),
    );

    // Allow async _fetchMindLensData to complete
    await tester.pumpAndSettle();

    // Restore oldHandler before any test assertions
    FlutterError.onError = oldHandler;

    if (errorDetails != null) {
      FlutterError.dumpErrorToConsole(errorDetails!);
    }
    expect(errorDetails, isNull);
    expect(tester.takeException(), isNull);

    // Verify badges and elements are present and rendered
    expect(find.text('CURRENT AFFECTIVE STATE'), findsOneWidget);
    expect(find.text('Low Valence / High Arousal (Tension)'), findsOneWidget);
    expect(find.text('94% Confidence'), findsOneWidget);
    expect(find.text('PSYCH HIGHLIGHTS'), findsOneWidget);
    expect(find.text('DETAILED ANALYTICS'), findsOneWidget);

    // Scroll to see Influencer badge
    await tester.scrollUntilVisible(
      find.text('Primary Tastemaker'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Primary Tastemaker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
