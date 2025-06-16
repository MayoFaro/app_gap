import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/chef_message_dao.dart';

/// Dashboard montrant les 5 prochaines missions (avion + hélico) et le dernier message du chef
class HomeDashboard extends StatefulWidget {
  final AppDatabase db;
  const HomeDashboard({Key? key, required this.db}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with WidgetsBindingObserver {
  late final MissionDao _missionDao;
  late final ChefMessageDao _chefDao;
  late final Stream<List<Mission>> _missionsStream;
  Future<ChefMessage?>? _latestMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _missionDao = MissionDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);

    // Abonnement à toutes les missions
    _missionsStream = widget.db.select(widget.db.missions).watch();

    // Charger le dernier message du chef
    _latestMessage = _chefDao.getAllMessages().then(
          (msgs) => msgs.isNotEmpty ? msgs.first : null,
    );

    // Debug: log chaque mise à jour de la liste des missions
    _missionsStream.listen((missions) {
      debugPrint('DEBUG Dashboard[stream]: total missions=${missions.length}');
      final upcomingCount = missions.where((m) => m.date.isAfter(DateTime.now())).length;
      debugPrint('DEBUG Dashboard[stream]: upcoming=$upcomingCount');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        children: [
          // Dernier message du chef
          FutureBuilder<ChefMessage?>(
            future: _latestMessage,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox();
              }
              final msg = snap.data;
              if (msg == null) return const SizedBox();
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.message),
                  title: Text(msg.content ?? ''),
                  subtitle: Text(
                    '${msg.authorRole} • ${msg.group} • '
                        '${msg.timestamp.toLocal().toIso8601String().replaceFirst('T', ' ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          ),
          // Missions à venir
          Expanded(
            child: StreamBuilder<List<Mission>>(
              stream: _missionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allMissions = snapshot.data ?? [];
                final now = DateTime.now();
                // Missions à venir, triées chronologiquement
                final upcomingMissions = allMissions
                    .where((m) => m.date.isAfter(now))
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));
                debugPrint(
                  'DEBUG Dashboard: total avion=${allMissions.where((m) => m.vecteur=="ATR72").length}, '
                      'helico=${allMissions.where((m) => m.vecteur!="ATR72").length}',
                );
                debugPrint('DEBUG Dashboard: upcoming count=${upcomingMissions.length}');

                // Affiche jusqu'à 5 missions à venir
                final display = upcomingMissions.take(5).toList();

                if (display.isEmpty) {
                  return const Center(child: Text('Aucune mission à venir'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    debugPrint('DEBUG Dashboard: manual refresh triggered');
                    setState(() {});
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: display.length,
                    itemBuilder: (context, i) {
                      final m = display[i];
                      return ListTile(
                        leading: FaIcon(
                          m.vecteur == 'ATR72'
                              ? FontAwesomeIcons.plane
                              : FontAwesomeIcons.helicopter,
                        ),
                        title: Text(
                          '${DateFormat('dd/MM').format(m.date)} '
                              '${DateFormat('HH:mm').format(m.date)}',
                        ),
                        subtitle: Text(
                          '${m.pilote1}'
                              '${m.pilote2 != null ? '/${m.pilote2}' : ''}'
                              '${m.pilote3 != null ? '/${m.pilote3}' : ''}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
