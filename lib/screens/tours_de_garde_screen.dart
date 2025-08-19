// lib/screens/tours_de_garde_screen.dart
//
// Affiche 3 colonnes (TWR, BAR, CRM) de trigrammes triés :
//  - par date de dernière occurrence (plus ancien en tête)
//  - tie-break TWR à date égale : rang (1 avant 2 avant 3)
// Déduplication des trigrammes si plusieurs users Firestore partagent le même trigramme.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ToursDeGardeScreen extends StatefulWidget {
  const ToursDeGardeScreen({Key? key, this.isAdmin = false}) : super(key: key);
  final bool isAdmin;

  @override
  State<ToursDeGardeScreen> createState() => _ToursDeGardeScreenState();
}

class _ToursDeGardeScreenState extends State<ToursDeGardeScreen> {
  bool _loading = true;

  List<String> _twr = [];
  List<String> _bar = [];
  List<String> _crm = [];

  @override
  void initState() {
    super.initState();
    _loadAndSort();
  }

  DateTime _maxDate(DateTime? a, DateTime b) {
    if (a == null) return b;
    return b.isAfter(a) ? b : a;
  }

  Future<void> _loadAndSort() async {
    // 1) Charger les users
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();

    // uid -> data ; tri -> uid (on garde le 1er uid rencontré pour un trigramme donné)
    final Map<String, Map<String, dynamic>> uidToData = {};
    final Map<String, String> triToUid = {};
    final Set<String> trigrammesSet = {}; // Set pour dédupliquer

    for (final d in usersSnap.docs) {
      final data = d.data();
      uidToData[d.id] = data;

      final triRaw = data['trigramme'];
      if (triRaw is String) {
        final tri = triRaw.trim();
        if (tri.isNotEmpty) {
          trigrammesSet.add(tri);                 // dédup
          triToUid.putIfAbsent(tri, () => d.id);  // n’écrase pas si déjà présent
        }
      }
    }

    final List<String> trigrammes = trigrammesSet.toList();

    // 2) Charger les events
    final eventsSnap =
    await FirebaseFirestore.instance.collection('planningEvents').get();

    // Maps de dernière occurrence
    final Map<String, DateTime> lastTwrDate = {};
    final Map<String, int>      lastTwrRank = {}; // rang associé à la dernière date
    final Map<String, DateTime> lastBar     = {};
    final Map<String, DateTime> lastCrm     = {};

    for (final doc in eventsSnap.docs) {
      final e = doc.data();
      final type = e['typeEvent'] as String?;
      final uid  = e['user'] as String?;          // UID Firestore
      final ts   = e['dateStart'] as Timestamp?;
      if (type == null || uid == null || ts == null) continue;

      // On lit directement le trigramme via uid -> data
      final trigram = uidToData[uid]?['trigramme'] as String?;
      if (trigram == null) continue;

      final d = ts.toDate();
      final date = DateTime(d.year, d.month, d.day);

      switch (type) {
        case 'TWR':
          final r = e['rank'];
          final rank = (r is int && r >= 1 && r <= 3) ? r : 2; // défaut raisonnable
          final prevDate = lastTwrDate[trigram];
          if (prevDate == null || date.isAfter(prevDate)) {
            lastTwrDate[trigram] = date;
            lastTwrRank[trigram] = rank;
          } else if (prevDate.isAtSameMomentAs(date)) {
            // même jour → on garde le plus petit rang (1 avant 2 avant 3)
            final oldRank = lastTwrRank[trigram] ?? 2;
            if (rank < oldRank) lastTwrRank[trigram] = rank;
          }
          break;

        case 'BAR':
          lastBar[trigram] = _maxDate(lastBar[trigram], date);
          break;

        case 'CRM':
          lastCrm[trigram] = _maxDate(lastCrm[trigram], date);
          break;
      }
    }

    // 3) Filtres par rôle/fonction (typés)
    final pilots = trigrammes.where((t) {
      final uid = triToUid[t];
      final map = (uid != null) ? uidToData[uid] : null;
      final role = (map == null) ? null : map['role'] as String?;
      return role == 'pilote';
    }).toList();

    final mecs = trigrammes.where((t) {
      final uid = triToUid[t];
      final map = (uid != null) ? uidToData[uid] : null;
      final role = (map == null) ? null : map['role'] as String?;
      return role == 'mecano';
    }).toList();

    final crms = trigrammes.where((t) {
      final uid = triToUid[t];
      final map = (uid != null) ? uidToData[uid] : null;
      final fonction = (map == null) ? null : map['fonction'] as String?;
      return fonction != 'cdt';
    }).toList();

    // 4) Tri : ancien en premier, tie-break TWR par rang
    List<String> sortTwr(List<String> list) {
      final copy = [...list];
      copy.sort((a, b) {
        final da = lastTwrDate[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = lastTwrDate[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        final ra = lastTwrRank[a] ?? 2;
        final rb = lastTwrRank[b] ?? 2;
        final rc = ra.compareTo(rb);
        return rc != 0 ? rc : a.compareTo(b);
      });
      // Sécurité anti-doublons, tout en préservant l’ordre obtenu
      final seen = <String>{};
      return [for (final t in copy) if (seen.add(t)) t];
    }

    List<String> sortByLast(List<String> list, Map<String, DateTime> lastMap) {
      final copy = [...list];
      copy.sort((a, b) {
        final da = lastMap[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = lastMap[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = da.compareTo(db);
        return cmp != 0 ? cmp : a.compareTo(b);
      });
      final seen = <String>{};
      return [for (final t in copy) if (seen.add(t)) t];
    }

    if (!mounted) return;
    setState(() {
      _twr = sortTwr(pilots);
      _bar = sortByLast(mecs, lastBar);
      _crm = sortByLast(crms, lastCrm);
      _loading = false;
    });
  }

  Widget _buildColumn(String title, List<String> list) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Text(list[i], style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tours de Garde')),
      body: Row(
        children: [
          _buildColumn('TWR', _twr),
          _buildColumn('BAR', _bar),
          _buildColumn('CRM', _crm),
        ],
      ),
    );
  }
}
