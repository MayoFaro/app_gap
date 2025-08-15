import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';

/// Destinations hélico (+ "--" pour laisser vide)
const List<String> helicoDestinations = ['--', 'FOGK', 'FOGR', 'FOOL', 'FOON', 'FOOG', 'FOGO'];

class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

/// Écran des missions hebdo (HÉLICO).
/// `canEdit` est injecté depuis HomeScreen (on ne lit plus les prefs ici).
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

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _dataFuture = _loadData();
  }

  Future<_MissionsData> _loadData() async {
    final all = await widget.dao.getAllMissions();
    const helicoVec = ['AH175', 'EC225'];
    final filtered = all
        .where((m) => helicoVec.contains(m.vecteur))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final data = _MissionsData(missions: filtered, isChef: widget.canEdit);
    debugPrint('DEBUG MissionsHelico._loadData: isChef=${data.isChef}, count=${data.missions.length}');
    return data;
  }

  Future<void> _showMissionDialog({Mission? mission}) async {
    // Équipages: p1 = pilote hélico ; p2/p3 = pilote|mecano hélico
    final allUsers = await widget.dao.attachedDatabase
        .select(widget.dao.attachedDatabase.users)
        .get();

    final pilotes1 = ['--'] +
        allUsers
            .where((u) => u.role.toLowerCase() == 'pilote' && u.group.toLowerCase() == 'helico')
            .map((u) => u.trigramme)
            .toList();

    final pilotes23 = ['--'] +
        allUsers
            .where((u) =>
        u.group.toLowerCase() == 'helico' &&
            (u.role.toLowerCase() == 'pilote' || u.role.toLowerCase() == 'mecano'))
            .map((u) => u.trigramme)
            .toList();

    // Vecteur au choix
    const vecteurs = ['AH175', 'EC225'];
    String chosenVect = mission?.vecteur ?? vecteurs.first;

    // borne à aujourd’hui
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);
    DateTime chosenDate = mission?.date ?? minDate;
    if (chosenDate.isBefore(minDate)) chosenDate = minDate;

    // Destination & heure
    String chosenDest = mission?.destinationCode ?? helicoDestinations.first;
    String chosenTime = mission != null ? DateFormat('HH:mm').format(mission.date) : '08:30';

    // Pilotes initiaux
    String p1 = mission?.pilote1 ?? pilotes1.first;
    String p2 = mission?.pilote2 ?? pilotes23.first;
    String p3 = mission?.pilote3 ?? pilotes23.first;

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
        builder: (ctx2, setSt) => AlertDialog(
          title: Text(mission == null ? 'Ajouter vol hélico' : 'Modifier vol hélico'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appareil
                const Text('Appareil'),
                SizedBox(
                  height: 50,
                  child: CupertinoSegmentedControl<String>(
                    groupValue: chosenVect,
                    children: {
                      for (var v in vecteurs)
                        v: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          child: Text(v),
                        )
                    },
                    onValueChanged: (v) => setSt(() => chosenVect = v),
                  ),
                ),
                const SizedBox(height: 8),

                // Date (flèches ±1 jour)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: chosenDate.isAfter(minDate)
                          ? () => setSt(() => chosenDate = chosenDate.subtract(const Duration(days: 1)))
                          : null,
                    ),
                    Text(DateFormat('dd/MM/yyyy').format(chosenDate)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setSt(() => chosenDate = chosenDate.add(const Duration(days: 1))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Destination
                const Text('Destination'),
                SizedBox(
                  height: 60,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 24,
                    scrollController: FixedExtentScrollController(
                      initialItem: helicoDestinations.indexOf(chosenDest),
                    ),
                    onSelectedItemChanged: (i) => setSt(() => chosenDest = helicoDestinations[i]),
                    children: helicoDestinations.map((d) => Center(child: Text(d))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Heure
                const Text('Heure'),
                SizedBox(
                  height: 60,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 24,
                    scrollController: FixedExtentScrollController(initialItem: times.indexOf(chosenTime)),
                    onSelectedItemChanged: (i) => setSt(() => chosenTime = times[i]),
                    children: times.map((t) => Center(child: Text(t))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Pilote 1
                const Text('Pil1'),
                SizedBox(
                  height: 60,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 24,
                    scrollController: FixedExtentScrollController(initialItem: pilotes1.indexOf(p1)),
                    onSelectedItemChanged: (i) => setSt(() => p1 = pilotes1[i]),
                    children: pilotes1.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Pilote 2
                const Text('Pil2'),
                SizedBox(
                  height: 60,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 24,
                    scrollController: FixedExtentScrollController(initialItem: pilotes23.indexOf(p2)),
                    onSelectedItemChanged: (i) => setSt(() => p2 = pilotes23[i]),
                    children: pilotes23.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Pilote 3
                const Text('Pil3'),
                SizedBox(
                  height: 60,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 24,
                    scrollController: FixedExtentScrollController(initialItem: pilotes23.indexOf(p3)),
                    onSelectedItemChanged: (i) => setSt(() => p3 = pilotes23[i]),
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
            TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Annuler')),
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
                  await widget.dao.insertMission(MissionsCompanion.insert(
                    date: dt,
                    vecteur: chosenVect,
                    pilote1: p1,
                    pilote2: Value(p2),
                    pilote3: Value(p3),
                    destinationCode: chosenDest,
                    description: Value(remarkCtrl.text.trim()),
                  ));
                } else {
                  await widget.dao.updateMission(mission.copyWith(
                    date: dt,
                    vecteur: chosenVect,
                    pilote1: p1,
                    pilote2: Value(p2),
                    pilote3: Value(p3),
                    destinationCode: chosenDest,
                    description: Value(remarkCtrl.text.trim()),
                  ));
                }
                Navigator.of(ctx2).pop();
              },
              child: Text(mission == null ? 'Valider' : 'Modifier'),
            ),
          ],
        ),
      ),
    );

    // après fermeture, recharger la liste
    _refreshData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missions Hebdo (Hélico)')),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.missions.isEmpty) {
            return const Center(child: Text('Aucune mission hélico'));
          }
          return ListView.builder(
            itemCount: data.missions.length,
            itemBuilder: (_, i) {
              final m = data.missions[i];
              return GestureDetector(
                onLongPress: data.isChef ? () => _showMissionDialog(mission: m) : null,
                child: ListTile(
                  title: Text(
                    '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}  ${m.vecteur}',
                  ),
                  subtitle: Text(
                    '${DateFormat('HH:mm').format(m.date)} • '
                        '${m.pilote1}/${m.pilote2}/${m.pilote3} → '
                        '${m.destinationCode}'
                        '${m.description != null ? ' – ${m.description}' : ''}',
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          final show = snap.connectionState == ConnectionState.done && (snap.data?.isChef ?? false);
          debugPrint('DEBUG MissionsHelico.FAB: state=${snap.connectionState}, isChef=${snap.data?.isChef}');
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
