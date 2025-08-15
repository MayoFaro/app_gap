import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/destinations.dart';

/// Contient la liste + droit d’édition
class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

/// Écran des missions hebdo (AVION).
/// `canEdit` est fourni par HomeScreen (fiable) — on ne lit plus la fonction depuis les prefs ici.
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
    // Avion uniquement
    final filtered = all
        .where((m) => m.vecteur == 'ATR72')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final data = _MissionsData(missions: filtered, isChef: widget.canEdit);
    debugPrint('DEBUG MissionsList._loadData: isChef=${data.isChef}, count=${data.missions.length}');
    return data;
  }

  /// Dialogue d’ajout / édition
  Future<void> _showMissionDialog({Mission? mission}) async {
    // Destinations avion: liste `destinations` déjà existante
    final users = await widget.dao.attachedDatabase.select(widget.dao.attachedDatabase.users).get();
    final pilotes = users
        .where((u) => u.role.toLowerCase() == 'pilote' && u.group.toLowerCase() == 'avion')
        .map((u) => u.trigramme)
        .toList();

    const defaultVecteur = 'ATR72';

    // borne à aujourd’hui
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);

    // valeurs initiales
    DateTime chosenDate = mission?.date ?? minDate;
    if (chosenDate.isBefore(minDate)) chosenDate = minDate;

    String chosenDest = mission?.destinationCode
        ?? (destinations.contains('FOON') ? 'FOON' : destinations.first);

    String chosenTime = mission != null
        ? DateFormat('HH:mm').format(mission.date)
        : '08:30';

    String chosenP1 = mission?.pilote1 ?? (pilotes.isNotEmpty ? pilotes.first : '');
    String chosenP2 = mission?.pilote2 ?? (pilotes.length > 1 ? pilotes[1] : chosenP1);
    final remarkCtrl = TextEditingController(text: mission?.description ?? '');

    // heures par pas de 30 min
    final times = List.generate(48, (i) {
      final h = i ~/ 2;
      final m = (i % 2) * 30;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    });

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateInner) {
            return AlertDialog(
              title: Text(mission == null ? 'Ajouter mission' : 'Modifier mission'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: chosenDate.isAfter(minDate)
                              ? () => setStateInner(() => chosenDate = chosenDate.subtract(const Duration(days: 1)))
                              : null,
                        ),
                        Text(DateFormat('dd/MM/yyyy').format(chosenDate)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setStateInner(() => chosenDate = chosenDate.add(const Duration(days: 1))),
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
                        onSelectedItemChanged: (i) => setStateInner(() => chosenDest = destinations[i]),
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
                        onSelectedItemChanged: (i) => setStateInner(() => chosenTime = times[i]),
                        children: times.map((t) => Center(child: Text(t))).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Pilotes
                    const Text('Pilote 1'),
                    SizedBox(
                      height: 80,
                      child: CupertinoPicker(
                        looping: true,
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: pilotes.indexOf(chosenP1),
                        ),
                        onSelectedItemChanged: (i) => setStateInner(() => chosenP1 = pilotes[i]),
                        children: pilotes.map((p) => Center(child: Text(p))).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text('Pilote 2'),
                    SizedBox(
                      height: 80,
                      child: CupertinoPicker(
                        looping: true,
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: pilotes.indexOf(chosenP2),
                        ),
                        onSelectedItemChanged: (i) => setStateInner(() => chosenP2 = pilotes[i]),
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
                        vecteur: defaultVecteur,
                        pilote1: chosenP1,
                        pilote2: Value(chosenP2),
                        destinationCode: chosenDest,
                        description: Value(remarkCtrl.text.trim()),
                      ));
                    } else {
                      await widget.dao.updateMission(mission.copyWith(
                        date: dt,
                        vecteur: defaultVecteur,
                        pilote1: chosenP1,
                        pilote2: Value(chosenP2),
                        destinationCode: chosenDest,
                        description: Value(remarkCtrl.text.trim()),
                      ));
                    }
                    Navigator.of(ctx2).pop();
                  },
                  child: Text(mission == null ? 'Valider' : 'Modifier'),
                ),
              ],
            );
          },
        );
      },
    );

    // après fermeture, recharger la liste
    _refreshData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missions Hebdo (Avion)')),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (context, snap) {
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
              return GestureDetector(
                onLongPress: data.isChef ? () => _showMissionDialog(mission: m) : null,
                child: ListTile(
                  title: Text(DateFormat('dd/MM').format(m.date)),
                  subtitle: Text(
                    '${DateFormat('HH:mm').format(m.date)} • '
                        '${m.pilote1}${m.pilote2 != null ? '/${m.pilote2}' : ''} → '
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
        builder: (context, snap) {
          // On se base sur le canEdit passé par Home (à l’intérieur du snapshot)
          final show = snap.connectionState == ConnectionState.done && (snap.data?.isChef ?? false);
          debugPrint('DEBUG MissionsList.FAB: state=${snap.connectionState}, isChef=${snap.data?.isChef}');
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
