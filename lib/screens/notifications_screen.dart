
// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart' hide Notification;
import '../data/app_database.dart';
import '../data/notification_dao.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationDao dao;
  final String group;

  const NotificationsScreen({super.key, required this.dao, required this.group});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Notification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _notificationsFuture = widget.dao.getForGroup(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Notification>>(
        future: _notificationsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Aucune notification'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];
              return Dismissible(
                key: ValueKey(n.id),
                background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: 16), child: Icon(Icons.delete, color: Colors.white)),
                secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 16), child: Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) async {
                  await widget.dao.deleteNotification(n.id);
                },
                child: ListTile(
                  leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active),
                  title: Text(n.type),
                  subtitle: Text(n.payload ?? ''),
                  trailing: Text(
                    n.timestamp.toLocal().toIso8601String().replaceFirst('T', ' '),
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () async {
                    if (!n.isRead) {
                      await widget.dao.markRead(n.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
