// lib/widgets/chef_message_banner.dart
//
// Bannière "Message du chef" pour la page d'accueil.
// - Stream Firestore des 20 derniers messages (orderBy createdAt desc).
// - Filtre côté client: group in {'all', userGroup}.
// - Affiche le plus récent non "dismissed".
// - À la première apparition, écrit un ACK dans /chefMessages/{id}/acks/{uid}.
//
// Dépendances: cloud_firestore, firebase_auth, shared_preferences.
// Intégration: placer ce widget à l'emplacement de l'ancien FutureBuilder
// dans ton HomeDashboard.
//
// Affichage attendu (si non dismiss) :
//   ┌───────────────────────────────┐
//   │  Message du Chef (groupe)     │  [X]
//   │  <contenu>                     │
//   │  Auteur: ABC • 12:34           │
//   └───────────────────────────────┘

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChefMessageBanner extends StatefulWidget {
  const ChefMessageBanner({super.key});

  @override
  State<ChefMessageBanner> createState() => _ChefMessageBannerState();
}

class _ChefMessageBannerState extends State<ChefMessageBanner> {
  String _userGroup = 'avion';     // défaut raisonnable
  String _trigramme = '---';
  String _uid = '';
  Set<String> _dismissed = {};
  bool _ready = false;
  final _ackedOnce = <String>{};   // évite multi-écritures

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _userGroup = (prefs.getString('userGroup') ?? 'avion').toLowerCase();
    _trigramme = prefs.getString('userTrigram') ?? '---';
    _dismissed = (prefs.getStringList('dismissedChefMessageIds') ?? []).toSet();

    _uid = fbAuth.FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _ready = true);
  }

  Future<void> _saveDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissedChefMessageIds', _dismissed.toList());
  }

  Future<void> _ackIfNeeded(DocumentSnapshot doc) async {
    if (_uid.isEmpty) return;
    if (_ackedOnce.contains(doc.id)) return; // déjà envoyé dans cette session
    _ackedOnce.add(doc.id);

    try {
      await doc.reference.collection('acks').doc(_uid).set({
        'uid': _uid,
        'trigramme': _trigramme,
        'seenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // on ignore pour ne pas casser l'UI
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();

    // Stream des 20 derniers messages (pas de filtre Firestore => pas d'index requis)
    final stream = FirebaseFirestore.instance
        .collection('chefMessages')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Message du chef indisponible (${snap.error})',
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        final docs = snap.data?.docs ?? [];

        // Filtre côté client: group == 'all' ou == _userGroup
        final filtered = docs.where((d) {
          final g = (d.get('group') ?? 'all').toString().toLowerCase();
          return g == 'all' || g == _userGroup;
        }).toList();

        if (filtered.isEmpty) return const SizedBox.shrink();

        final doc = filtered.first; // le plus récent
        if (_dismissed.contains(doc.id)) return const SizedBox.shrink();

        // ACK (fire-and-forget)
        _ackIfNeeded(doc);

        final content = (doc.get('message') ?? doc.get('content') ?? '').toString();
        final author = (doc.get('author') ?? '').toString();
        final group = (doc.get('group') ?? 'all').toString();
        DateTime? createdAt;
        final ts = doc.get('createdAt');
        if (ts is Timestamp) createdAt = ts.toDate();

        final timeStr = createdAt != null ? DateFormat('dd/MM HH:mm').format(createdAt) : '—';

        return Dismissible(
          key: ValueKey(doc.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) async {
            setState(() => _dismissed.add(doc.id));
            await _saveDismissed();
          },
          background: Container(
            color: Colors.redAccent.withOpacity(0.8),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.close, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message du Chef (${group.toUpperCase()})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(content),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Auteur: ${author.isEmpty ? '—' : author}'),
                    const Spacer(),
                    Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
