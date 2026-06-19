/// Opt-in utilities used internally by `flutter_notification_wrapper`.
///
/// These are exposed as a separate entrypoint so they don't pollute the main
/// package namespace (the names `Logger`, `Rx`, `Debouncer` collide with many
/// popular packages). Import only if you want to reuse them:
///
/// ```dart
/// import 'package:flutter_notification_wrapper/utils.dart';
/// ```
library;

export 'src/utils/debounce.dart';
export 'src/utils/logger.dart';
export 'src/utils/rx.dart';
