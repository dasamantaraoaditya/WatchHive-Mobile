import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/utils/error_handler.dart';

void main() {
  group('AppErrorHandler Tests', () {
    test('Handles null error with default fallback', () {
      final msg = AppErrorHandler.toUserFriendlyMessage(null);
      expect(msg, equals('An unexpected issue occurred. Please try again.'));

      final custom = AppErrorHandler.toUserFriendlyMessage(null, defaultMessage: 'Custom fallback');
      expect(custom, equals('Custom fallback'));
    });

    test('Handles SocketException gracefully', () {
      final msg = AppErrorHandler.toUserFriendlyMessage(const SocketException('Failed host lookup'));
      expect(msg, contains('Please check your internet connection'));
    });

    test('Handles FormatException gracefully', () {
      final msg = AppErrorHandler.toUserFriendlyMessage(const FormatException('Unexpected character'));
      expect(msg, contains('unexpected response'));
    });

    test('Handles Dio connection timeout', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, contains('Connection timed out'));
    });

    test('Handles Dio connection error', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, contains('Unable to reach WatchHive servers'));
    });

    test('Extracts backend JSON message from Dio 400 response', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'message': 'Password must be at least 8 characters'},
        ),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, equals('Password must be at least 8 characters.'));
    });

    test('Extracts backend JSON error from Dio response', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 409,
          data: {'error': 'Username is already taken'},
        ),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, equals('Username is already taken.'));
    });

    test('Extracts backend detail from FastAPI/Django-style response', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
          data: {'detail': 'Movie not found in database'},
        ),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, equals('Movie not found in database.'));
    });

    test('Handles HTTP 401 unauthorized session expiry', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: null,
        ),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, contains('session has expired'));
    });

    test('Handles HTTP 500 server error', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
          data: null,
        ),
      );
      final msg = AppErrorHandler.toUserFriendlyMessage(dioError);
      expect(msg, contains('temporarily unavailable'));
    });

    test('Sanitizes raw string exception dumps', () {
      const raw = 'Exception: DioException [connection error]: The request connection took longer than 0:00:30.000000 and timed out';
      final clean = AppErrorHandler.sanitize(raw);
      expect(clean, isNot(contains('Exception')));
      expect(clean, isNot(contains('DioException')));
      expect(clean, contains('timed out'));
    });

    test('Sanitizes SocketException string dump', () {
      const raw = 'SocketException: OS Error: Connection refused, errno = 61, address = localhost, port = 51234';
      final clean = AppErrorHandler.sanitize(raw);
      expect(clean, isNot(contains('errno = 61')));
      expect(clean, contains('connection'));
    });

    test('Appends action prefix when provided', () {
      final clean = AppErrorHandler.sanitize('Network is unreachable', action: 'Failed to update bio');
      expect(clean, startsWith('Failed to update bio:'));
      expect(clean, isNot(contains('unreachable')));
    });
  });
}
