// lib/screens/new_chef_message_screen.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column; // pour Value
import '../data/app_database.dart'; // pour ChefMessagesCompanion
import '../data/chef_message_dao.dart';

class NewChefMessageScreen extends StatefulWidget {
  final ChefMessageDao dao;
  const NewChefMessageScreen({super.key, required this.dao});

  @override
  State<NewChefMessageScreen> createState() => _NewChefMessageScreenState();
}

class _NewChefMessageScreenState extends State<NewChefMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _authorRole = 'chef_ops';
  String _group = 'avion';
  bool _loading = false;

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final entry = ChefMessagesCompanion.insert(
      content: Value(_contentController.text.trim()),
      authorRole: _authorRole,
      group: _group,
      timestamp: DateTime.now(),
    );
    await widget.dao.insertMessage(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau message')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _authorRole,
                items: const [
                  DropdownMenuItem(value: 'chef_ops', child: Text('chef_ops')),
                  DropdownMenuItem(value: 'chef', child: Text('chef')),
                  DropdownMenuItem(value: 'adjchefops', child: Text('adjchefops')),
                ],
                onChanged: (v) => setState(() => _authorRole = v!),
                decoration: const InputDecoration(labelText: 'Rôle de l’auteu­ r'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _group,
                items: const [
                  DropdownMenuItem(value: 'avion', child: Text('Avion')),
                  DropdownMenuItem(value: 'helico', child: Text('Hélico')),
                  DropdownMenuItem(value: 'both', child: Text('Les deux')),
                ],
                onChanged: (v) => setState(() => _group = v!),
                decoration: const InputDecoration(labelText: 'Groupe destinataire'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Contenu'),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Le contenu ne peut être vide'
                    : null,
              ),
              const SizedBox(height: 24),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _sendMessage,
                child: const Text('Envoyer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
