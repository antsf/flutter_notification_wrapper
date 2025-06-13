// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:meta/meta.dart';

/// A utility class for debouncing function calls.
///
/// Debouncing ensures that a function is only called once after a specified
/// delay, even if it's triggered multiple times. This is useful for scenarios
/// like preventing duplicate notifications or handling rapid user interactions.
///
/// Example usage:
/// ```dart
/// final debouncer = Debouncer(delay: Duration(milliseconds: 500));
///
/// // This will only execute once, even if called multiple times rapidly
/// debouncer.run(() {
///   print('This will only print once after 500ms');
/// });
/// ```
// @immutable
class Debouncer {
  /// Creates a new debouncer with the specified delay.
  Debouncer({required this.delay});

  /// The delay duration before executing the debounced function
  final Duration delay;

  /// Internal timer for managing the debounce delay
  Timer? timer;

  /// Whether the debouncer is currently active (has a pending execution)
  bool get isActive => timer?.isActive ?? false;

  /// Runs the provided action after the debounce delay.
  ///
  /// If this method is called again before the delay expires,
  /// the previous call is cancelled and a new delay starts.
  void run(VoidCallback action) {
    cancel();
    timer = Timer(delay, action);
  }

  /// Runs the provided async action after the debounce delay.
  ///
  /// Similar to [run] but supports async functions.
  void runAsync(Future<void> Function() action) {
    cancel();
    timer = Timer(delay, () async {
      try {
        await action();
      } catch (error, stackTrace) {
        // Log error but don't rethrow to prevent unhandled exceptions
        debugPrint('Debouncer async action error: $error\n$stackTrace');
      }
    });
  }

  /// Cancels any pending debounced action.
  void cancel() {
    timer?.cancel();
    timer = null;
  }

  /// Disposes of the debouncer and cancels any pending actions.
  ///
  /// Call this when you're done with the debouncer to prevent memory leaks.
  void dispose() {
    cancel();
  }

  @override
  String toString() => 'Debouncer(delay: $delay, isActive: $isActive)';
}

/// A specialized debouncer for handling notification-related operations.
///
/// This debouncer includes additional features specific to notification handling,
/// such as tracking the last processed message ID to prevent duplicates.
class NotificationDebouncer extends Debouncer {
  /// Creates a new notification debouncer with the specified delay.
  NotificationDebouncer({required super.delay});

  /// The ID of the last processed message
  String? _lastMessageId;

  /// Gets the ID of the last processed message
  String? get lastMessageId => _lastMessageId;

  /// Runs the action only if the message ID is different from the last processed one.
  ///
  /// This helps prevent duplicate notification processing when the same
  /// notification is received multiple times.
  void runForMessage(String? messageId, VoidCallback action) {
    if (messageId == null || messageId != _lastMessageId) {
      _lastMessageId = messageId;
      run(action);
    }
  }

  /// Runs the async action only if the message ID is different from the last processed one.
  void runAsyncForMessage(String? messageId, Future<void> Function() action) {
    if (messageId == null || messageId != _lastMessageId) {
      _lastMessageId = messageId;
      runAsync(action);
    }
  }

  /// Resets the last message ID, allowing the next message to be processed
  /// regardless of its ID.
  void resetLastMessageId() {
    _lastMessageId = null;
  }

  @override
  String toString() =>
      'NotificationDebouncer(delay: $delay, isActive: $isActive, lastMessageId: $_lastMessageId)';
}

/// A collection of commonly used debounce durations.
class DebounceDurations {
  /// Very short debounce for rapid interactions (100ms)
  static const Duration veryShort = Duration(milliseconds: 100);

  /// Short debounce for user interactions (250ms)
  static const Duration short = Duration(milliseconds: 250);

  /// Medium debounce for notifications (500ms)
  static const Duration medium = Duration(milliseconds: 500);

  /// Long debounce for expensive operations (1000ms)
  static const Duration long = Duration(milliseconds: 1000);

  /// Very long debounce for rare operations (2000ms)
  static const Duration veryLong = Duration(milliseconds: 2000);
}
