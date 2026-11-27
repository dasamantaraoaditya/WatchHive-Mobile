import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/comment.dart';

void main() {
  group('Backend API Response Contracts & Forward/Backward Compatibility', () {
    test('User.fromJson parses standard backend /api/v1/auth & /users payload', () {
      final json = {
        'id': 'usr-1234-uuid',
        'username': 'filmseeker',
        'email': 'filmseeker@example.com',
        'displayName': 'Film Seeker',
        'profilePictureUrl': 'https://watchershive.com/avatars/user.jpg',
        'bio': 'Cinema enthusiast and critic.',
        'location': 'New York, USA',
        'isPrivate': false,
        'privacyLevel': 'PUBLIC',
        'xp': 450,
        'level': 3,
        'streak': 12,
        'createdAt': '2026-10-15T12:00:00Z',
        // Forward-compatibility: new / future backend fields must not break parser
        'v2ExperimentalField': {'beta': true, 'tier': 'gold'},
        'futureMetrics': [1, 2, 3],
      };

      final user = User.fromJson(json);

      expect(user.id, 'usr-1234-uuid');
      expect(user.username, 'filmseeker');
      expect(user.email, 'filmseeker@example.com');
      expect(user.displayName, 'Film Seeker');
      expect(user.profilePictureUrl, 'https://watchershive.com/avatars/user.jpg');
      expect(user.bio, 'Cinema enthusiast and critic.');
      expect(user.location, 'New York, USA');
      expect(user.xp, 450);
      expect(user.level, 3);
    });

    test('User.fromJson handles legacy keys and null fallbacks safely', () {
      final legacyJson = {
        'id': 'usr-legacy-5678',
        'username': 'classicfan',
        'avatarUrl': 'https://s3.amazonaws.com/avatar.png',
        'location': {'name': 'San Francisco'},
        '_count': {'entries': 42, 'followers': 100, 'following': 80},
      };

      final user = User.fromJson(legacyJson);

      expect(user.id, 'usr-legacy-5678');
      expect(user.username, 'classicfan');
      expect(user.profilePictureUrl, 'https://s3.amazonaws.com/avatar.png');
      expect(user.location, 'San Francisco');
      expect(user.bio, isNull);
      expect(user.isPrivate, isFalse);
    });

    test('Entry.fromJson parses movie and TV entry contracts from /api/v1/entries', () {
      final entryJson = {
        'id': 'ent-9999-uuid',
        'userId': 'usr-1234-uuid',
        'tmdbId': 550,
        'title': 'Fight Club',
        'type': 'MOVIE',
        'rating': 9.5,
        'review': 'A groundbreaking psychological thriller.',
        'watchedAt': '2026-11-20T20:00:00Z',
        'posterPath': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
        'backdropPath': '/hZkgoQYus5vegHoetLkCJzb17zJ.jpg',
        'tags': ['cult', 'drama', 'mind-bending'],
        'watchBuddies': [
          {'id': 'buddy-1', 'username': 'edward', 'displayName': 'The Narrator'},
          {'id': 'buddy-2', 'username': 'tyler', 'displayName': 'Tyler Durden'},
        ],
        'likesCount': 15,
        'commentsCount': 4,
        'isLiked': true,
        'isCommented': false,
        // Forward compatibility check:
        'newRecommendationScore': 0.98,
        'aiSummary': 'High entropy narrative match',
      };

      final entry = Entry.fromJson(entryJson);

      expect(entry.id, 'ent-9999-uuid');
      expect(entry.tmdbId, 550);
      expect(entry.title, 'Fight Club');
      expect(entry.type, 'MOVIE');
      expect(entry.rating, 9.5);
      expect(entry.review, 'A groundbreaking psychological thriller.');
      expect(entry.tags, contains('cult'));
      expect(entry.watchBuddies.length, 2);
      expect(entry.watchBuddies[0].username, 'edward');
      expect(entry.likesCount, 15);
      expect(entry.isLiked, isTrue);
    });

    test('Entry.fromJson handles string ratings and missing optional fields', () {
      final minimalJson = {
        'id': 'ent-min-1',
        'tmdbId': '603', // String tmdbId
        'title': 'The Matrix',
        'type': 'movie',
        'rating': '10', // String rating
      };

      final entry = Entry.fromJson(minimalJson);

      expect(entry.id, 'ent-min-1');
      expect(entry.tmdbId, 603);
      expect(entry.title, 'The Matrix');
      expect(entry.rating, 10.0);
      expect(entry.review, isNull);
      expect(entry.watchBuddies, isEmpty);
      expect(entry.likesCount, 0);
      expect(entry.isLiked, isFalse);
    });

    test('Comment.fromJson parses comment contract from /api/v1/comments', () {
      final commentJson = {
        'id': 'comm-777-uuid',
        'entryId': 'ent-9999-uuid',
        'userId': 'usr-1234-uuid',
        'content': 'One of the best plot twists in cinematic history!',
        'createdAt': '2026-11-25T14:30:00Z',
        'user': {
          'id': 'usr-1234-uuid',
          'username': 'cinemaphile',
          'displayName': 'Cinema Phile',
          'profilePictureUrl': 'https://watchershive.com/avatars/user.jpg',
        },
        // Forward compatibility check:
        'reactionCount': 8,
        'pinnedByAuthor': true,
      };

      final comment = Comment.fromJson(commentJson);

      expect(comment.id, 'comm-777-uuid');
      expect(comment.entryId, 'ent-9999-uuid');
      expect(comment.content, 'One of the best plot twists in cinematic history!');
      expect(comment.user?.username, 'cinemaphile');
      expect(comment.user?.displayName, 'Cinema Phile');
    });
  });
}
