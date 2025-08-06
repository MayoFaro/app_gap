// lib/screens/home_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/chef_message_dao.dart';

/// Dashboard montrant les 5 prochaines missions (avion + hélico) et le dernier message du chef
class HomeDashboard extends StatefulWidget {
  final AppDatabase db;
  final ChefMessageDao chefDao;   // DAO pour gérer les acknowledgements
  final String currentUser;       // Trigramme de l'utilisateur

  const HomeDashboard({
    Key? key,
    required this.db,
    required this.chefDao,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with WidgetsBindingObserver {
  static const _kDismissedKey = 'dismissedChefMessages';
  late final MissionDao _missionDao;
  late final Stream<List<Mission>> _missionsStream;
  late final Future<ChefMessage?> _initFuture;
  Set<int> _dismissed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _missionDao = MissionDao(widget.db);
    _missionsStream = widget.db.select(widget.db.missions).watch();
    _loadDismissed();
    _initFuture = _initializeDashboard();  // pré-chargement des acks et du dernier message
  }

  Future<ChefMessage?> _initializeDashboard() async {
    final msgs = await widget.chefDao.getAllMessages();
    final latest = msgs.isNotEmpty ? msgs.first : null;
    if (latest != null) {
      final acks = await widget.chefDao.getAcks(latest.id);
      if (!acks.any((a) => a.trigramme == widget.currentUser)) {
        await widget.chefDao.acknowledge(latest.id, widget.currentUser);
      }
    }
    return latest;
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDismissedKey) ?? [];
    setState(() => _dismissed = list.map(int.parse).toSet());
  }

  Future<void> _saveDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDismissedKey,
      _dismissed.map((i) => i.toString()).toList(),
    );
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
          // Dernier message du chef avec possibilité de dismiss
          FutureBuilder<ChefMessage?>(
            future: _initFuture,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox();
              }
              final msg = snap.data;
              if (msg == null || _dismissed.contains(msg.id)) {
                return const SizedBox();
              }
              return Dismissible(
                key: ValueKey(msg.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) async {
                  setState(() => _dismissed.add(msg.id));
                  await _saveDismissed();
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.message),
                    title: Text(msg.content ?? ''),
                    subtitle: Text(
                      '${msg.authorRole} • ${msg.group} • ${msg.timestamp.toLocal().toIso8601String().replaceFirst('T', ' ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
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
                final upcomingMissions = allMissions
                    .where((m) => m.date.isAfter(now))
                    .toList()
                  ..sort((a, b) => a.date.compareTo(b.date));
                final display = upcomingMissions.take(5).toList();
                if (display.isEmpty) {
                  return const Center(child: Text('Aucune mission à venir'));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
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
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DateFormat('dd/MM').format(m.date)} '
                                  '${DateFormat('HH:mm').format(m.date)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (m.description != null && m.description!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  m.description!,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
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