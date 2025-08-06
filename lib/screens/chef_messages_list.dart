// lib/screens/chef_messages_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import '../data/chef_message_dao.dart';
import 'new_chef_message_screen.dart';

/// Écran de gestion des messages du Chef, accessible uniquement aux chefs/CDT/Admin
class ChefMessagesList extends StatefulWidget {
  final ChefMessageDao dao;
  final String currentUser; // Trigramme de l'utilisateur courant

  const ChefMessagesList({
    Key? key,
    required this.dao,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ChefMessagesList> createState() => _ChefMessagesListState();
}

class _ChefMessagesListState extends State<ChefMessagesList> {
  List<ChefMessage>? _messages;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final msgs = await widget.dao.getAllMessages();
    // Acknowledge each message if not already seen by currentUser
    for (final m in msgs) {
      final acks = await widget.dao.getAcks(m.id);
      if (!acks.any((a) => a.trigramme == widget.currentUser)) {
        await widget.dao.acknowledge(m.id, widget.currentUser);
      }
    }
    setState(() => _messages = msgs);
  }

  @override
  Widget build(BuildContext context) {
    if (_messages == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages du Chef')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
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
              await _loadMessages();
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _messages!.length,
        itemBuilder: (context, index) {
          final m = _messages![index];
          return ExpansionTile(
            title: Text(m.content ?? ''),
            subtitle: Text(
              '${m.authorRole} • ${m.group} • ${DateFormat('dd/MM HH:mm').format(m.timestamp)}',
            ),
            children: [
              FutureBuilder<List<ChefMessageAck>>(
                future: widget.dao.getAcks(m.id),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: snap.data!.map((a) {
                        return Chip(
                          label: Text(
                            '${a.trigramme} ${DateFormat('HH:mm').format(a.seenAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              // Suppression globale (toujours disponible, car seuls chefs/CDT accèdent)
              TextButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Supprimer (global)'),
                onPressed: () async {
                  await widget.dao.deleteMessage(m.id);
                  await _loadMessages();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}