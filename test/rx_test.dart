// test/rx_test.dart
import 'package:flutter_notification_wrapper/src/utils/rx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rx', () {
    test('should create reactive value', () {
      final rx = Rx<int>(0);
      expect(rx.value, 0);
    });

    test('should notify listeners on value change', () {
      final rx = Rx<int>(0);
      int? notifiedValue;

      rx
        ..listen((value) {
          notifiedValue = value;
        })
        ..value = 5;

      expect(notifiedValue, 5);
    });

    test('should not notify listeners if value unchanged', () {
      final rx = Rx<int>(0);
      var notificationCount = 0;

      rx
        ..listen((value) {
          notificationCount++;
        })
        ..value = 0; // Same value

      expect(notificationCount, 0);
    });

    test('should update value using function', () {
      final rx = Rx<int>(5)..update((current) => current * 2);

      expect(rx.value, 10);
    });

    test('should remove listener', () {
      final rx = Rx<int>(0);
      var notificationCount = 0;

      void listener(int value) {
        notificationCount++;
      }

      rx
        ..listen(listener)
        ..value = 1;
      expect(notificationCount, 1);

      rx
        ..removeListener(listener)
        ..value = 2;
      expect(notificationCount, 1); // Should not increase
    });

    test('should clear all listeners', () {
      final rx = Rx<int>(0);
      var notificationCount = 0;

      rx
        ..listen((value) => notificationCount++)
        ..listen((value) => notificationCount++)
        ..value = 1;
      expect(notificationCount, 2);

      rx
        ..clearListeners()
        ..value = 2;
      expect(notificationCount, 2); // Should not increase
    });

    test('should implement equality correctly', () {
      final rx1 = Rx<int>(5);
      final rx2 = Rx<int>(5);
      final rx3 = Rx<int>(10);

      expect(rx1, equals(rx2));
      expect(rx1, isNot(equals(rx3)));
      expect(rx1.hashCode, equals(rx2.hashCode));
    });
  });

  group('RxBool', () {
    test('should toggle value', () {
      final rxBool = RxBool(false)..toggle();
      expect(rxBool.value, true);

      rxBool.toggle();
      expect(rxBool.value, false);
    });

    test('should set true and false', () {
      final rxBool = RxBool(false)..setTrue();
      expect(rxBool.value, true);
      expect(rxBool.isTrue, true);
      expect(rxBool.isFalse, false);

      rxBool.setFalse();
      expect(rxBool.value, false);
      expect(rxBool.isTrue, false);
      expect(rxBool.isFalse, true);
    });
  });

  group('RxInt', () {
    test('should increment and decrement', () {
      final rxInt = RxInt(5)..increment();
      expect(rxInt.value, 6);

      rxInt.decrement();
      expect(rxInt.value, 5);
    });

    test('should add and subtract', () {
      final rxInt = RxInt(10)..add(5);
      expect(rxInt.value, 15);

      rxInt.subtract(3);
      expect(rxInt.value, 12);
    });

    test('should multiply', () {
      final rxInt = RxInt(4)..multiply(3);
      expect(rxInt.value, 12);
    });

    test('should check zero, positive, negative', () {
      final rxInt = RxInt(0);
      expect(rxInt.isZero, true);
      expect(rxInt.isPositive, false);
      expect(rxInt.isNegative, false);

      rxInt.value = 5;
      expect(rxInt.isZero, false);
      expect(rxInt.isPositive, true);
      expect(rxInt.isNegative, false);

      rxInt.value = -3;
      expect(rxInt.isZero, false);
      expect(rxInt.isPositive, false);
      expect(rxInt.isNegative, true);
    });
  });

  group('RxString', () {
    test('should append and prepend', () {
      final rxString = RxString('Hello')..append(' World');
      expect(rxString.value, 'Hello World');

      rxString.prepend('Hi ');
      expect(rxString.value, 'Hi Hello World');
    });

    test('should clear string', () {
      final rxString = RxString('Hello')..clear();
      expect(rxString.value, '');
      expect(rxString.isEmpty, true);
      expect(rxString.isNotEmpty, false);
    });

    test('should check length', () {
      final rxString = RxString('Hello');
      expect(rxString.length, 5);

      rxString.append(' World');
      expect(rxString.length, 11);
    });
  });

  group('RxList', () {
    test('should add and remove items', () {
      final rxList = RxList<String>()..add('item1');
      expect(rxList.value, ['item1']);
      expect(rxList.length, 1);
      expect(rxList.isEmpty, false);
      expect(rxList.isNotEmpty, true);

      rxList.addAll(['item2', 'item3']);
      expect(rxList.value, ['item1', 'item2', 'item3']);
      expect(rxList.length, 3);

      rxList.remove('item2');
      expect(rxList.value, ['item1', 'item3']);

      rxList.removeAt(0);
      expect(rxList.value, ['item3']);
    });

    test('should clear list', () {
      final rxList = RxList<String>(['item1', 'item2'])..clear();
      expect(rxList.value, []);
      expect(rxList.isEmpty, true);
      expect(rxList.length, 0);
    });

    test('should get first and last items', () {
      final rxList = RxList<String>(['first', 'middle', 'last']);

      expect(rxList.firstOrNull, 'first');
      expect(rxList.lastOrNull, 'last');

      rxList.clear();
      expect(rxList.firstOrNull, null);
      expect(rxList.lastOrNull, null);
    });
  });
}
