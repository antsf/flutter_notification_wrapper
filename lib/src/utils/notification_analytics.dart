// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';

class NotificationAnalytics {
  static void trackDisplayed(int id) {
    debugPrint('Analytics: Notification ID $id displayed');
  }

  static void trackDismissed(int id) {
    debugPrint('Analytics: Notification ID $id dismissed');
  }

  static void trackDismissedAll() {
    debugPrint('Analytics: All notifications dismissed');
  }

  static void trackClicked(int id) {
    debugPrint('Analytics: Notification ID $id clicked');
  }
}
