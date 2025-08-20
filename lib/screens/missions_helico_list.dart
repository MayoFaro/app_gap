// lib/screens/missions_helico_list.dart
import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';

const List<String> helicoDestinations = [
  '--', 'FOGK', 'FOGR', 'FOOL', 'FOON', 'FOOG', 'FOGO'
];

class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

class MissionsHelicoList extends StatefulWidget {
  final MissionDao dao;
  final bool canEdit;

  const MissionsHelicoList({
    Key? key,
    required this.dao,
    required this.canEdit,
  }) : super(key: key);

  @override
  State<MissionsHelicoList> createState() => _MissionsHelicoListState();
}

class _MissionsHelicoListState extends State<MissionsHelicoList> {
  late Future<_MissionsData> _dataFuture;

  // 🔔 Abonnement aux changements Drift pour recharger automatiquement
  StreamSubscription<List<Mission>>? _missionSub;

  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG MissionsHelico.initState');
    _refreshData();

    // On écoute la table missions (sans filtre de date → utile pour capter tous les changements).
    final db = widget.dao.attachedDatabase;
    final stream = (db.select(db.missions)
      ..where((m) => m.vecteur.equals('AH175') | m.vecteur.equals('EC225')))
        .watch();

    _missionSub = stream.listen((rows) {
      debugPrint(
        'DEBUG MissionsHelico.stream: changement local détecté (rows=${rows.length}) -> _refreshData()',
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
    debugPrint('DEBUG MissionsHelico._loadData: total local=${all.length}');

    const helicoVec = ['AH175', 'EC225'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ➡️ Filtrage hélico + date >= aujourd’hui
    final filtered = all
        .where((m) => helicoVec.contains(m.vecteur) && !m.date.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final data = _MissionsData(missions: filtered, isChef: widget.canEdit);
    debugPrint(
      'DEBUG MissionsHelico._loadData: isChef=${data.isChef}, filtered=${data.missions.length}',
    );
    return data;
  }

  Future<void> _showMissionDialog({Mission? mission}) async {
    final allUsers = await widget.dao.attachedDatabase.users.select().get();

    // Pilotes hélico (P1 = pilotes, P2/P3 = pilotes ou mécanos)
    final pilotes1 = ['--'] +
        allUsers
            .where((u) =>
        u.role.toLowerCase() == 'pilote' &&
            u.group.toLowerCase() == 'helico')
            .map((u) => u.trigramme)
            .toList();

    final pilotes23 = ['--'] +
        allUsers
            .where((u) {
          final r = u.role.toLowerCase();
          final g = u.group.toLowerCase();
          return g == 'helico' && (r == 'pilote' || r == 'mecano');
        })
            .map((u) => u.trigramme)
            .toList();

    // borne à aujourd’hui
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);
    DateTime chosenDate = mission?.date ?? minDate;
    if (chosenDate.isBefore(minDate)) chosenDate = minDate;

    // Vecteurs hélico
    const vecteurs = ['AH175', 'EC225'];
    String chosenVect = mission?.vecteur ?? vecteurs.first;

    // Destination & heure
    String chosenDest = mission?.destinationCode ?? helicoDestinations.first;
    String chosenTime =
    mission != null ? DateFormat('HH:mm').format(mission.date) : '08:30';

    // Pilotes initiaux
    String chosenP1 = mission?.pilote1 ?? pilotes1.first;
    String chosenP2 = mission?.pilote2 ?? pilotes23.first;
    String chosenP3 = mission?.pilote3 ?? pilotes23.first;

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
            mission == null ? 'Ajouter mission hélico' : 'Modifier mission hélico',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vecteur hélico
                const Text('Appareil'),
                CupertinoSegmentedControl<String>(
                  groupValue: chosenVect,
                  children: {
                    for (var v in vecteurs)
                      v: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(v),
                      ),
                  },
                  onValueChanged: (v) => setStateInner(() => chosenVect = v),
                ),
                const SizedBox(height: 8),

                // Date
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
                      initialItem: helicoDestinations.indexOf(chosenDest),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenDest = helicoDestinations[i]),
                    children: helicoDestinations
                        .map((d) => Center(child: Text(d)))
                        .toList(),
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
                      initialItem: pilotes1.indexOf(chosenP1),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenP1 = pilotes1[i]),
                    children: pilotes1.map((p) => Center(child: Text(p))).toList(),
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
                      initialItem: pilotes23.indexOf(chosenP2),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenP2 = pilotes23[i]),
                    children: pilotes23.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Pilote 3
                const Text('Pilote 3'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: pilotes23.indexOf(chosenP3),
                    ),
                    onSelectedItemChanged: (i) =>
                        setStateInner(() => chosenP3 = pilotes23[i]),
                    children: pilotes23.map((p) => Center(child: Text(p))).toList(),
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
              child: const Text('Annuler'),
            ),
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
                  await widget.dao.upsertMission(MissionsCompanion.insert(
                    date: dt,
                    vecteur: chosenVect,
                    pilote1: chosenP1,
                    pilote2: Value(chosenP2),
                    pilote3: Value(chosenP3),
                    destinationCode: chosenDest,
                    description: Value(remarkCtrl.text.trim()),
                  ));
                } else {
                  await widget.dao.upsertMission(mission.copyWith(
                    date: dt,
                    vecteur: chosenVect,
                    pilote1: chosenP1,
                    pilote2: Value(chosenP2),
                    pilote3: Value(chosenP3),
                    destinationCode: chosenDest,
                    description: Value(remarkCtrl.text.trim()),
                  ).toCompanion(true));
                }

                await widget.dao.syncPendingMissions();

                if (mounted) {
                  Navigator.of(ctx2).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(mission == null
                          ? "✅ Mission hélico créée et synchronisée"
                          : "✅ Mission hélico modifiée et synchronisée"),
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

    _refreshData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions Hebdo (Hélico)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Synchroniser maintenant",
            onPressed: () async {
              await widget.dao.syncPendingMissions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🔄 Synchronisation manuelle effectuée")),
                );
              }
              _refreshData();
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          if (data.missions.isEmpty) return const Center(child: Text('Aucune mission hélico'));
          return ListView.builder(
            itemCount: data.missions.length,
            itemBuilder: (_, i) {
              final m = data.missions[i];
              return ListTile(
                leading: Icon(
                  m.isSynced ? Icons.check_circle : Icons.sync_problem,
                  color: m.isSynced ? Colors.green : Colors.orange,
                ),
                title: Text('${DateFormat('dd/MM').format(m.date)}  ${m.vecteur}'),
                subtitle: Text(
                  '${DateFormat('HH:mm').format(m.date)} • ${m.pilote1}/${m.pilote2}/${m.pilote3} → ${m.destinationCode}'
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
          if (snap.connectionState != ConnectionState.done || !(snap.data?.isChef ?? false)) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => _showMissionDialog(),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
