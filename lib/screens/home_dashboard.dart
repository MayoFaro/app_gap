import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/chef_message_dao.dart';

/// Écran d'accueil avec prochaines missions et derniers messages du chef
class HomeDashboard extends StatefulWidget {
  final AppDatabase db;
  const HomeDashboard({Key? key, required this.db}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late final MissionDao _missionDao;
  late final ChefMessageDao _chefDao;

  late Future<List<Mission>> _nextMissions;
  late Future<ChefMessage?> _latestMessage;

  @override
  void initState() {
    super.initState();
    _missionDao = MissionDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);
    _loadData();
  }

  /// Recharge les prochaines missions et le dernier message
  void _loadData() {
    final now = DateTime.now();
    _nextMissions = _missionDao.getAllMissions().then((all) {
      final upcoming = all
          .where((m) => m.date.isAfter(now) || m.date.isAtSameMomentAs(now))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return upcoming.take(5).toList();
    });

    _latestMessage = _chefDao.getAllMessages().then((list) {
      if (list.isEmpty) return null;
      // Messages triés par timestamp décroissant dans DAO
      return list.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadData();
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prochaines missions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              FutureBuilder<List<Mission>>(
                future: _nextMissions,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final missions = snap.data!;
                  if (missions.isEmpty) {
                    return const Text('Aucune mission prochaine');
                  }
                  return Column(
                    children: missions.map((m) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.flight),
                        title: Text('${m.date.toLocal()}'.split('.').first),
                        subtitle: Text('${m.vecteur} → ${m.destinationCode}'),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(height: 32),
              const Text('Message du Chef', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              FutureBuilder<ChefMessage?>(
                future: _latestMessage,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final msg = snap.data;
                  if (msg == null) {
                    return const Text('Aucun message');
                  }
                  return Card(
                    child: ListTile(
                      title: Text(msg.content ?? ''),
                      subtitle: Text('${msg.timestamp.toLocal()}'.split('.').first),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
