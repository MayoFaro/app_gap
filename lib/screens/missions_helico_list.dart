// lib/screens/missions_helico_list.dart
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';

const List<String> helicoDestinations = ['--', 'FOGK', 'FOGR', 'FOOL', 'FOON', 'FOOG', 'FOGO'];

class _MissionsData {
  final List<Mission> missions;
  final bool isChef;
  _MissionsData({required this.missions, required this.isChef});
}

class MissionsHelicoList extends StatefulWidget {
  final MissionDao dao;
  final bool canEdit;

  const MissionsHelicoList({Key? key, required this.dao, required this.canEdit}) : super(key: key);

  @override
  State<MissionsHelicoList> createState() => _MissionsHelicoListState();
}

class _MissionsHelicoListState extends State<MissionsHelicoList> {
  late Future<_MissionsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _dataFuture = _loadData();
  }

  Future<_MissionsData> _loadData() async {
    final all = await widget.dao.getAllMissions();
    const helicoVec = ['AH175', 'EC225'];
    final filtered = all.where((m) => helicoVec.contains(m.vecteur)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return _MissionsData(missions: filtered, isChef: widget.canEdit);
  }

  // ─────────────────────────────────────────────────────────────────────────────
// Fenêtre de création/édition d’une mission hélico
// Harmonisée visuellement avec la version avion :
// - Pickers iOS (CupertinoPicker) dans SizedBox(height: 80)
// - itemExtent: 32, looping: true
// - Libellés identiques ("Heure de décollage", "Pilote 1", etc.)
// Spécificités hélico conservées : choix vecteur (AH175/EC225) + Pilote3
// ─────────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────────
// Fenêtre de création/édition d’une mission hélico (VERSION INSTRUMENTÉE)
// - Style harmonisé avec la version avion (CupertinoPicker height:80, itemExtent:32, looping:true)
// - Spécificités hélico conservées (vecteur AH175/EC225 + Pilote 3)
// - LOGS détaillés pour diagnostiquer l’absence de pilotes en base locale
// ─────────────────────────────────────────────────────────────────────────────
  Future<void> _showMissionDialog({Mission? mission}) async {
    // Marqueur d'entrée
    debugPrint("[HELI][DIALOG] _showMissionDialog() CALLED @ ${DateTime.now().toIso8601String()} (missionId=${mission?.id})");

    // 1) Lecture de la table users (SQLite/Drift)
    List<dynamic> allUsers = const [];
    try {
      final t0 = DateTime.now();
      allUsers = await widget.dao.attachedDatabase
          .select(widget.dao.attachedDatabase.users)
          .get();
      final dtMs = DateTime.now().difference(t0).inMilliseconds;
      debugPrint("[HELI][DIALOG] Users loaded from local DB: count=${allUsers.length} in ${dtMs}ms");
    } catch (e, st) {
      debugPrint("[HELI][ERROR] Failed to load users from local DB: $e");
      debugPrint(st.toString());
    }

    // 2) Logs de diagnostic sur le contenu users
    try {
      debugPrint("[HELI][DIALOG] --- USERS SAMPLE (max 10) ---");
      for (final u in allUsers.take(10)) {
        // Les champs attendus: trigramme, group, role
        // On protège par toString() + trim pour éviter les null
        final tri = (u.trigramme ?? '').toString();
        final grp = (u.group ?? '').toString();
        final rol = (u.role ?? '').toString();
        debugPrint("[HELI][USER] trigramme=$tri | group=$grp | role=$rol");
      }

      // Distribution group/role (utile pour voir si 'helico' / 'pilote' / 'mecano' existent)
      final Map<String, int> groupDist = {};
      final Map<String, int> roleDist  = {};
      int nullGroup = 0, nullRole = 0;

      for (final u in allUsers) {
        final g = ((u.group ?? '') as String).trim().toLowerCase();
        final r = ((u.role ?? '') as String).trim().toLowerCase();
        if (g.isEmpty) nullGroup++; else groupDist[g] = (groupDist[g] ?? 0) + 1;
        if (r.isEmpty) nullRole++;  else roleDist[r]  = (roleDist[r]  ?? 0) + 1;
      }

      debugPrint("[HELI][DIALOG] group distribution: $groupDist | null/empty=$nullGroup");
      debugPrint("[HELI][DIALOG] role  distribution: $roleDist  | null/empty=$nullRole");
    } catch (e) {
      debugPrint("[HELI][WARN] Could not print users distribution: $e");
    }

    // 3) Listes équipages (spécificité hélico: P1 = pilotes, P2/P3 = pilotes ou mécanos)
    //    (On garde exactement la même logique que précédemment)
    final pilotes1 = ['--'] +
        allUsers
            .where((u) =>
        (u.role ?? '').toString().toLowerCase().trim() == 'pilote' &&
            (u.group ?? '').toString().toLowerCase().trim() == 'helico')
            .map<String>((u) => (u.trigramme ?? '').toString())
            .where((tri) => tri.isNotEmpty)
            .toList();

    final pilotes23 = ['--'] +
        allUsers
            .where((u) {
          final role = (u.role ?? '').toString().toLowerCase().trim();
          final grp  = (u.group ?? '').toString().toLowerCase().trim();
          return grp == 'helico' && (role == 'pilote' || role == 'mecano');
        })
            .map<String>((u) => (u.trigramme ?? '').toString())
            .where((tri) => tri.isNotEmpty)
            .toList();

    debugPrint("[HELI][DIALOG] pilotes1.size=${pilotes1.length}  (sample: ${pilotes1.take(10).join(', ')})");
    debugPrint("[HELI][DIALOG] pilotes23.size=${pilotes23.length} (sample: ${pilotes23.take(10).join(', ')})");

    // 4) Vecteurs hélico (spécificité conservée)
    const vecteurs = ['AH175', 'EC225'];
    String chosenVect = mission?.vecteur ?? vecteurs.first;

    // 5) Date bornée à aujourd’hui (identique avion)
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);
    DateTime chosenDate = mission?.date ?? minDate;
    if (chosenDate.isBefore(minDate)) chosenDate = minDate;

    // 6) Destination & heure (mêmes conventions que l’avion)
    //    NB: 'helicoDestinations' doit exister dans ce fichier (liste de codes, ex: ['--','FOOL',...])
    String chosenDest = mission?.destinationCode ?? helicoDestinations.first;
    String chosenTime = mission != null
        ? DateFormat('HH:mm').format(mission.date)
        : '08:30';

    // 7) Pilotes initiaux
    String chosenP1 = mission?.pilote1 ?? (pilotes1.isNotEmpty ? pilotes1.first : '--');
    String chosenP2 = mission?.pilote2 ?? (pilotes23.isNotEmpty ? pilotes23.first : '--');
    String chosenP3 = mission?.pilote3 ?? (pilotes23.isNotEmpty ? pilotes23.first : '--');

    final remarkCtrl = TextEditingController(text: mission?.description);

    // 8) Plage d’heures de 30 minutes (identique avion)
    final times = List.generate(48, (i) {
      final h = i ~/ 2;
      final m = (i % 2) * 30;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    });

    debugPrint("[HELI][DIALOG] Ready to open dialog | vect=$chosenVect date=${DateFormat('dd/MM/yyyy').format(chosenDate)} dest=$chosenDest time=$chosenTime");

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateInner) => AlertDialog(
          title: Text(
            mission == null ? 'Ajouter mission hélico' : 'Modifier mission hélico',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Appareil (spécificité hélico)
                const Text('Appareil'),
                CupertinoSegmentedControl<String>(
                  groupValue: chosenVect,
                  children: {
                    for (var v in vecteurs)
                      v: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(v),
                      ),
                  },
                  onValueChanged: (v) {
                    debugPrint("[HELI][UI] chosenVect -> $v");
                    setStateInner(() => chosenVect = v);
                  },
                ),
                const SizedBox(height: 8),

                // ── Date (identique avion)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: chosenDate.isAfter(minDate)
                          ? () {
                        final old = chosenDate;
                        setStateInner(() {
                          chosenDate = chosenDate.subtract(const Duration(days: 1));
                        });
                        debugPrint("[HELI][UI] date ${DateFormat('dd/MM').format(old)} -> ${DateFormat('dd/MM').format(chosenDate)}");
                      }
                          : null,
                    ),
                    Text(DateFormat('dd/MM/yyyy').format(chosenDate)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        final old = chosenDate;
                        setStateInner(() {
                          chosenDate = chosenDate.add(const Duration(days: 1));
                        });
                        debugPrint("[HELI][UI] date ${DateFormat('dd/MM').format(old)} -> ${DateFormat('dd/MM').format(chosenDate)}");
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Destination (style avion)
                const Text('Destination'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: helicoDestinations.indexOf(chosenDest),
                    ),
                    onSelectedItemChanged: (i) {
                      setStateInner(() => chosenDest = helicoDestinations[i]);
                      debugPrint("[HELI][UI] chosenDest -> $chosenDest");
                    },
                    children: helicoDestinations
                        .map((d) => Center(child: Text(d)))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Heure (harmonisée avec avion)
                const Text('Heure de décollage'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: times.indexOf(chosenTime),
                    ),
                    onSelectedItemChanged: (i) {
                      setStateInner(() => chosenTime = times[i]);
                      debugPrint("[HELI][UI] chosenTime -> $chosenTime");
                    },
                    children: times.map((t) => Center(child: Text(t))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Pilote 1
                const Text('Pilote 1'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: pilotes1.indexOf(chosenP1),
                    ),
                    onSelectedItemChanged: (i) {
                      setStateInner(() => chosenP1 = pilotes1[i]);
                      debugPrint("[HELI][UI] chosenP1 -> $chosenP1");
                    },
                    children: pilotes1.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Pilote 2
                const Text('Pilote 2'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: pilotes23.indexOf(chosenP2),
                    ),
                    onSelectedItemChanged: (i) {
                      setStateInner(() => chosenP2 = pilotes23[i]);
                      debugPrint("[HELI][UI] chosenP2 -> $chosenP2");
                    },
                    children: pilotes23.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Pilote 3
                const Text('Pilote 3'),
                SizedBox(
                  height: 80,
                  child: CupertinoPicker(
                    looping: true,
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: pilotes23.indexOf(chosenP3),
                    ),
                    onSelectedItemChanged: (i) {
                      setStateInner(() => chosenP3 = pilotes23[i]);
                      debugPrint("[HELI][UI] chosenP3 -> $chosenP3");
                    },
                    children: pilotes23.map((p) => Center(child: Text(p))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Remarque
                const Text('Remarque'),
                TextField(controller: remarkCtrl),
              ],
            ),
          ),
          actions: [
            if (mission != null)
              TextButton(
                onPressed: () async {
                  try {
                    await widget.dao.deleteMission(mission.id);
                    debugPrint("[HELI][ACTION] Mission deleted locally (id=${mission.id})");
                  } catch (e, st) {
                    debugPrint("[HELI][ERROR] deleteMission failed: $e");
                    debugPrint(st.toString());
                  }
                  Navigator.of(ctx2).pop();
                },
                child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () {
                debugPrint("[HELI][ACTION] Cancel dialog");
                Navigator.of(ctx2).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final parts = chosenTime.split(':');
                  final dt = DateTime(
                    chosenDate.year,
                    chosenDate.month,
                    chosenDate.day,
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                  );

                  if (mission == null) {
                    // Création locale
                    await widget.dao.upsertMission(MissionsCompanion.insert(
                      date: dt,
                      vecteur: chosenVect,
                      pilote1: chosenP1,
                      pilote2: Value(chosenP2),
                      pilote3: Value(chosenP3),
                      destinationCode: chosenDest,
                      description: Value(remarkCtrl.text.trim()),
                    ));
                    debugPrint("[HELI][ACTION] Mission created locally (vect=$chosenVect dest=$chosenDest time=$chosenTime p1=$chosenP1 p2=$chosenP2 p3=$chosenP3)");
                  } else {
                    // Modification locale
                    await widget.dao.upsertMission(
                      mission.copyWith(
                        date: dt,
                        vecteur: chosenVect,
                        pilote1: chosenP1,
                        pilote2: Value(chosenP2),
                        pilote3: Value(chosenP3),
                        destinationCode: chosenDest,
                        description: Value(remarkCtrl.text.trim()),
                      ).toCompanion(true),
                    );
                    debugPrint("[HELI][ACTION] Mission updated locally (id=${mission.id})");
                  }

                  // Sync Firestore
                  final t0 = DateTime.now();
                  await widget.dao.syncPendingMissions();
                  final dtMs = DateTime.now().difference(t0).inMilliseconds;
                  debugPrint("[HELI][SYNC] syncPendingMissions done in ${dtMs}ms");

                  if (mounted) {
                    Navigator.of(ctx2).pop();
                    setState(() {}); // recharge la liste
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(mission == null
                            ? "✅ Mission hélico créée et synchronisée"
                            : "✅ Mission hélico modifiée et synchronisée"),
                      ),
                    );
                  }
                } catch (e, st) {
                  debugPrint("[HELI][ERROR] Save mission failed: $e");
                  debugPrint(st.toString());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("❌ Erreur: $e")),
                    );
                  }
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );

    // Rafraîchissement de la liste
    try {
      _refreshData(); // ✅ corrigé : plus de await ici
      if (mounted) setState(() {});
      debugPrint("[HELI][DIALOG] Closed and list refreshed");
    } catch (e, st) {
      debugPrint("[HELI][WARN] _refreshData() failed: $e");
      debugPrint(st.toString());
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions Hebdo (Hélico)'),
        actions: [
          // 🔄 Bouton de synchronisation manuelle (même logique que MissionsList avion)
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Synchroniser maintenant",
            onPressed: () async {
              await widget.dao.syncPendingMissions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🔄 Synchronisation manuelle effectuée")),
                );
              }
              _refreshData();
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          if (data.missions.isEmpty) return const Center(child: Text('Aucune mission hélico'));
          return ListView.builder(
            itemCount: data.missions.length,
            itemBuilder: (_, i) {
              final m = data.missions[i];
              return GestureDetector(
                onLongPress: data.isChef ? () => _showMissionDialog(mission: m) : null,
                child: ListTile(
                  leading: Icon(
                    m.isSynced ? Icons.check_circle : Icons.sync_problem,
                    color: m.isSynced ? Colors.green : Colors.orange,
                  ),
                  title: Text('${DateFormat('dd/MM').format(m.date)}  ${m.vecteur}'),
                  subtitle: Text(
                    '${DateFormat('HH:mm').format(m.date)} • ${m.pilote1}/${m.pilote2}/${m.pilote3} → ${m.destinationCode}'
                        '${m.description != null ? ' – ${m.description}' : ''}',
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<_MissionsData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done || !(snap.data?.isChef ?? false)) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => _showMissionDialog(),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
