import 'dart:io';
import 'package:dio/dio.dart';

class AppErrorHandler {
  /// Converts any error object or exception into a clean, concise,
  /// human-readable message suitable for display in UI toasts and error screens.
  static String toUserFriendlyMessage(
    dynamic error, {
    String? defaultMessage,
    String? action,
  }) {
    if (error == null) {
      return defaultMessage ?? 'An unexpected issue occurred. Please try again.';
    }

    // 1. Handle DioException specifically
    if (error is DioException) {
      return _handleDioException(error, action: action, defaultMessage: defaultMessage);
    }

    // 2. Handle SocketException (network failure)
    if (error is SocketException) {
      return _formatWithAction(
        'Unable to connect to WatchHive. Please check your internet connection and try again.',
        action: action,
      );
    }

    // 3. Handle FormatException
    if (error is FormatException) {
      return _formatWithAction(
        'Received an unexpected response from the server. Please try again.',
        action: action,
      );
    }

    // 4. Handle String or general Exception
    final rawString = error.toString().trim();
    return sanitize(rawString, action: action, defaultMessage: defaultMessage);
  }

  static String _handleDioException(
    DioException dioError, {
    String? action,
    String? defaultMessage,
  }) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _formatWithAction(
          'Connection timed out. Please check your network and try again.',
          action: action,
        );

      case DioExceptionType.connectionError:
        return _formatWithAction(
          'Unable to reach WatchHive servers. Please check your internet connection.',
          action: action,
        );

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.badCertificate:
        return 'Security certificate verification failed.';

      case DioExceptionType.badResponse:
        final response = dioError.response;
        final statusCode = response?.statusCode;

        // Try extracting backend error message
        final backendMessage = _extractBackendMessage(response?.data);
        if (backendMessage != null && backendMessage.isNotEmpty) {
          return backendMessage;
        }

        if (statusCode != null) {
          if (statusCode == 400) {
            return _formatWithAction('Invalid request details. Please check and try again.', action: action);
          } else if (statusCode == 401) {
            return 'Your session has expired. Please log in again to continue.';
          } else if (statusCode == 403) {
            return 'You do not have permission to perform this action.';
          } else if (statusCode == 404) {
            return _formatWithAction('The requested item could not be found.', action: action);
          } else if (statusCode == 409) {
            return _formatWithAction('This item is already added or in conflict.', action: action);
          } else if (statusCode == 413) {
            return 'The uploaded image or file is too large. Please choose a smaller one.';
          } else if (statusCode == 422) {
            return 'The submitted data was incomplete or invalid.';
          } else if (statusCode == 429) {
            return 'Too many requests. Please slow down and try again in a few seconds.';
          } else if (statusCode >= 500) {
            return 'WatchHive servers are temporarily unavailable. Please try again shortly.';
          }
        }
        break;

      case DioExceptionType.unknown:
      default:
        final underlying = dioError.error;
        if (underlying is SocketException) {
          return _formatWithAction(
            'Unable to connect to the server. Please check your internet connection.',
            action: action,
          );
        }
        break;
    }

    return defaultMessage ?? 'Something went wrong. Please try again.';
  }

  /// Extracts readable error text from common backend response structures:
  /// e.g. {"message": "Invalid password"}, {"error": "..."}, or {"errors": ["..."]}
  static String? _extractBackendMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      if (data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
        return _cleanMessage(data['message'] as String);
      }
      if (data['error'] is String && (data['error'] as String).trim().isNotEmpty) {
        return _cleanMessage(data['error'] as String);
      }
      if (data['detail'] is String && (data['detail'] as String).trim().isNotEmpty) {
        return _cleanMessage(data['detail'] as String);
      }
      if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
        final first = (data['errors'] as List).first;
        if (first is String && first.trim().isNotEmpty) return _cleanMessage(first);
        if (first is Map && first['message'] is String) return _cleanMessage(first['message']);
      }
    } else if (data is String && data.trim().isNotEmpty) {
      if (!data.startsWith('<') && !data.contains('<!DOCTYPE')) {
        return _cleanMessage(data);
      }
    }

    return null;
  }

  /// Sanitizes any raw exception string, stripping exception names,
  /// stack traces, and internal technical jargon.
  static String sanitize(
    String raw, {
    String? action,
    String? defaultMessage,
  }) {
    if (raw.isEmpty) {
      return defaultMessage ?? 'An unexpected issue occurred. Please try again.';
    }

    // Strip common exception prefixes
    var cleaned = raw
        .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^DioException\s*\[.*?\]:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^SocketException:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^FormatException:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^PlatformException\([^)]*\),\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^StateError\([^)]*\):\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^TypeError:\s*', caseSensitive: false), '')
        .trim();

    // Check for network errors in text
    final lower = cleaned.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection error') ||
        lower.contains('connection reset') ||
        lower.contains('broken pipe') ||
        lower.contains('clientexception with socketexception')) {
      return _formatWithAction(
        'Unable to reach server. Please check your connection and try again.',
        action: action,
      );
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return _formatWithAction(
        'The request timed out. Please check your connection and try again.',
        action: action,
      );
    }

    if (lower.contains('session expired') || lower.contains('401') || lower.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }

    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'You do not have permission for this action.';
    }

    if (lower.contains('404') || lower.contains('not found')) {
      return _formatWithAction('Item not found.', action: action);
    }

    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('internal server error') ||
        lower.contains('bad gateway')) {
      return 'Server error. Our hive is experiencing high traffic, please try again shortly.';
    }

    if (lower.contains('null check operator used on a null value') ||
        lower.contains('rangeerror') ||
        lower.contains('nosuchmethoderror')) {
      return _formatWithAction(
        defaultMessage ?? 'Could not process data. Please try again.',
        action: action,
      );
    }

    // Try to extract embedded JSON message if present
    if (cleaned.contains('{"message":') || cleaned.contains('{"error":')) {
      final match = RegExp(r'"(?:message|error)"\s*:\s*"([^"]+)"').firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        return _cleanMessage(match.group(1)!);
      }
    }

    // If cleaned string has an action prefix like "Failed to add: something"
    if (cleaned.contains(': ')) {
      final parts = cleaned.split(': ');
      if (parts.length > 1) {
        final lastPart = parts.last.trim();
        // If the last part is a clean human message, use it
        if (!lastPart.contains('[') && !lastPart.contains('Exception') && lastPart.length < 90) {
          cleaned = lastPart;
        }
      }
    }

    // Cap length to avoid wall of text
    if (cleaned.length > 120) {
      cleaned = '${cleaned.substring(0, 117)}...';
    }

    return _cleanMessage(cleaned);
  }

  static String _cleanMessage(String msg) {
    var text = msg.trim();
    if (text.isEmpty) return 'Operation failed. Please try again.';
    // Ensure capitalization
    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }
    // Ensure terminal punctuation if it reads like a full sentence
    if (!text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?')) {
      text = '$text.';
    }
    return text;
  }

  static String _formatWithAction(String message, {String? action}) {
    if (action != null && action.trim().isNotEmpty) {
      final cleanAction = action.trim();
      return '$cleanAction: $message';
    }
    return message;
  }
}
