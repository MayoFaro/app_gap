// lib/screens/home_screen.dart
import 'package:flutter/material.dart' hide Notification;
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/planning_dao.dart';
import '../data/chef_message_dao.dart';
import '../data/notification_dao.dart';

import 'home_dashboard.dart';
import 'missions_list.dart';
import 'vol_en_cours_list.dart';
import 'planning_list.dart';
import 'tours_de_garde_screen.dart';
import 'organigramme_list.dart';
import 'tripfuel_screen.dart';
import 'meteo_screen.dart';
import 'notifications_screen.dart';
import 'chef_messages_list.dart';
import 'auth_screen.dart'; // <— On importe AuthScreen pour la navigation après déconnexion

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final bool isAdmin;

  const HomeScreen({Key? key, required this.db, this.isAdmin = false}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MissionDao _missionDao;
  late final PlanningDao _planningDao;
  late final ChefMessageDao _chefDao;
  late final NotificationDao _notificationDao;

  String _userGroup = '';
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _missionDao = MissionDao(widget.db);
    _planningDao = PlanningDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);
    _notificationDao = NotificationDao(widget.db);

    // Charger le groupe utilisateur à partir des SharedPreferences
    SharedPreferences.getInstance().then((prefs) async {
      final trig = prefs.getString('userTrigram');
      if (trig != null) {
        final user = await (widget.db.select(widget.db.users)
          ..where((u) => u.trigramme.equals(trig)))
            .getSingle();
        setState(() {
          _userGroup = user.group;
        });
      }
    });

    _pages = [
      HomeDashboard(db: widget.db),
      MissionsList(dao: _missionDao),
      VolEnCoursList(dao: _missionDao, group: _userGroup.isNotEmpty ? _userGroup : 'avion'),
      PlanningList(dao: _planningDao),
      ToursDeGardeScreen(db: widget.db, isAdmin: widget.isAdmin),
      OrganigrammeList(db: widget.db),
      TripFuelScreen(db: widget.db),
      MeteoScreen(),
    ];
  }

  void _onItemTapped(int index) {
    Navigator.of(context).pop(); // ferme le drawer
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final groupKey = _userGroup.isNotEmpty ? _userGroup : 'avion';
    return Scaffold(
      appBar: AppBar(
        title: const Text('appGAP'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Opérations', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Accueil'),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Missions Hebdo'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.flight),
              title: const Text('Vols du jour'),
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.local_gas_station),
              title: const Text('Calcul Carburant'),
              onTap: () => _onItemTapped(6),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Test Notification'),
              onTap: () async {
                final grp = groupKey;
                try {
                  await _notificationDao.insertNotification(
                    NotificationsCompanion.insert(
                      group: grp,
                      type: 'test_event',
                      originator: 'SYS',
                      payload: Value('Notification de test'),
                      timestamp: DateTime.now(),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notification ajoutée pour $grp')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: StreamBuilder<List<Notification>>(
                stream: _notificationDao.watchForGroup(groupKey),
                builder: (ctx, snap) {
                  final unread = (snap.data ?? []).where((n) => !n.isRead).length;
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(Icons.notifications),
                      if (unread > 0)
                        Positioned(
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(dao: _notificationDao, group: groupKey),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Administratif', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Messages du Chef'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChefMessagesList(dao: _chefDao)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Planning Annuel'),
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.shield),
              title: const Text('Tours de Garde'),
              onTap: () => _onItemTapped(4),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Organigramme'),
              onTap: () => _onItemTapped(5),
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('Météo'),
              onTap: () => _onItemTapped(7),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Se déconnecter'),
              onTap: () async {
                // On supprime le trigramme en session et on revient à l'écran d'authentification
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('userTrigram');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
