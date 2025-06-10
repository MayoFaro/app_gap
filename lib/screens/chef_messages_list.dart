// lib/screens/chef_messages_list.dart
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/chef_message_dao.dart';
import 'new_chef_message_screen.dart';

class ChefMessagesList extends StatefulWidget {
  final ChefMessageDao dao;
  const ChefMessagesList({super.key, required this.dao});

  @override
  State<ChefMessagesList> createState() => _ChefMessagesListState();
}

class _ChefMessagesListState extends State<ChefMessagesList> {
  late Future<List<ChefMessage>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    _messagesFuture = widget.dao.getAllMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages du Chef'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NewChefMessageScreen(dao: widget.dao),
                ),
              );
              _loadMessages();
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ChefMessage>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Aucun message'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              return ListTile(
                title: Text(m.content ?? ''),
                subtitle: Text(
                  '${m.authorRole} • ${m.group} • ${m.timestamp.toLocal().toIso8601String()}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await widget.dao.deleteMessage(m.id);
                    _loadMessages();
                    setState(() {});
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
