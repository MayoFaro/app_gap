// lib/screens/vol_en_cours_list.dart
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column; // pour Value, évite le conflit avec Flutter Column // pour Value
import '../data/mission_dao.dart';
import '../data/app_database.dart';

class VolEnCoursList extends StatefulWidget {
  final MissionDao dao;
  final String group;

  const VolEnCoursList({super.key, required this.dao, required this.group});

  @override
  State<VolEnCoursList> createState() => _VolEnCoursListState();
}

class _VolEnCoursListState extends State<VolEnCoursList> {
  late Future<List<Mission>> _futureMissions;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  void _loadMissions() {
    _futureMissions = widget.dao.getAllMissions().then((all) {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final end = start.add(const Duration(days: 1));
      return all.where((m) {
        return m.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            m.date.isBefore(end) &&
            m.vecteur == widget.group;
      }).toList();
    });
  }

  Future<void> _markDeparture(Mission m) async {
    await (widget.dao.update(widget.dao.missions)
      ..where((tbl) => tbl.id.equals(m.id)))
        .write(MissionsCompanion(actualDeparture: Value(DateTime.now()))); //The named parameter 'actualDeparture' isn't defined.
    _loadMissions();
    setState(() {});
  }

  Future<void> _markArrival(Mission m) async {
    await (widget.dao.update(widget.dao.missions)
      ..where((tbl) => tbl.id.equals(m.id)))
        .write(MissionsCompanion(actualArrival: Value(DateTime.now()))); //The named parameter 'actualArrival' isn't defined.
    _loadMissions();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vols du jour')),
      body: FutureBuilder<List<Mission>>(
        future: _futureMissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text("Aucun vol aujourd'hui"));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m.date.toLocal().toIso8601String().split('T')[1].substring(0,5)} - ${m.vecteur}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Dest: ${m.destinationCode}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (m.actualDeparture == null)
                            ElevatedButton(
                                onPressed: () => _markDeparture(m),
                                child: const Text('Décollage'))
                          else
                            Text(
                              'Décollé: ${m.actualDeparture!.toLocal().toIso8601String().split('T')[1].substring(0,5)}',
                            ),
                          const SizedBox(width: 12),
                          if (m.actualArrival == null)
                            ElevatedButton(
                                onPressed: () => _markArrival(m),
                                child: const Text('Atterrissage'))
                          else if (m.actualArrival != null)
                            Text(
                              'Atterri: ${m.actualArrival!.toLocal().toIso8601String().split('T')[1].substring(0,5)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
