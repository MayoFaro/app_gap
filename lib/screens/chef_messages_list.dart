import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chef_message_dao.dart';
import 'new_chef_message_screen.dart';

/// Liste des messages du Chef avec flèches (ACKs), suppression autorisée:
/// - CDT: tous les messages
/// - CHEF: seulement ses propres messages (author == trigramme)
class ChefMessagesList extends StatefulWidget {
  final String currentUser;         // trigramme affiché dans l'UI
  final ChefMessageDao dao;         // pour ouvrir l'écran de création

  const ChefMessagesList({
    Key? key,
    required this.currentUser,
    required this.dao,
  }) : super(key: key);

  @override
  State<ChefMessagesList> createState() => _ChefMessagesListState();
}

class _ChefMessagesListState extends State<ChefMessagesList> {
  final _fs = FirebaseFirestore.instance;
  final _auth = fbAuth.FirebaseAuth.instance;

  String _userTrigram = '---';
  String _userGroup = '';      // 'avion' | 'helico'
  String _userFonction = 'rien';

  @override
  void initState() {
    super.initState();
    _loadLocalContext();
  }

  Future<void> _loadLocalContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userTrigram = (prefs.getString('userTrigram') ?? widget.currentUser).toUpperCase();
        _userGroup = (prefs.getString('userGroup') ?? '').toLowerCase();
        _userFonction = (prefs.getString('userFonction') ?? 'rien').toLowerCase();
      });
    } catch (_) {}
  }

  /// Enregistre (ou met à jour) l'ACK pour l'utilisateur courant sur un message donné
  Future<void> _ackMessage(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final acksRef = _fs.collection('chefMessages').doc(messageId).collection('acks').doc(user.uid);
    await acksRef.set({
      'uid': user.uid,
      'trigramme': _userTrigram,
      'seenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Suppression sécurisée:
  /// - CDT: tout
  /// - CHEF: seulement si author == _userTrigram
  Future<void> _deleteMessage(DocumentSnapshot doc) async {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    final author = (data['author'] as String?)?.toUpperCase() ?? '--';

    final isCdt = _userFonction == 'cdt';
    final isChefAndOwner = _userFonction == 'chef' && author == _userTrigram;

    if (!isCdt && !isChefAndOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Suppression non autorisée")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text('Cette action supprimera aussi les accusés de lecture associés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm != true) return;

    final msgRef = _fs.collection('chefMessages').doc(doc.id);
    try {
      // Supprime d'abord les ACKs (subcollection)
      final acksSnap = await msgRef.collection('acks').get();
      for (final a in acksSnap.docs) {
        await a.reference.delete();
      }
      // Puis le message
      await msgRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message supprimé")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur suppression: $e")),
      );
    }
  }

  String _titleFromContent(String content) {
    final s = content.trim();
    if (s.isEmpty) return '—';
    final firstNl = s.indexOf('\n');
    final head = (firstNl > 0 ? s.substring(0, firstNl) : s);
    return head.length > 60 ? '${head.substring(0, 60)}…' : head;
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = (_userFonction == 'chef' || _userFonction == 'cdt');

    return Scaffold(
      appBar: AppBar(
        title: Text('Messages du Chef ($_userTrigram)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.collection('chefMessages').orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucun message'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = (doc.data() as Map<String, dynamic>? ?? {});
              final content = (data['content'] as String?)?.trim() ?? '';
              final group = (data['group'] as String?) ?? '';
              final author = ((data['author'] as String?) ?? '--').toUpperCase();
              final role = (data['authorRole'] as String?) ?? '';
              final ts = data['createdAt'];
              final createdAt = (ts is Timestamp) ? ts.toDate() : null;

              final title = _titleFromContent(content);
              final subtitle = StringBuffer();
              subtitle.write(author);
              if (role.isNotEmpty) subtitle.write(' • $role');
              if (group.isNotEmpty) subtitle.write(' • $group');
              if (createdAt != null) {
                subtitle.write(' • ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}');
              }

              // Droit de suppression pour CET item
              final canDelete = (_userFonction == 'cdt') || (_userFonction == 'chef' && author == _userTrigram);

              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(title),
                subtitle: Text(subtitle.toString()),
                trailing: canDelete
                    ? IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _deleteMessage(doc),
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                )
                    : null,
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                children: [
                  // Ligne d'action ACK + liste des acks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Accusés de lecture', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => _ackMessage(doc.id),
                        icon: const Icon(Icons.visibility),
                        label: const Text("J'ai lu"),
                      ),
                    ],
                  ),
                  // Liste des ACKs du message
                  StreamBuilder<QuerySnapshot>(
                    stream: _fs
                        .collection('chefMessages')
                        .doc(doc.id)
                        .collection('acks')
                        .orderBy('seenAt', descending: true)
                        .snapshots(),
                    builder: (ctx2, ackSnap) {
                      if (ackSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      if (ackSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Erreur ACKs: ${ackSnap.error}'),
                        );
                      }
                      final acks = ackSnap.data?.docs ?? const [];
                      if (acks.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Aucun ACK pour l’instant'),
                        );
                      }
                      return Column(
                        children: acks.map((a) {
                          final ad = (a.data() as Map<String, dynamic>? ?? {});
                          final trig = (ad['trigramme'] as String?) ?? '--';
                          final ts = ad['seenAt'];
                          final when = (ts is Timestamp)
                              ? DateFormat('dd/MM HH:mm').format(ts.toDate())
                              : '—';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check, color: Colors.green),
                            title: Text(trig),
                            subtitle: Text('vu le $when'),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (content.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(content),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NewChefMessageScreen(dao: widget.dao),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Nouveau message',
      )
          : null,
    );
  }
}
