// test/logger_test.dart

import 'package:flutter_notification_wrapper/src/utils/logger.dart' show Logger;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Logger', () {
    test('should create logger with name', () {
      const logger = Logger('TestLogger');
      expect(logger.name, 'TestLogger');
    });

    test('should create logger for class', () {
      final logger = Logger.forClass(String);
      expect(logger.name, 'String');
    });

    test('should create logger for feature', () {
      final logger = Logger.forFeature('Notifications');
      expect(logger.name, 'Feature:Notifications');
    });

    test('should implement equality correctly', () {
      const logger1 = Logger('Test');
      const logger2 = Logger('Test');
      const logger3 = Logger('Different');

      expect(logger1, equals(logger2));
      expect(logger1, isNot(equals(logger3)));
      expect(logger1.hashCode, equals(logger2.hashCode));
    });
  });
}
