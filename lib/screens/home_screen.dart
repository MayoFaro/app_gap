// lib/screens/home_screen.dart
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart' hide Notification;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firestore

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
/// - Charge le contexte utilisateur depuis SharedPreferences
/// - ✅ Garantit que la table locale `users` est peuplée (synchro Firestore → Drift, avec dédup par trigramme et priorité au doc UID)
/// - Construit dynamiquement la page "Missions" selon le groupe (avion/hélico)
/// - Garde les pages en mémoire via un IndexedStack
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

  // Contexte utilisateur
  String _userTrigram = '---';
  String _userGroup = '';     // 'avion' | 'helico'
  String _userFonction = '';  // 'chef' | 'cdt' | 'rien' ...

  // État UI
  int _currentIndex = 0;
  bool _ready = false;
  List<Widget> _pages = const [];

  final List<String> _titles = <String>[
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

    _bootstrap();
  }

  /// Bootstrap: 1) profil, 2) synchro users locale si vide (avec dédup), 3) pages
  Future<void> _bootstrap() async {
    try {
      await _loadUserContext();
      await _ensureUsersSynced(); // ✅ important pour alimenter les pickers partout
    } catch (e, st) {
      debugPrint('ERROR Home._bootstrap: $e');
      debugPrint(st.toString());
    } finally {
      if (mounted) {
        setState(() {
          _ready = true;
          _pages = _buildPages();
          _currentIndex = 0;
        });
      }
    }
  }

  /// Charge trigramme / group / fonction depuis SharedPreferences
  Future<void> _loadUserContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _userTrigram  = prefs.getString('userTrigram') ?? '---';
      _userGroup    = (prefs.getString('userGroup') ?? '').toLowerCase();
      _userFonction = (prefs.getString('userFonction') ?? '').toLowerCase();

      if (_userTrigram == '---' || _userGroup.isEmpty || _userFonction.isEmpty) {
        debugPrint('WARN Home: profil incomplet dans SharedPreferences → valeurs par défaut.');
      }

      debugPrint('DEBUG Home: user=$_userTrigram, group=$_userGroup, fonction=$_userFonction');
    } catch (e) {
      debugPrint('ERROR Home._loadUserContext: $e');
    }
  }

  /// Synchro Firestore → Drift pour la table `users`, avec:
  /// - Déduplication par `trigramme`
  /// - **Priorité au doc UID** (doc.id ≠ trigramme && doc.id.length > 8)
  /// - UPSERT (insert on conflict update) pour éviter toute erreur d'unicité
  Future<void> _ensureUsersSynced() async {
    try {
      final existing = await widget.db.select(widget.db.users).get();
      if (existing.isNotEmpty) {
        debugPrint('SYNC[users]: table locale déjà peuplée (count=${existing.length}) → skip.');
        return;
      }

      debugPrint('SYNC[users]: table locale vide → lecture Firestore…');
      final snap = await FirebaseFirestore.instance.collection('users').get();
      debugPrint('SYNC[users]: Firestore count=${snap.docs.length}');

      if (snap.docs.isEmpty) {
        debugPrint('SYNC[users]: aucun doc Firestore → rien à insérer.');
        return;
      }

      // 1) Normalisation + déduplication par trigramme
      //    Règle: si plusieurs docs partagent le même trigramme, on garde celui
      //    dont l'ID **ressemble à un UID** (id ≠ trigramme et longueur > 8).
      //    Sinon, on prend le "seed" (id = trigramme ou id court).
      final Map<String, _UserPick> byTrig = {}; // trigramme -> choix retenu
      int duplicates = 0;
      int uidWins = 0;

      for (final d in snap.docs) {
        final data = d.data();

        final triRaw      = (data['trigramme'] ?? data['trigram'] ?? '').toString().trim();
        final grpRaw      = (data['group'] ?? data['groupe'] ?? '').toString().trim();
        final roleRaw     = (data['role'] ?? '').toString().trim();
        final fonctionRaw = (data['fonction'] ?? '').toString().trim();

        if (triRaw.isEmpty) continue;

        final grp = grpRaw.toLowerCase();                      // avion|helico
        final role = roleRaw.toLowerCase();                    // pilote|mecano|...
        final fonction = (fonctionRaw.isEmpty ? 'rien' : fonctionRaw.toLowerCase()); // min length 3

        // Champs indispensables
        if (grp.isEmpty || role.isEmpty) {
          debugPrint('SYNC[users]: skip "$triRaw" (grp="$grpRaw", role="$roleRaw", fonction="$fonctionRaw")');
          continue;
        }

        // Heuristique UID : ID différent du trigramme et longueur > 8
        final docId = d.id;
        final bool looksLikeUid = (docId != triRaw && docId.length > 8);

        final comp = UsersCompanion.insert(
          trigramme: triRaw,
          group: grp,
          role: role,
          fonction: fonction,
        );

        final candidate = _UserPick(comp: comp, isUid: looksLikeUid, docId: docId);

        final prev = byTrig[triRaw];
        if (prev == null) {
          byTrig[triRaw] = candidate;
        } else {
          // Doublon détecté
          duplicates++;
          // Priorité au doc UID
          if (!prev.isUid && candidate.isUid) {
            byTrig[triRaw] = candidate;
            uidWins++;
          } else if (prev.isUid && !candidate.isUid) {
            // garde prev
          } else {
            // Les deux sont seeds ou les deux "ressemblent" à UID → on remplace par le dernier
            // (pas d'enjeu ici: tu as dit que les champs sont identiques)
            byTrig[triRaw] = candidate;
          }
        }
      }

      if (byTrig.isEmpty) {
        debugPrint('SYNC[users]: aucun enregistrement valide à insérer après déduplication.');
        return;
      }

      final inserts = byTrig.values.map((p) => p.comp).toList(growable: false);
      debugPrint('SYNC[users]: prêts à insérer ${inserts.length} lignes (après dédup). '
          'doublons détectés=$duplicates, uid préférés=$uidWins');

      // 2) UPSERT:
      //    - Tente insertAllOnConflictUpdate (Drift récent)
      //    - Sinon fallback: boucle insertOnConflictUpdate
      try {
        await widget.db.batch((b) {
          b.insertAllOnConflictUpdate(widget.db.users, inserts);
        });
        debugPrint('SYNC[users]: UPSERT batch réussi (insertAllOnConflictUpdate).');
      } catch (e) {
        debugPrint('SYNC[users]: insertAllOnConflictUpdate indisponible → fallback par boucle.');
        for (final row in inserts) {
          await widget.db
              .into(widget.db.users)
              .insertOnConflictUpdate(row);
        }
        debugPrint('SYNC[users]: UPSERT boucle réussi (insertOnConflictUpdate).');
      }
    } catch (e, st) {
      debugPrint('SYNC[users][ERROR]: $e');
      debugPrint(st.toString());
    }
  }

  List<Widget> _buildPages() {
    final bool isBoss = (_userFonction == 'chef' || _userFonction == 'cdt');

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

  void _onItemTapped(int index) {
    Navigator.of(context).pop(); // referme le drawer
    setState(() {
      _pages = _buildPages();
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final title = '${_userTrigram}_appGAP_${_titles[_currentIndex]}';
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

      body: IndexedStack(index: _currentIndex, children: _pages),

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
                final auth = fbAuth.FirebaseAuth.instance;
                final prefs = await SharedPreferences.getInstance();

                try {
                  await auth.signOut();
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

/// Petit conteneur interne pour gérer la priorité UID vs seed lors de la dédup.
class _UserPick {
  final UsersCompanion comp;
  final bool isUid;
  final String docId;
  _UserPick({required this.comp, required this.isUid, required this.docId});
}
