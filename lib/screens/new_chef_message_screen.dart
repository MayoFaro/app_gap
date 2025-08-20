import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
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

  // Rôle auteur par défaut
  String _authorRole = 'chef_ops';

  // Valeur par défaut : "tous" (au lieu de "all" pour respecter min=4)
  String _group = 'tous';

  bool _loading = false;

  /// Valide et envoie le message vers la base
  Future<void> _sendMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final trigram = prefs.getString('userTrigram') ?? '---';

    if (!_formKey.currentState!.validate()) {
      debugPrint("❌ Validation du formulaire échouée");
      return;
    }

    setState(() => _loading = true);
    debugPrint("➡️ Envoi du message...");

    try {
      final entry = {
        "content": _contentController.text.trim(),
        "authorRole": _authorRole,
        "group": _group,
        "author": trigram,
        "createdAt": FieldValue.serverTimestamp(),
        // "author": "XXX"  // si besoin
      };

      debugPrint("📦 Données préparées : $entry");

      final docRef = await FirebaseFirestore.instance
          .collection("chefMessages")
          .add(entry);

      debugPrint("✅ Message créé avec id ${docRef.id}");

      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint("🔥 Erreur Firestore: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l’envoi : $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
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
              // Champ texte pour contenu du message
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

              // Sélecteur du groupe (tous / avion / helico)
              DropdownButtonFormField<String>(
                value: _group,
                decoration: const InputDecoration(
                  labelText: 'Destinataires',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'tous', child: Text('Tous')),
                  DropdownMenuItem(value: 'avion', child: Text('Avion')),
                  DropdownMenuItem(value: 'helico', child: Text('Hélico')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _group = val);
                  }
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
