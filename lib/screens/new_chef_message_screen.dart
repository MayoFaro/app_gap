// lib/screens/new_chef_message_screen.dart
//
// Écran de création d'un "message du chef".
//
// ✅ Changements clés :
//  - Ajout d'un sélecteur de groupe: "tous" | "avion" | "helico".
//  - Insertion locale (Drift) CONSERVÉE.
//  - Écriture Firestore dans /chefMessages pour déclencher les Cloud Functions V2.
//    Champs écrits: message/content/createdAt/author/authorRole/group.
//  - author et authorRole sont récupérés des SharedPreferences si dispo.
//
// ⚠️ Permissions: seules les fonctions 'chef' ou 'cdt' (via users/{uid}.fonction)
//    peuvent écrire (règles Firestore ci-dessus).

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';       // ChefMessagesCompanion
import '../data/chef_message_dao.dart';   // DAO locale

class NewChefMessageScreen extends StatefulWidget {
  final ChefMessageDao dao;
  const NewChefMessageScreen({Key? key, required this.dao}) : super(key: key);

  @override
  State<NewChefMessageScreen> createState() => _NewChefMessageScreenState();
}

class _NewChefMessageScreenState extends State<NewChefMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  // Valeurs renseignées/affichées
  String _authorTrigram = '---';
  String _authorRole = 'chef'; // par défaut; sera écrasé par prefs si 'cdt'
  String _selectedGroup = 'tous'; // "tous" | "avion" | "helico"

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLocalUserInfo();
  }

  Future<void> _loadLocalUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authorTrigram = prefs.getString('userTrigram') ?? '---';
      final f = (prefs.getString('userFonction') ?? '').toLowerCase();
      if (f == 'cdt' || f == 'chef') _authorRole = f;
    });
  }

  /// Écrit le message dans Firestore -> déclenche les notifs (Cloud Functions)
  Future<void> _sendToFirestore(String content) async {
    // Normalisation du champ "group" côté serveur
    final String group =
    (_selectedGroup == 'tous') ? 'all' : (_selectedGroup == 'avion' ? 'avion' : 'helico');

    await FirebaseFirestore.instance.collection('chefMessages').add({
      'message': content, // pour les Functions
      'content': content, // pour UI éventuelle
      'createdAt': FieldValue.serverTimestamp(),
      'author': _authorTrigram,
      'authorRole': _authorRole, // 'chef' | 'cdt'
      'group': group,            // 'all' | 'avion' | 'helico'
    });
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // 🔎 Debug UID courant
    debugPrint('UID courant: ${fbAuth.FirebaseAuth.instance.currentUser?.uid}');
    final text = _contentController.text.trim();

    try {
      // 1) Insertion locale (conservée)
      final entry = ChefMessagesCompanion.insert(
        content: text,
        authorRole: _authorRole,
        group: _selectedGroup, // on garde la valeur affichée côté UI
        timestamp: Value(DateTime.now()),
      );
      await widget.dao.insertMessage(entry);

      // 2) Écriture Firestore (déclenchement notifs)
      await _sendToFirestore(text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message envoyé ✅')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’envoi : Permission ? Règles ?\n$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
              // Infos auteur (contexte)
              Row(
                children: [
                  Expanded(child: _InfoChip(label: 'Trig', value: _authorTrigram)),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoChip(label: 'Fonction', value: _authorRole)),
                ],
              ),
              const SizedBox(height: 12),

              // Sélecteur de groupe
              Row(
                children: [
                  const Text('Cible :'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedGroup,
                    items: const [
                      DropdownMenuItem(value: 'tous',   child: Text('Tous')),
                      DropdownMenuItem(value: 'avion',  child: Text('Avion')),
                      DropdownMenuItem(value: 'helico', child: Text('Hélico')),
                    ],
                    onChanged: (v) => setState(() => _selectedGroup = v ?? 'tous'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Contenu',
                  border: OutlineInputBorder(),
                  hintText: 'Tape ton message…',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le contenu ne peut pas être vide'
                    : null,
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = (value.trim().isEmpty || value == '---') ? '—' : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('$label : ', style: Theme.of(context).textTheme.bodyMedium),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
