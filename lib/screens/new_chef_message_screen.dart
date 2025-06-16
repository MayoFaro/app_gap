import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../data/app_database.dart';       // Pour ChefMessagesCompanion
import '../data/chef_message_dao.dart';   // Pour interaction avec la DAO

/// Écran de création d'un nouveau message du chef
class NewChefMessageScreen extends StatefulWidget {
  final ChefMessageDao dao;
  const NewChefMessageScreen({Key? key, required this.dao}) : super(key: key);

  @override
  State<NewChefMessageScreen> createState() => _NewChefMessageScreenState();
}

class _NewChefMessageScreenState extends State<NewChefMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _authorRole = 'chef_ops';
  String _group = 'avion';
  bool _loading = false;

  /// Valide et envoie le message vers la base
  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Création de la companion pour l'insertion
    final entry = ChefMessagesCompanion.insert(
      content: _contentController.text.trim(),
      authorRole: _authorRole,
      group: _group,
      timestamp: Value(DateTime.now()),
    );

    await widget.dao.insertMessage(entry);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau message du Chef')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Contenu',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le contenu ne peut pas être vide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _loading
                  ? const Center(child: CircularProgressIndicator())
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
