// Simple internal logger
import 'package:flutter/material.dart';

class Logger {
  final String name;
  Logger(this.name);

  void d(String message) {
    debugPrint('[$name] $message');
  }

  void i(String message) {
    debugPrint('[$name] [INFO] $message');
  }

  void w(String message) {
    debugPrint('[$name] [WARNING] $message');
  }

  void e(String message) {
    debugPrint('[$name] [ERROR] $message');
  }
}
