import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';

/// A single screen exercising every local-notification feature of the package.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DefaultNotificationHandler _handler = DefaultNotificationHandler.I;
  String _status = 'Ready';

  void _report(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<void> _requestPermission() async {
    final status = await _handler.requestPermissions();
    _report('Permission: $status');
  }

  Future<void> _showRegular() async {
    final id = await _handler.showRegularNotification(
      title: 'Hello 👋',
      body: 'A simple notification (id is returned so you can cancel it).',
    );
    _report('Shown regular notification id=$id');
  }

  Future<void> _showAction() async {
    final id = await _handler.showActionNotification(
      title: 'New message',
      body: 'You have a new message',
      buttons: [
        NotificationActionButton(
          key: 'MARK_READ',
          label: 'Mark read',
          actionType: ActionType.SilentAction,
        ),
        NotificationActionButton(key: 'OPEN', label: 'Open'),
      ],
    );
    _report('Shown action notification id=$id');
  }

  Future<void> _showReply() async {
    final id = await _handler.showReplyNotification(
      title: 'Chat',
      body: 'Tap reply to type a response',
      replyLabel: 'Reply',
    );
    _report('Shown reply notification id=$id');
  }

  Future<void> _schedule() async {
    final when = DateTime.now().add(const Duration(seconds: 5));
    final id = await _handler.scheduleNotification(
      id: 1001,
      title: 'Reminder',
      body: 'This was scheduled 5 seconds ago.',
      scheduledDate: when,
    );
    _report('Scheduled notification id=$id for $when');
  }

  Future<void> _showGrouped() async {
    final ids = await _handler.showGroupedNotification('chat_messages', [
      NotificationContent(
        id: 2001,
        channelKey: 'app_channel_01',
        title: 'John',
        body: 'Hey there!',
        groupKey: 'chat_messages',
      ),
      NotificationContent(
        id: 2002,
        channelKey: 'app_channel_01',
        title: 'Jane',
        body: 'Meeting at 3pm',
        groupKey: 'chat_messages',
      ),
    ]);
    _report('Shown grouped notifications ids=$ids');
  }

  Future<void> _setBadge() async {
    await _handler.updateBadgeCount(5);
    _report('Badge set to 5');
  }

  Future<void> _clearBadge() async {
    await _handler.clearBadgeCount();
    _report('Badge cleared');
  }

  Future<void> _cancelAll() async {
    await _handler.cancelAllNotifications();
    _report('All notifications cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final actions = <(String, Future<void> Function())>[
      ('Request permission', _requestPermission),
      ('Show regular', _showRegular),
      ('Show action buttons', _showAction),
      ('Show reply', _showReply),
      ('Schedule (+5s)', _schedule),
      ('Show grouped', _showGrouped),
      ('Set badge = 5', _setBadge),
      ('Clear badge', _clearBadge),
      ('Cancel all', _cancelAll),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Wrapper Example')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Status: $_status',
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final (label, onTap) = actions[i];
                return FilledButton.tonal(
                  onPressed: onTap,
                  child: Text(label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
