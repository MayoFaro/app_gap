// lib/screens/chef_messages_list.dart
//
// Correctifs:
// 1) Les ACKs n'affichent plus l'heure: on montre uniquement le trigramme.
// 2) _authorRole est initialisé automatiquement depuis SharedPreferences
//    (clé 'userFonction' en lowercase), fallback sur 'chef' si absent ou autre.
//
// On conserve:
// - L'état contrôlé des tuiles (Set<String> _expanded) pour éviter la fermeture "automatique"
// - Le StreamBuilder des ACKs démarré uniquement quand la tuile est ouverte
// - La version Firestore (stream en temps réel) inchangée côté données

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Écran de gestion des messages du Chef, accessible uniquement aux chefs/cdt/Admin
class ChefMessagesList extends StatefulWidget {
  final String currentUser; // Trigramme de l'utilisateur courant

  const ChefMessagesList({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ChefMessagesList> createState() => _ChefMessagesListState();
}

class _ChefMessagesListState extends State<ChefMessagesList> {
  /// On mémorise quelles tuiles sont ouvertes (clé = doc.id)
  final Set<String> _expanded = <String>{};

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
                  builder: (_) => const NewChefMessageScreenFirestore(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chefMessages')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Liste des messages
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur messages: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun message du Chef'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final content = (data['content'] ?? '').toString();
              final authorRole = (data['authorRole'] ?? '').toString();
              final group = (data['group'] ?? '').toString();

              // createdAt peut être null tant que serverTimestamp n'est pas posé
              final ts = data['createdAt'];
              final createdAt = ts is Timestamp
                  ? ts.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              final isOpen = _expanded.contains(doc.id);

              return ExpansionTile(
                key: PageStorageKey(doc.id),
                maintainState: true, // garde les enfants montés
                initiallyExpanded: isOpen,
                onExpansionChanged: (open) {
                  setState(() {
                    if (open) {
                      _expanded.add(doc.id);
                    } else {
                      _expanded.remove(doc.id);
                    }
                  });
                },
                title: Text(content),
                subtitle: Text(
                  '$authorRole • $group • ${DateFormat('dd/MM HH:mm').format(createdAt)}',
                ),
                children: [
                  // IMPORTANT:
                  // On NE démarre le stream des ACKs QUE lorsque la tuile est ouverte.
                  if (!isOpen)
                    const SizedBox.shrink()
                  else
                    StreamBuilder<QuerySnapshot>(
                      key: ValueKey('acks_${doc.id}'),
                      stream: FirebaseFirestore.instance
                          .collection('chefMessages')
                          .doc(doc.id)
                          .collection('acks')
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Chargement des ACKs...'),
                          );
                        }
                        if (snap.hasError) {
                          // Utile pour diagnostiquer un PERMISSION_DENIED directement à l’écran
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Erreur ACKs: ${snap.error}'),
                          );
                        }
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Chargement...'),
                          );
                        }

                        final ackDocs = snap.data!.docs;
                        if (ackDocs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Aucun ACK'),
                          );
                        }

                        // --- Affichage : UNIQUEMENT le trigramme ---
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: ackDocs.map((ackDoc) {
                              final ack = ackDoc.data() as Map<String, dynamic>;
                              final trigramme = (ack['trigramme'] ?? '').toString();
                              return Chip(
                                label: Text(
                                  trigramme,
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
                  // Suppression globale
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Supprimer (global)'),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('chefMessages')
                            .doc(doc.id)
                            .delete();
                        setState(() {
                          _expanded.remove(doc.id);
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Écran de création (rôle auto-initialisé depuis SharedPreferences)
class NewChefMessageScreenFirestore extends StatefulWidget {
  const NewChefMessageScreenFirestore({Key? key}) : super(key: key);

  @override
  State<NewChefMessageScreenFirestore> createState() =>
      _NewChefMessageScreenFirestoreState();
}

class _NewChefMessageScreenFirestoreState
    extends State<NewChefMessageScreenFirestore> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  // Valeurs autorisées: 'chef' | 'cdt'
  // On met 'chef' par défaut, puis on écrase avec la valeur réelle en initState.
  String _authorRole = 'chef';

  // Valeurs autorisées: 'tous' | 'avion' | 'helico'
  String _group = 'tous';

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAuthorRoleFromPrefs();
  }

  /// Récupère le rôle réel de l'utilisateur connecté depuis SharedPreferences
  /// (clé 'userFonction', déjà normalisée en lowercase par l'app).
  Future<void> _loadAuthorRoleFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final f = (prefs.getString('userFonction') ?? '').toLowerCase();
      if (f == 'chef' || f == 'cdt') {
        setState(() {
          _authorRole = f;
        });
      } else {
        // fallback: pour éviter toute valeur exotique ('rien'...) côté messages
        setState(() {
          _authorRole = 'chef';
        });
      }
    } catch (_) {
      // en cas d'erreur prefs, on garde 'chef'
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await FirebaseFirestore.instance.collection('chefMessages').add({
      'content': _contentController.text.trim(),
      'authorRole': _authorRole,   // 'chef' ou 'cdt' d'après prefs
      'group': _group,             // 'tous' | 'avion' | 'helico'
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.of(context).pop();
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
              // Contenu
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

              // Destinataires
              DropdownButtonFormField<String>(
                value: _group,
                items: const [
                  DropdownMenuItem(value: 'tous', child: Text('Tous')),
                  DropdownMenuItem(value: 'avion', child: Text('Avion')),
                  DropdownMenuItem(value: 'helico', child: Text('Hélico')),
                ],
                onChanged: (val) => setState(() => _group = val ?? 'tous'),
                decoration: const InputDecoration(
                  labelText: 'Destinataires',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Envoi
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
