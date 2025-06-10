// lib/screens/tours_de_garde_screen.dart
import 'package:flutter/material.dart';
import '../data/app_database.dart';

/// Écran des tours de garde (TWR, BAR, CRM)
/// - Liste triée selon date de dernière occurrence
/// - L'admin peut déplacer un utilisateur en fin de liste via le bouton « Fait »
class ToursDeGardeScreen extends StatefulWidget {
  final AppDatabase db;
  final bool isAdmin;

  const ToursDeGardeScreen({
    super.key,
    required this.db,
    this.isAdmin = false,
  });

  @override
  State<ToursDeGardeScreen> createState() => _ToursDeGardeScreenState();
}

class _ToursDeGardeScreenState extends State<ToursDeGardeScreen> {
  List<User> _twr = [];
  List<User> _bar = [];
  List<User> _crm = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildListsFromPlanning();
  }

  DateTime _maxDate(DateTime? a, DateTime b) {
    if (a == null) return b;
    return a.isAfter(b) ? a : b;
  }

  Future<void> _buildListsFromPlanning() async {
    final users = await widget.db.select(widget.db.users).get();
    final events = await widget.db.select(widget.db.planningEvents).get();

    // Map user-> last occurrence date for each type
    final Map<String, DateTime> lastTwr = {};
    final Map<String, DateTime> lastBar = {};
    final Map<String, DateTime> lastCrm = {};

    for (final e in events) {
      final date = e.dateStart;
      switch (e.typeEvent) {
        case 'TWR':
          lastTwr[e.user] = _maxDate(lastTwr[e.user], date);
          break;
        case 'BAR':
          lastBar[e.user] = _maxDate(lastBar[e.user], date);
          break;
        case 'CRM':
          lastCrm[e.user] = _maxDate(lastCrm[e.user], date);
          break;
      }
    }

    List<User> sortByLast(List<User> list, Map<String, DateTime> lastMap) {
      final copy = [...list];
      copy.sort((a, b) {
        final da = lastMap[a.trigramme] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db_ = lastMap[b.trigramme] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = da.compareTo(db_);
        return cmp != 0 ? cmp : a.trigramme.compareTo(b.trigramme);
      });
      return copy;
    }

    final pilots = users.where((u) => u.role == 'pilot').toList();
    final mechs  = users.where((u) => u.role == 'mecanicien').toList();
    final both   = users.where((u) => u.role == 'pilot' || u.role == 'mecanicien').toList();

    setState(() {
      _twr = sortByLast(pilots, lastTwr);
      _bar = sortByLast(mechs, lastBar);
      _crm = sortByLast(both, lastCrm);
      _loading = false;
    });
  }

  void _markDone(List<User> list, User user) {
    setState(() {
      list.remove(user);
      list.add(user);
    });
  }

  Widget _buildList(String title, List<User> list) {
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
                itemBuilder: (_, i) {
                  final u = list[i];
                  return ListTile(
                    title: Text(u.fullName ?? u.trigramme),
                    subtitle: Text(u.trigramme),
                    trailing: widget.isAdmin
                        ? ElevatedButton(
                      onPressed: () => _markDone(list, u),
                      child: const Text('Fait'),
                    )
                        : null,
                  );
                },
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
          _buildList('TWR (Pilotes)', _twr),
          _buildList('BAR (Mécanos)', _bar),
          _buildList('CRM (Pilotes & Mécanos)', _crm),
        ],
      ),
    );
  }
}
