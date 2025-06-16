import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import '../data/app_database.dart';
import '../data/mission_dao.dart';

/// Écran des missions hebdo pour le groupe hélico
class MissionsHelicoList extends StatefulWidget {
  final MissionDao dao;
  const MissionsHelicoList({Key? key, required this.dao}) : super(key: key);

  @override
  State<MissionsHelicoList> createState() => _MissionsHelicoListState();
}

class _MissionsHelicoListState extends State<MissionsHelicoList> {
  late List<String> _pilots;      // Trigrammes 'pilote' + 'helico'
  late List<String> _crew;        // Trigrammes ('pilote'|'mecano') + helico
  late Future<List<Mission>> _missionsFuture;
  bool _isChef = false;
  bool _isReady = false;

  static const List<String> _vectors = ['AH175', 'EC225'];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final fonction = prefs.getString('fonction')?.toLowerCase();
    _isChef = fonction == 'chef';
    debugPrint('DEBUG MissionsHelicoList._initialize: fonction=$fonction, isChef=$_isChef');

    final users = await widget.dao.attachedDatabase.select(widget.dao.attachedDatabase.users).get();
    _pilots = users
        .where((u) => u.fonction.toLowerCase() == 'pilote' && u.group.toLowerCase() == 'helico')
        .map((u) => u.trigramme)
        .toList();
    _crew = users
        .where((u) {
      final fn = u.fonction.toLowerCase();
      return (fn == 'pilote' || fn == 'mecano') && u.group.toLowerCase() == 'helico';
    })
        .map((u) => u.trigramme)
        .toList();

    _loadMissions();
    setState(() => _isReady = true);
  }

  void _loadMissions() {
    _missionsFuture = widget.dao.getAllMissions().then((all) {
      final filtered = all.where((m) => _vectors.contains(m.vecteur)).toList();
      filtered.sort((a, b) => a.date.compareTo(b.date));
      debugPrint('DEBUG MissionsHelicoList._loadMissions: found ${filtered.length} helico missions');
      return filtered;
    });
  }

  Future<void> _showMissionDialog([Mission? mission]) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);

    // Initial values
    DateTime chosenDate = mission?.date ?? minDate;
    if (chosenDate.isBefore(minDate)) chosenDate = minDate;
    String chosenVector = mission?.vecteur ?? _vectors.first;
    String chosenDest = mission?.destinationCode ?? 'FOGK';
    String chosenTime = mission != null
        ? DateFormat('HH:mm').format(mission.date)
        : '08:30';
    String chosenP1 = mission?.pilote1 ?? (_pilots.isNotEmpty ? _pilots.first : '');
    String chosenP2 = mission?.pilote2 ?? (_crew.length > 1 ? _crew[1] : chosenP1);
    String chosenP3 = _crew.length > 2 ? _crew[2] : chosenP1;
    final remarkCtrl = TextEditingController(text: mission?.description ?? '');

    final times = List.generate(48, (i) {
      final h = i ~/ 2;
      final m = (i % 2) * 30;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    });

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateInner) {
          return AlertDialog(
            title: Text(mission == null ? 'Ajouter mission Héli' : 'Modifier mission Héli'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Appareil'),
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: _vectors.map((v) {
                        final sel = v == chosenVector;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setStateInner(() => chosenVector = v),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: sel ? Colors.blue : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(v, style: TextStyle(color: sel ? Colors.white : Colors.black)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const Text('Destination'),
                  SizedBox(
                    height: 80,
                    child: CupertinoPicker(
                      looping: true,
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: 0),
                      onSelectedItemChanged: (i) => setStateInner(() => chosenDest = ['FOGK','FOGR','FOOL','FOON','FOOG','FOGO'][i]),
                      children: ['FOGK','FOGR','FOOL','FOON','FOOG','FOGO'].map((d) => Center(child: Text(d))).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Heure'),
                  SizedBox(
                    height: 80,
                    child: CupertinoPicker(
                      looping: true,
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: times.indexOf(chosenTime)),
                      onSelectedItemChanged: (i) => setStateInner(() => chosenTime = times[i]),
                      children: times.map((t) => Center(child: Text(t))).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var idx = 1; idx <= 3; idx++) ...[
                    Text('Pilote ${idx}'),
                    SizedBox(
                      height: 80,
                      child: CupertinoPicker(
                        looping: true,
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(initialItem: idx == 1
                            ? _pilots.indexOf(chosenP1)
                            : (idx == 2 ? _crew.indexOf(chosenP2) : _crew.indexOf(chosenP3))),
                        onSelectedItemChanged: (i) => setStateInner(() {
                          if (idx == 1) chosenP1 = _pilots[i];
                          else if (idx == 2) chosenP2 = _crew[i];
                          else chosenP3 = _crew[i];
                        }),
                        children: (idx == 1 ? _pilots : _crew).map((p) => Center(child: Text(p))).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                      vecteur: chosenVector,
                      pilote1: chosenP1,
                      pilote2: Value(chosenP2),
                      destinationCode: chosenDest,
                      description: Value(remarkCtrl.text.trim()),
                    ));
                  } else {
                    await widget.dao.updateMission(mission.copyWith(
                      date: dt,
                      vecteur: chosenVector,
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
      ),
    );
    _loadMissions();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Missions Hebdo Hélico')),
      body: FutureBuilder<List<Mission>>(
        future: _missionsFuture,
        builder: (ctx, msnap) {
          if (msnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = msnap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Aucune mission hélico'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              return GestureDetector(
                onLongPress: _isChef ? () => _showMissionDialog(m) : null,
                child: ListTile(
                  title: Text(
                    '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')} '  '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}',
                  ),
                  subtitle: Text(
                    '${m.pilote1}/${m.pilote2}/${m.pilote2}/${m.description ?? ''}',
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _isChef
          ? FloatingActionButton(
        onPressed: () {
          debugPrint('DEBUG MissionsHelicoList: + button pressed (isChef=$_isChef)');
          _showMissionDialog();
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
