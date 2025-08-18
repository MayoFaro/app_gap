// lib/screens/vol_en_cours_list.dart
import 'package:flutter/material.dart';
import '../data/mission_dao.dart';
import '../data/app_database.dart';

class VolEnCoursList extends StatefulWidget {
  final MissionDao dao;
  /// 'avion' | 'helico'
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
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final isAvion = widget.group.toLowerCase() == 'avion';
      const heliVectors = ['AH175', 'EC225'];

      final filtered = all.where((m) {
        final inToday = m.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            m.date.isBefore(end);
        final okGroup = isAvion ? (m.vecteur == 'ATR72')
            : heliVectors.contains(m.vecteur);
        return inToday && okGroup;
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      debugPrint('DEBUG VolEnCours: loaded ${filtered.length} vols for group=${widget.group}');
      return filtered;
    });
  }

  Future<void> _markDeparture(Mission m) async {
    debugPrint('DEBUG VolEnCours: mark DEP id=${m.id}');
    // soit juste: await widget.dao.setActualDeparture(m.id);
    await widget.dao.setActualDeparture(m.id,); //The method 'setActualDeparture' isn't defined for the type 'MissionDao'.
    _loadMissions();
    setState(() {});
  }

  Future<void> _markArrival(Mission m) async {
    debugPrint('DEBUG VolEnCours: mark ARR id=${m.id}');
    // soit juste: await widget.dao.setActualArrival(m.id);
    await widget.dao.setActualArrival(m.id, ); //The method 'setActualArrival' isn't defined for the type 'MissionDao'.
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
          final list = snapshot.data ?? const <Mission>[];
          if (list.isEmpty) {
            return const Center(child: Text("Aucun vol aujourd'hui"));
          }
          return RefreshIndicator(
            onRefresh: () async {
              debugPrint('DEBUG VolEnCours: pull-to-refresh');
              _loadMissions();
              setState(() {});
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = list[i];
                final hhmm = m.date.toLocal().toIso8601String().split('T')[1].substring(0, 5);
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$hhmm - ${m.vecteur}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Dest: ${m.destinationCode}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (m.actualDeparture == null)
                              ElevatedButton(
                                onPressed: () => _markDeparture(m),
                                child: const Text('Décollage'),
                              )
                            else
                              Text('Décollé: ${m.actualDeparture!.toLocal().toIso8601String().split('T')[1].substring(0,5)}'),
                            const SizedBox(width: 12),
                            if (m.actualArrival == null)
                              ElevatedButton(
                                onPressed: () => _markArrival(m),
                                child: const Text('Atterrissage'),
                              )
                            else
                              Text('Atterri: ${m.actualArrival!.toLocal().toIso8601String().split('T')[1].substring(0,5)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
