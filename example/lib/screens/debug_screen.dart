import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';

class DebugScreen extends StatelessWidget {
  final notificationHandler = DefaultNotificationHandler();

  DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Debug Notifications")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => notificationHandler.enableDevTool(),
              child: const Text("Enable DevTool"),
            ),
            ElevatedButton(
              onPressed: () => notificationHandler.disableDevTool(),
              child: const Text("Disable DevTool"),
            ),
            ElevatedButton(
              onPressed: () => notificationHandler.simulateNotification(
                title: "Test Title",
                body: "This is a simulated notification!",
                data: {"route": "/chat"},
              ),
              child: const Text("Simulate Notification"),
            ),
            ElevatedButton(
              onPressed: () => notificationHandler.openNotificationSettings(),
              child: const Text("Open System Settings"),
            ),
            ElevatedButton(
              onPressed: () => notificationHandler.updateBadgeCount(5),
              child: const Text("Set Badge to 5"),
            ),
            ElevatedButton(
              onPressed: () => notificationHandler.clearBadgeCount(),
              child: const Text("Clear Badge"),
            ),
          ],
        ),
      ),
    );
  }
}
