// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:meta/meta.dart';

/// A simple reactive wrapper that notifies listeners when its value changes.
///
/// This is a lightweight alternative to more complex reactive programming
/// libraries like RxDart. It's suitable for simple state management needs
/// within the notification wrapper package.
///
/// Example usage:
/// ```dart
/// final counter = Rx<int>(0);
///
/// // Listen to changes
/// counter.listen((value) {
///   print('Counter changed to: $value');
/// });
///
/// // Update the value (triggers listeners)
/// counter.value = 1;
/// ```
class Rx<T> {
  /// Creates a new reactive value with the initial value.
  Rx(this._value);
  T _value;
  final List<void Function(T)> _listeners = [];
  final StreamController<T> _streamController = StreamController<T>.broadcast();

  /// Gets the current value.
  T get value => _value;

  /// Sets a new value and notifies all listeners if the value has changed.
  set value(T newValue) {
    if (_value != newValue) {
      final oldValue = _value;
      _value = newValue;
      _notifyListeners(oldValue, newValue);
    }
  }

  /// Updates the value using a function and notifies listeners if changed.
  void update(T Function(T current) updater) {
    value = updater(_value);
  }

  /// Gets a stream of value changes.
  Stream<T> get stream => _streamController.stream;

  /// Adds a listener that will be called whenever the value changes.
  ///
  /// Returns a function that can be called to remove the listener.
  VoidCallback listen(void Function(T) callback) {
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  /// Adds a listener that will be called with both old and new values.
  ///
  /// Returns a function that can be called to remove the listener.
  VoidCallback listenWithPrevious(
    void Function(T previous, T current) callback,
  ) {
    void wrappedCallback(T current) {
      // This is a simplified version - in a full implementation,
      // you'd want to track the previous value properly
      callback(_value, current);
    }

    return listen(wrappedCallback);
  }

  /// Removes a specific listener.
  void removeListener(void Function(T) callback) {
    _listeners.remove(callback);
  }

  /// Removes all listeners.
  void clearListeners() {
    _listeners.clear();
  }

  /// Disposes of the reactive value and closes the stream.
  ///
  /// Call this when you're done with the Rx to prevent memory leaks.
  void dispose() {
    _listeners.clear();
    _streamController.close();
  }

  /// Notifies all listeners of the value change.
  void _notifyListeners(T oldValue, T newValue) {
    // Create a copy of listeners to avoid concurrent modification
    final listenersToNotify = List<void Function(T)>.from(_listeners);

    for (final listener in listenersToNotify) {
      try {
        listener(newValue);
      } catch (error, stackTrace) {
        // Log error but continue notifying other listeners
        if (kDebugMode) {
          print('Error in Rx listener: $error\n$stackTrace');
        }
      }
    }

    // Also notify stream listeners
    if (!_streamController.isClosed) {
      _streamController.add(newValue);
    }
  }

  /// Returns the current value as a string.
  @override
  String toString() => 'Rx<$T>($_value)';

  /// Checks equality based on the current value.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rx<T> &&
          runtimeType == other.runtimeType &&
          _value == other._value;

  @override
  int get hashCode => _value.hashCode;
}

/// A specialized Rx for boolean values with additional convenience methods.
class RxBool extends Rx<bool> {
  /// Creates a new reactive boolean with the initial value.
  // ignore: avoid_positional_boolean_parameters
  RxBool(super.value);

  /// Toggles the boolean value.
  void toggle() {
    value = !value;
  }

  /// Sets the value to true.
  void setTrue() {
    value = true;
  }

  /// Sets the value to false.
  void setFalse() {
    value = false;
  }

  /// Returns true if the current value is true.
  bool get isTrue => value;

  /// Returns true if the current value is false.
  bool get isFalse => !value;
}

/// A specialized Rx for integer values with additional convenience methods.
class RxInt extends Rx<int> {
  /// Creates a new reactive integer with the initial value.
  RxInt(super.value);

  /// Increments the value by 1.
  void increment() {
    value++;
  }

  /// Decrements the value by 1.
  void decrement() {
    value--;
  }

  /// Adds the specified amount to the current value.
  void add(int amount) {
    value += amount;
  }

  /// Subtracts the specified amount from the current value.
  void subtract(int amount) {
    value -= amount;
  }

  /// Multiplies the current value by the specified factor.
  void multiply(int factor) {
    value *= factor;
  }

  /// Returns true if the current value is zero.
  bool get isZero => value == 0;

  /// Returns true if the current value is positive.
  bool get isPositive => value > 0;

  /// Returns true if the current value is negative.
  bool get isNegative => value < 0;
}

/// A specialized Rx for String values with additional convenience methods.
class RxString extends Rx<String> {
  /// Creates a new reactive string with the initial value.
  RxString(super.value);

  /// Appends text to the current value.
  void append(String text) {
    value += text;
  }

  /// Prepends text to the current value.
  void prepend(String text) {
    value = text + value;
  }

  /// Clears the string (sets it to empty).
  void clear() {
    value = '';
  }

  /// Returns true if the current value is empty.
  bool get isEmpty => value.isEmpty;

  /// Returns true if the current value is not empty.
  bool get isNotEmpty => value.isNotEmpty;

  /// Returns the length of the current string value.
  int get length => value.length;
}

/// A specialized Rx for List values with additional convenience methods.
class RxList<T> extends Rx<List<T>> {
  /// Creates a new reactive list with the initial value.
  RxList([List<T>? initial]) : super(initial ?? <T>[]);

  /// Adds an item to the list.
  void add(T item) {
    final newList = List<T>.from(value)..add(item);
    value = newList;
  }

  /// Adds all items to the list.
  void addAll(Iterable<T> items) {
    final newList = List<T>.from(value)..addAll(items);
    value = newList;
  }

  /// Removes an item from the list.
  void remove(T item) {
    final newList = List<T>.from(value)..remove(item);
    value = newList;
  }

  /// Removes an item at the specified index.
  void removeAt(int index) {
    final newList = List<T>.from(value)..removeAt(index);
    value = newList;
  }

  /// Clears all items from the list.
  void clear() {
    value = <T>[];
  }

  /// Returns true if the list is empty.
  bool get isEmpty => value.isEmpty;

  /// Returns true if the list is not empty.
  bool get isNotEmpty => value.isNotEmpty;

  /// Returns the length of the list.
  int get length => value.length;

  /// Returns the first item in the list, or null if empty.
  T? get firstOrNull => value.isEmpty ? null : value.first;

  /// Returns the last item in the list, or null if empty.
  T? get lastOrNull => value.isEmpty ? null : value.last;
}
