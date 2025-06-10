// lib/screens/missions_list.dart
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';

class MissionsList extends StatelessWidget {
  final MissionDao dao;
  const MissionsList({super.key, required this.dao});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missions Hebdo')),
      body: FutureBuilder<List<Mission>>(
        future: dao.getAllMissions(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              return ListTile(
                title: Text(
                  '${m.date.toLocal().toIso8601String().split("T").first}  ${m.vecteur}',
                ),
                subtitle: Text(
                  '${m.pilote1}${m.pilote2 != null ? "/\${m.pilote2}" : ""} → ${m.destinationCode}',
                ),
                onTap: () {
                  // TODO: naviguer vers l’édition si autorisé
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: ajouter une nouvelle mission si autorisé
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
