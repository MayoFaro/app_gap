// lib/screens/home_dashboard.dart
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/chef_message_dao.dart';

class HomeDashboard extends StatefulWidget {
  final AppDatabase db;
  const HomeDashboard({super.key, required this.db});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late final MissionDao _missionDao;
  late final ChefMessageDao _chefDao;

  Future<List<Mission>>? _nextMissions;
  Future<ChefMessage?>? _latestMessage;

  @override
  void initState() {
    super.initState();
    _missionDao = MissionDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);
    _loadData();
  }

  void _loadData() {
    _nextMissions = _missionDao.getAllMissions().then((all) {
      final now = DateTime.now();
      final futureList = all
          .where((m) => m.date.isAfter(now) || m.date.isAtSameMomentAs(now))
          .toList();
      futureList.sort((a, b) {
        final cmpDate = a.date.compareTo(b.date);
        if (cmpDate != 0) return cmpDate;
        return a.hourStart.compareTo(b.hourStart);
      });
      // On prend désormais les 5 premiers vols (tous vecteurs confondus)
      return futureList.take(5).toList();
    });

    _latestMessage = _chefDao
        .getAllMessages()
        .then((list) => list.isNotEmpty ? list.first : null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Message du Chef
          FutureBuilder<ChefMessage?>(
            future: _latestMessage,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 80, child: Center(child: CircularProgressIndicator()));
              }
              final msg = snap.data;
              if (msg == null) return const SizedBox();
              return Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Message du Chef', style: textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(msg.content ?? '', style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${msg.authorRole.toUpperCase()} • ${msg.group.toUpperCase()}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Prochains vols
          Text('Prochains vols', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Mission>>(
            future: _nextMissions,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) return const Text('Pas d’activité prévue');
              return Column(
                children: list.map((m) {
                  final date = m.date.toLocal().toIso8601String().split('T').first;
                  return ListTile(
                    leading: const Icon(Icons.flight_takeoff),
                    title: Text('$date — ${m.vecteur}'),
                    subtitle: Text(
                      '${m.pilote1}${m.pilote2 != null ? '/${m.pilote2}' : ''} → ${m.destinationCode}',
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
