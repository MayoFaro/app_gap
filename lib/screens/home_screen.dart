// lib/screens/home_screen.dart
//
// ✅ UX CONSERVÉE : Drawer gauche + endDrawer droit (pas de barre en bas)
// ✅ OPTI : body via builder + cache (pas d’IndexedStack -> démarrage plus léger)
// ✅ RÉTABLI : entrée "Astreintes opérationnelles" dans le volet gauche
// ✅ Bootstrap après 1ʳᵉ frame (pas de gros travail bloquant en initState)
//
// Remplace intégralement ton fichier par celui-ci.

import 'package:appgap/screens/tripfuel_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart' hide Notification;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/planning_dao.dart';
import '../data/chef_message_dao.dart';
import '../data/notification_dao.dart';

// Écrans principaux (volet gauche)
import '../services/sync_service.dart';
import 'AstreinteGeneratorScreen.dart';
import 'home_dashboard.dart';
import 'missions_list.dart';
import 'missions_helico_list.dart';
import 'vol_en_cours_list.dart';
// Astreintes opé (même écran que TWR/BAR/CRM si tu n’as pas de page dédiée)
import 'tours_de_garde_screen.dart';

// Écrans volet droit (administratif)
import 'planning_list.dart';
import 'chef_messages_list.dart';
import 'organigramme_screen.dart';

// Auth
import 'auth_screen.dart';

// Désactive le pré-chauffage pour éviter le pic CPU initial
const bool kPrewarmPages = false;

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final bool isAdmin;

  const HomeScreen({
    Key? key,
    required this.db,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // DAOs
  late final MissionDao _missionDao;
  late final PlanningDao _planningDao;
  late final ChefMessageDao _chefDao;
  late final NotificationDao _notificationDao;

  // Contexte user
  String _userTrigram = '---';
  String _userGroup = '';     // 'avion' | 'helico'
  String _userFonction = '';  // 'chef' | 'cdt' | autre
  bool _isAdmin = false;

  // UI
  bool _ready = false;
  int _currentIndex = 0; // 0 Accueil, 1 Missions, 2 Vols du jour, 3 Carburant, 4 Astreintes Opé (drawer gauche)

  // Cache paresseux
  final Map<int, Widget> _pageCache = <int, Widget>{};

  final List<String> _titles = const [
    'Accueil',
    'Missions Hebdo',
    'Vols du jour',
    'Calcul Carburant',
    'Astreintes opérationnelles',
  ];

  @override
  void initState() {
    super.initState();
    _missionDao = MissionDao(widget.db);
    _planningDao = PlanningDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);
    _notificationDao = NotificationDao(widget.db);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _loadUserContext();

      // 🔗 Relance la synchro Firestore → Drift
      final sync = SyncService(
        db: widget.db,
        fonction: _userFonction == 'chef'
            ? Fonction.chef
            : _userFonction == 'cdt'
            ? Fonction.cdt
            : Fonction.none,
      );
      await sync.syncAll();

      if (kPrewarmPages) {
        Future.delayed(const Duration(milliseconds: 300), () => _safePrewarm(1));
        Future.delayed(const Duration(milliseconds: 900), () => _safePrewarm(2));
      }
    } catch (e) {
      debugPrint('Home.bootstrap ERROR: $e');
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }


  Future<void> _loadUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    _userTrigram = (prefs.getString('userTrigram') ?? '---').toUpperCase();
    _userGroup = (prefs.getString('userGroup') ?? '').toLowerCase();
    _userFonction = (prefs.getString('userFonction') ?? '').toLowerCase();
    _isAdmin = prefs.getBool('isAdmin') ?? widget.isAdmin;
  }

  void _safePrewarm(int index) {
    Future.microtask(() {
      if (!mounted) return;
      _pageCache[index] ??= _instantiatePage(index);
    });
  }

  // ---------- Builder + cache ----------
  Widget _getPage(int index) {
    final cached = _pageCache[index];
    if (cached != null) return cached;
    final built = _instantiatePage(index);
    _pageCache[index] = built;
    return built;
  }

  Widget _instantiatePage(int index) {
    switch (index) {
      case 0:
        return HomeDashboard(
          db: widget.db,
          chefDao: _chefDao,
          currentUser: _userTrigram,
        );
      case 1: {
        final canEditAvion  = (_userFonction == 'chef' || _userFonction == 'cdt') && _userGroup == 'avion';
        final canEditHelico = (_userFonction == 'chef' || _userFonction == 'cdt') && _userGroup == 'helico';
        return (_userGroup == 'helico')
            ? MissionsHelicoList(dao: _missionDao, canEdit: canEditHelico)
            : MissionsList(dao: _missionDao, canEdit: canEditAvion);
      }
      case 2:
        return VolEnCoursList(
          dao: _missionDao,
          group: _userGroup.isNotEmpty ? _userGroup : 'avion',
        );
      case 3:
        return TripFuelScreen(db: widget.db);
      case 4:
      // Astreintes opérationnelles (réutilise l’écran existant)
        return ToursDeGardeScreen(isAdmin: _isAdmin);
      default:
        return const SizedBox.shrink();
    }
  }

  void _invalidateDependentPages() {
    _pageCache.remove(1); // Missions
    _pageCache.remove(2); // Vols du jour
  }

  void _onItemTapped(int index) {
    Navigator.of(context).pop(); // fermer le drawer gauche
    setState(() => _currentIndex = index);
  }

  Future<void> _logout() async {
    final auth = fbAuth.FirebaseAuth.instance;
    final prefs = await SharedPreferences.getInstance();
    try { await auth.signOut(); } finally {
      await prefs.remove('userEmail');
      await prefs.remove('userTrigram');
      await prefs.remove('userGroup');
      await prefs.remove('userFonction');
      await prefs.remove('isAdmin');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthScreen(db: widget.db)),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final title = '${_userTrigram}_appGAP_${_titles[_currentIndex]}';
    final bool canEditOrganigramme = _isAdmin || _userFonction == 'cdt' || _userFonction == 'chef';

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

      // 👉 builder + cache
      body: _getPage(_currentIndex),

      // ───────── Drawer gauche : navigation principale
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
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
              leading: const Icon(Icons.view_week),
              title: const Text('Missions Hebdo'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Astreintes opérationnelles'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AstreinteGeneratorScreen(
                      db: widget.db,
                      planningDao: PlanningDao(widget.db),
                    ),
                  ),
                );
              },
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
              onTap: _logout,
            ),
          ],
        ),
      ),

      // ───────── endDrawer droit : Administratif
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Administratif', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Planning annuel'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlanningList(dao: _planningDao)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield),
              title: const Text('Tours de garde'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ToursDeGardeScreen(isAdmin: widget.isAdmin)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Organigramme'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrganigrammeScreen(isAdmin: canEditOrganigramme)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Messages du Chef'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChefMessagesList(
                      currentUser: _userTrigram,
                      dao: _chefDao,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
