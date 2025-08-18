// lib/screens/home_screen.dart
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart' hide Notification;
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
import 'organigramme_screen.dart';
import 'tripfuel_screen.dart';
import 'notifications_screen.dart';
import 'chef_messages_list.dart';
import 'auth_screen.dart';

/// Écran racine après authentification.
/// - Charge le contexte utilisateur (trigramme, group, fonction) depuis SharedPreferences
///   puis vérifie en base (table users).
/// - Construit dynamiquement la page "Missions" selon le groupe (avion/hélico).
/// - Garde les pages en mémoire via un IndexedStack pour ne pas perdre leur état.
class HomeScreen extends StatefulWidget {
  final AppDatabase db;

  /// Optionnel : certains écrans (organigramme, etc.) peuvent exposer des actions supplémentaires
  /// si l'utilisateur est admin. Tu peux étendre la logique plus tard.
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

  // Contexte utilisateur (déterminent la page "missions" et divers droits UI)
  String _userTrigram = '---';
  String _userGroup = '';     // 'avion' | 'helico'
  String _userFonction = '';  // 'chef' | 'cdt' | ...

  // État UI
  int _currentIndex = 0;
  bool _ready = false;        // passe à true quand le profil est chargé
  List<Widget> _pages = const [];

  // Titres d’onglets, même ordre que _pages
  final List<String> _titles = <String>[
    'Accueil',
    'Missions Hebdo',
    'Vols du jour',
    'Calcul Carburant',
  ];

  @override
  void initState() {
    super.initState();

    // Instanciation des DAOs une seule fois
    _missionDao = MissionDao(widget.db);
    _planningDao = PlanningDao(widget.db);
    _chefDao = ChefMessageDao(widget.db);
    _notificationDao = NotificationDao(widget.db);

    // Charge le profil puis construit les pages à partir des infos
    _loadUserContext();
  }

  /// Récupère depuis SharedPreferences le trigramme,
  /// puis lit la table Users pour connaître group & fonction.
  Future<void> _loadUserContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trig = prefs.getString('userTrigram') ?? '';

      if (trig.isEmpty) {
        // Aucun user en cache → on reste minimal, l’AuthGate renverra vers AuthScreen si besoin
        debugPrint('DEBUG Home: aucun trigramme en prefs, retour écran d’auth possible.');
        setState(() {
          _ready = true;
          _pages = _buildPages(); // pages par défaut (missions avion si groupe inconnu)
        });
        return;
      }

      final row = await (widget.db.select(widget.db.users)
        ..where((u) => u.trigramme.equals(trig)))
          .getSingleOrNull();

      if (row == null) {
        // Incohérence prefs/BDD : on log et on continue en valeurs par défaut
        debugPrint('WARN Home: trigramme $trig non trouvé en BDD Users.');
        setState(() {
          _ready = true;
          _pages = _buildPages();
        });
        return;
      }

      _userTrigram  = trig;
      _userGroup    = row.group.toLowerCase();       // 'avion' ou 'helico'
      _userFonction = row.fonction.toLowerCase();    // 'chef', 'cdt', etc.

      debugPrint('DEBUG Home: user=$_userTrigram, group=$_userGroup, fonction=$_userFonction');

      setState(() {
        _ready = true;
        _pages = _buildPages();
        _currentIndex = 0; // on revient sur Accueil après (re)chargement
      });
    } catch (e) {
      debugPrint('ERROR Home._loadUserContext: $e');
      setState(() {
        _ready = true;
        _pages = _buildPages();
      });
    }
  }

  /// Construit la liste des pages à afficher dans l’IndexedStack,
  /// en choisissant la page "missions" selon le groupe de l’utilisateur.
  List<Widget> _buildPages() {
    // Droit de création/édition: chef et cdt sont autorisés
    final bool isBoss = (_userFonction == 'chef' || _userFonction == 'cdt');

    // canEdit s’applique seulement sur la page du groupe courant
    final bool canEditAvion  = isBoss && _userGroup == 'avion';
    final bool canEditHelico = isBoss && _userGroup == 'helico';

    final missionPage = (_userGroup == 'helico')
        ? MissionsHelicoList(dao: _missionDao, canEdit: canEditHelico)
        : MissionsList(dao: _missionDao, canEdit: canEditAvion);

    return <Widget>[
      HomeDashboard(
        db: widget.db,
        chefDao: _chefDao,
        currentUser: _userTrigram,
      ),
      missionPage,
      VolEnCoursList(
        dao: _missionDao,
        group: _userGroup.isNotEmpty ? _userGroup : 'avion',
      ),
      TripFuelScreen(db: widget.db),
    ];
  }

  /// Changement d’onglet depuis le drawer
  void _onItemTapped(int index) {
    Navigator.of(context).pop(); // referme le drawer
    setState(() {
      // On reconstruit les pages au cas où le contexte user a changé (déconnexion/reconnexion)
      _pages = _buildPages();
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tant que le profil n’est pas prêt, on évite tout flicker + faux routage
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final title = '${_userTrigram}_appGAP_${_titles[_currentIndex]}';

    // Un admin peut éditer l’organigramme ; à toi d’étendre la logique si besoin
    final bool canEditOrganigramme = widget.isAdmin;

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

      // On garde les pages en mémoire pour éviter de perdre l’état de chacune
      body: IndexedStack(index: _currentIndex, children: _pages),

      // Drawer principal (navigation)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text(
                '${_userTrigram}_appGAP',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
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
                // Désactive les taps ici si besoin (setState _loggingOut = true)
                final auth = fbAuth.FirebaseAuth.instance;
                final prefs = await SharedPreferences.getInstance();

                try {
                  await auth.signOut(); // <-- IMPORTANT: attendre la fin
                } finally {
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
              },
            ),
          ],
        ),
      ),

      // Drawer “admin / outils”
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
            if (_userFonction == 'chef' || _userFonction == 'cdt')
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Messages du Chef'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChefMessagesList(
                        dao: _chefDao,
                        currentUser: _userTrigram,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      dao: _notificationDao,
                      group: _userGroup,
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
