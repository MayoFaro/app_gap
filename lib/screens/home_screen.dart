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
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final bool isAdmin;

  const HomeScreen({Key? key, required this.db, this.isAdmin = false})
      : super(key: key);

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

    _pages = _buildPages();
    _loadTrigramme();
  }

  Future<void> _loadTrigramme() async {
    final prefs = await SharedPreferences.getInstance();
    // DEBUG: lister toutes les clés
    print('DEBUG prefs keys = ${prefs.getKeys()}');
    String? trig = prefs.getString('userTrigram');
    print('DEBUG prefs[userTrigram] = $trig');
    if ((trig == null || trig.isEmpty) && prefs.containsKey('userTrigramme')) {
      trig = prefs.getString('userTrigramme');
      print('DEBUG prefs[userTrigramme] = $trig');
    }

    if (trig != null && trig.isNotEmpty) {
      try {
        // On force `trig!` car on sait qu'il n'est pas null ici
        final user = await (widget.db.select(widget.db.users)
          ..where((u) => u.trigramme.equals(trig!)))
            .getSingle();
        print('DEBUG DB user.group = ${user.group}');
        setState(() {
          _userTrigram = trig!;
          _userGroup = user.group;
          _pages = _buildPages();
        });
      } catch (e) {
        print('ERROR: trigram "$trig" introuvable en base → $e');
      }
    } else {
      print('DEBUG: aucun trigramme trouvé dans SharedPreferences');
    }
  }

  List<Widget> _buildPages() {
    return [
      HomeDashboard(db: widget.db),
      MissionsList(dao: _missionDao),
      VolEnCoursList(
          dao: _missionDao, group: _userGroup.isNotEmpty ? _userGroup : 'avion'),
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
          builder: (ctx) =>
              IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        actions: [
          Builder(
            builder: (ctx) =>
                IconButton(icon: const Icon(Icons.settings), onPressed: () => Scaffold.of(ctx).openEndDrawer()),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Text('${_userTrigram}_appGAP', style: const TextStyle(color: Colors.white, fontSize: 24)),
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
              await prefs.remove('userTrigram');
              await prefs.remove('userTrigramme');
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
            },
          ),
        ]),
      ),
      endDrawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: const Text('Administratif', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Planning annuel'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanningList(dao: _planningDao))); //<=The named parameter 'trigram' is required, but there's no corresponding argument.
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield),
            title: const Text('Tours de garde'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ToursDeGardeScreen(db: widget.db, isAdmin: widget.isAdmin)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('Organigramme'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => OrganigrammeList(db: widget.db)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Messages du Chef'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChefMessagesList(dao: _chefDao)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotificationsScreen(dao: _notificationDao, group: _userGroup)));
            },
          ),
        ]),
      ),
    );
  }
}
