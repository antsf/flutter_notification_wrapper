// Simple wrapper for Rx<T> to avoid GetX dependency
class Rx<T> {
  T _value;
  final _listeners = <void Function(T)>[];

  Rx(this._value);

  T get value => _value;
  set value(T newValue) {
    _value = newValue;
    for (final listener in _listeners) {
      listener(_value);
    }
  }

  void listen(void Function(T) callback) {
    _listeners.add(callback);
  }
}
