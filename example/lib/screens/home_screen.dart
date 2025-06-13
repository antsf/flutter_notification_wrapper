import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'debug_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final notificationHandler = DefaultNotificationHandler.I;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notification Wrapper')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DebugScreen()),
                  );
                },
                child: const Text('Open Debug Screen'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final token = await notificationHandler.getFcmToken();
                  debugPrint('FCM Token: $token');
                },
                child: const Text('Get FCM Token'),
              ),
            ],
          ),
        ),
      );
}
