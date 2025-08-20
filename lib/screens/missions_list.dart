// lib/screens/missions_list.dart
import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';

class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

/// Écran des missions hebdo (AVION).
class MissionsList extends StatefulWidget {
  final MissionDao dao;
  final bool canEdit;

  const MissionsList({
    Key? key,
    required this.dao,
    required this.canEdit,
  }) : super(key: key);

  @override
  State<MissionsList> createState() => _MissionsListState();
}

class _MissionsListState extends State<MissionsList> {
  late Future<_MissionsData> _dataFuture;

  // 🔔 Abonnement Drift (permet de rafraîchir quand la table missions change)
  StreamSubscription<List<Mission>>? _missionSub;

  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG MissionsAvion.initState');
    _refreshData(); // premier chargement

    final db = widget.dao.attachedDatabase;

    // On écoute la table missions (sans filtrage, pour capter tous les changements).
    final stream = (db.select(db.missions)
      ..where((m) => m.vecteur.equals('ATR72')))
        .watch();

    _missionSub = stream.listen((rows) {
      debugPrint(
        'DEBUG MissionsAvion.stream: changement local détecté (rows=${rows.length}) -> _refreshData()',
      );
      _refreshData();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _missionSub?.cancel();
    super.dispose();
  }

  void _refreshData() {
    _dataFuture = _loadData();
  }

  Future<_MissionsData> _loadData() async {
    final all = await widget.dao.getAllMissions();
    debugPrint('DEBUG MissionsAvion._loadData: total local=${all.length}');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ➡️ Filtrage : uniquement ATR72 et date >= aujourd’hui
    final filtered = all
        .where((m) => m.vecteur == 'ATR72' && !m.date.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final data = _MissionsData(missions: filtered, isChef: widget.canEdit);
    debugPrint(
      'DEBUG MissionsAvion._loadData: isChef=${data.isChef}, filtered=${data.missions.length}',
    );
    return data;
  }

  Future<void> _showMissionDialog({Mission? mission}) async {
    final allUsers = await widget.dao.attachedDatabase.users.select().get();

    // Liste des pilotes avion
    final pilotes = ['--'] +
        allUsers
            .where((u) =>
        u.role.toLowerCase() == 'pilote' &&
            u.group.toLowerCase() == 'avion')
            .map((u) => u.trigramme)
            .toList();

    // borne à aujourd’hui
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);
    DateTime chosenDate = mission?.date ?? minDate;
    if (chosenDate.isBefore(minDate)) chosenDate = minDate;

    // Destination & heure
    final destinations = ['--', 'FOOL', 'FOON', 'FOOG', 'FOGR', 'FOGO'];
    String chosenDest = mission?.destinationCode ?? destinations.first;
    String chosenTime =
    mission != null ? DateFormat('HH:mm').format(mission.date) : '08:30';

    // Pilotes initiaux
    String chosenP1 = mission?.pilote1 ?? pilotes.first;
    String chosenP2 = mission?.pilote2 ?? pilotes.first;

    final remarkCtrl = TextEditingController(text: mission?.description);

    // Heures par pas de 30 mn
    final times = List.generate(48, (i) {
      final h = i ~/ 2;
      final m = (i % 2) * 30;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    });

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateInner) => AlertDialog(
          title: Text(
              mission == null ? 'Ajouter mission avion' : 'Modifier mission avion'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date avec flèches
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: chosenDate.isAfter(minDate)
                          ? () => setStateInner(
                              () => chosenDate = chosenDate.subtract(const Duration(days: 1)))
                          : null,
                    ),
                    Text(DateFormat('dd/MM/yyyy').format(chosenDate)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setStateInner(
                              () => chosenDate = chosenDate.add(const Duration(days: 1))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Destination
                const Text('Destination'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: destinations.indexOf(chosenDest),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenDest = destinations[i]),
                    children: destinations.map((d) => Center(child: Text(d))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Heure
                const Text('Heure de décollage'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: times.indexOf(chosenTime),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenTime = times[i]),
                    children: times.map((t) => Center(child: Text(t))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Pilote 1
                const Text('Pilote 1'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: pilotes.indexOf(chosenP1),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenP1 = pilotes[i]),
                    children: pilotes.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Pilote 2
                const Text('Pilote 2'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: pilotes.indexOf(chosenP2),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenP2 = pilotes[i]),
                    children: pilotes.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Remarque
                const Text('Remarque'),
                TextField(controller: remarkCtrl),
              ],
            ),
          ),
          actions: [
            if (mission != null)
              TextButton(
                onPressed: () async {
                  await widget.dao.deleteMission(mission.id);
                  Navigator.of(ctx2).pop();
                },
                child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
                onPressed: () => Navigator.of(ctx2).pop(),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final parts = chosenTime.split(':');
                final dt = DateTime(
                  chosenDate.year,
                  chosenDate.month,
                  chosenDate.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );

                if (mission == null) {
                  // ➕ Création locale
                  await widget.dao.upsertMission(MissionsCompanion.insert(
                    date: dt,
                    vecteur: 'ATR72',
                    pilote1: chosenP1,
                    pilote2: Value(chosenP2),
                    destinationCode: chosenDest,
                    description: Value(remarkCtrl.text.trim()),
                  ));
                } else {
                  // ✏️ Modification
                  await widget.dao.upsertMission(mission.copyWith(
                    date: dt,
                    pilote1: chosenP1,
                    pilote2: Value(chosenP2),
                    destinationCode: chosenDest,
                    description: Value(remarkCtrl.text.trim()),
                  ).toCompanion(true));
                }

                // 🔄 Sync Firestore
                await widget.dao.syncPendingMissions();

                if (mounted) {
                  Navigator.of(ctx2).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(mission == null
                          ? "✅ Mission créée et synchronisée"
                          : "✅ Mission modifiée et synchronisée"),
                    ),
                  );
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );

    // Force un refresh après fermeture
    _refreshData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions Hebdo (Avion)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Synchroniser maintenant",
            onPressed: () async {
              debugPrint('DEBUG MissionsAvion.syncButton: start');
              await widget.dao.syncPendingMissions();
              debugPrint('DEBUG MissionsAvion.syncButton: done, call _refreshData');
              _refreshData();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🔄 Synchronisation manuelle effectuée"),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.missions.isEmpty) {
            return const Center(child: Text('Aucune mission avion'));
          }
          return ListView.builder(
            itemCount: data.missions.length,
            itemBuilder: (_, i) {
              final m = data.missions[i];
              return ListTile(
                leading: Icon(
                  m.isSynced ? Icons.check_circle : Icons.sync_problem,
                  color: m.isSynced ? Colors.green : Colors.orange,
                ),
                title: Text(
                  '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}  ${m.vecteur}',
                ),
                subtitle: Text(
                  '${DateFormat('HH:mm').format(m.date)} • '
                      '${m.pilote1}/${m.pilote2} → ${m.destinationCode}'
                      '${m.description != null ? ' – ${m.description}' : ''}',
                ),
                onLongPress: data.isChef ? () => _showMissionDialog(mission: m) : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          final show = snap.connectionState == ConnectionState.done &&
              (snap.data?.isChef ?? false);
          if (!show) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _showMissionDialog(),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
