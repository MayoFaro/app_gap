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
import 'missions_helico_list.dart';
import 'vol_en_cours_list.dart';
import 'planning_list.dart';
import 'tours_de_garde_screen.dart';
import 'organigramme_list.dart';
import 'tripfuel_screen.dart';
import 'notifications_screen.dart';
import 'chef_messages_list.dart';
import 'auth_screen.dart';

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
  String _userTrigram = '---';
  int _currentIndex = 0;

  late List<Widget> _pages;
  final List<String> _titles = [
    'Accueil',
    'Missions Hebdo',
    'Vols du jour',
    'Calcul Carburant',
  ];

  @override
  void initState() {
    super.initState();
    _missionDao = MissionDao(widget.db);
    _planningDao = PlanningDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);
    _notificationDao = NotificationDao(widget.db);

    _loadTrigramme().then((_) {
      setState(() {
        _pages = _buildPages();
      });
    });
    _pages = _buildPages();
  }

  Future<void> _loadTrigramme() async {
    final prefs = await SharedPreferences.getInstance();
    final trig = prefs.getString('userTrigram') ?? prefs.getString('userTrigramme') ?? '';
    if (trig.isNotEmpty) {
      try {
        final user = await (widget.db.select(widget.db.users)
          ..where((u) => u.trigramme.equals(trig)))
            .getSingle();
        _userTrigram = trig;
        _userGroup = user.group.toLowerCase();
      } catch (_) {
        // ignore
      }
    }
  }

  List<Widget> _buildPages() {
    // Écran mission selon le groupe
    final missionPage = (_userGroup == 'helico')
        ? MissionsHelicoList(dao: _missionDao)
        : MissionsList(dao: _missionDao);

    return [
      HomeDashboard(db: widget.db),
      missionPage,
      VolEnCoursList(
        dao: _missionDao,
        group: _userGroup.isNotEmpty ? _userGroup : 'avion',
      ),
      TripFuelScreen(db: widget.db),
    ];
  }

  void _onItemTapped(int index) {
    Navigator.of(context).pop();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_userTrigram}_appGAP_${_titles[_currentIndex]}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Text('${_userTrigram}_appGAP',
                style: const TextStyle(color: Colors.white, fontSize: 24)),
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
            onTap: () => _onItemTapped(3),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AuthScreen(db: widget.db)),
                    (route) => false,
              );
            },
          ),
        ]),
      ),
      endDrawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: const Text('Administratif',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Planning annuel'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlanningList(dao: _planningDao),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield),
            title: const Text('Tours de garde'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ToursDeGardeScreen(
                  db: widget.db,
                  isAdmin: widget.isAdmin,
                ),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('Organigramme'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OrganigrammeList(db: widget.db),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Messages du Chef'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChefMessagesList(dao: _chefDao),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsScreen(
                  dao: _notificationDao,
                  group: _userGroup,
                ),
              ));
            },
          ),
        ]),
      ),
    );
  }
}
