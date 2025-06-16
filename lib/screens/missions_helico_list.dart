import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';

/// Data holder for missions and chef status
class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

/// Screen for weekly helicopter missions
class MissionsHelicoList extends StatefulWidget {
  final MissionDao dao;
  const MissionsHelicoList({Key? key, required this.dao}) : super(key: key);

  @override
  State<MissionsHelicoList> createState() => _MissionsHelicoListState();
}

class _MissionsHelicoListState extends State<MissionsHelicoList> {
  late Future<_MissionsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MissionsData> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final fonction = prefs.getString('fonction')?.toLowerCase();
    final all = await widget.dao.getAllMissions();
    final isChef = fonction == 'chef';

    // Only helico vecteurs
    const vecteurs = ['AH175', 'EC225'];
    final filtered = all
        .where((m) => vecteurs.contains(m.vecteur))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return _MissionsData(missions: filtered, isChef: isChef);
  }

  Future<void> _showAddHelicoDialog({Mission? mission}) async {
    // Prepare initial values
    final today = DateTime.now();
    DateTime chosenDate = mission?.date ?? today;
    TimeOfDay chosenTime = mission != null
        ? TimeOfDay(hour: mission.date.hour, minute: mission.date.minute)
        : const TimeOfDay(hour: 8, minute: 30);
    String chosenDest = mission?.destinationCode ?? 'FOGK';

    // Fetch pilots with fonction 'pilote' and group 'helico'
    final users = await widget.dao.attachedDatabase.select(widget.dao.attachedDatabase.users).get();
    final pilots = users
        .where((u) => u.fonction.toLowerCase() == 'pilote' && u.group.toLowerCase() == 'helico')
        .map((u) => u.trigramme)
        .toList();

    String pil1 = mission?.pilote1 ?? (pilots.isNotEmpty ? pilots.first : '');
    String pil2 = mission?.pilote2 ?? (pilots.length > 1 ? pilots[1] : pil1);
    String pil3 = mission?.pilote3 ?? (pilots.length > 2 ? pilots[2] : pil1); //The getter 'pilote3' isn't defined for the type 'Mission'.

    // Show dialog
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateInner) {
          return AlertDialog(
            title: Text(mission == null ? 'Ajouter mission Hélico' : 'Modifier mission Hélico'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column( //'Column' isn't a function.
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          final prev = chosenDate.subtract(const Duration(days: 1));
                          if (!prev.isBefore(today)) setStateInner(() => chosenDate = prev);
                        },
                      ),
                      Text('${chosenDate.day.toString().padLeft(2, '0')}/'
                          '${chosenDate.month.toString().padLeft(2, '0')}'),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setStateInner(
                              () => chosenDate = chosenDate.add(const Duration(days: 1)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Time picker compact
                  SizedBox(
                    height: 100,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: DateTime(
                        chosenDate.year,
                        chosenDate.month,
                        chosenDate.day,
                        chosenTime.hour,
                        chosenTime.minute,
                      ),
                      use24hFormat: true,
                      minuteInterval: 30,
                      onDateTimeChanged: (dt) => setStateInner(() {
                        chosenTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Pilots pickers, compact rows
                  _buildLabelledDropdown('Pil1', pilots, pil1, (v) => setStateInner(() => pil1 = v)),
                  _buildLabelledDropdown('Pil2', pilots, pil2, (v) => setStateInner(() => pil2 = v)),
                  _buildLabelledDropdown('Pil3', pilots, pil3, (v) => setStateInner(() => pil3 = v)),
                  const SizedBox(height: 8),
                  // Destination dropdown
                  _buildLabelledDropdown(
                    'Dest', ['FOGK', 'FOGR', 'FOOL', 'FOON', 'FOOG', 'FOGO'],
                    chosenDest,
                        (v) => setStateInner(() => chosenDest = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final dt = DateTime(
                    chosenDate.year,
                    chosenDate.month,
                    chosenDate.day,
                    chosenTime.hour,
                    chosenTime.minute,
                  );
                  final entry = MissionsCompanion.insert(
                    date: dt,
                    vecteur: mission?.vecteur ?? 'AH175',
                    pilote1: pil1,
                    pilote2: Value(pil2),
                    pilote3: Value(pil3), //The named parameter 'pilote3' isn't defined.
                    destinationCode: chosenDest,
                    description: const Value.absent(),
                  );
                  if (mission == null) {
                    await widget.dao.insertMission(entry);
                  } else {
                    await widget.dao.updateMission(
                      mission.copyWith(
                        date: dt,
                        pilote1: pil1,
                        pilote2: Value(pil2),
                        pilote3: Value(pil3), //The named parameter 'pilote3' isn't defined.
                        destinationCode: chosenDest,
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                  setState(() => _dataFuture = _loadData());
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLabelledDropdown(
      String label,
      List<String> items,
      String value,
      ValueChanged<String> onChanged,
      ) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label)),
        Expanded(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => onChanged(v!),
            itemHeight: 32,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missions Hebdo Hélico')),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.missions.isEmpty) {
            return const Center(child: Text('Aucune mission'));  }
          return ListView.builder(
            itemCount: data.missions.length,
            itemBuilder: (_, i) {
              final m = data.missions[i];
              return ListTile(
                title: Text(
                    '${m.date.day.toString().padLeft(2,'0')}/'
                        '${m.date.month.toString().padLeft(2,'0')} '
                        '${m.date.hour.toString().padLeft(2,'0')}:'
                        '${m.date.minute.toString().padLeft(2,'0')}'
                ),
                subtitle: Text('${m.pilote1}/${m.pilote2}/${m.pilote3} → ${m.destinationCode}'), //The getter 'pilote3' isn't defined for the type 'Mission'.
                onTap: data.isChef
                    ? () => _showAddHelicoDialog(mission: m)
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done || !snap.data!.isChef) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => _showAddHelicoDialog(),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
