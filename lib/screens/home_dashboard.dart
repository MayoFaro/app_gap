// lib/screens/home_dashboard.dart
//
// Version optimisée "First Frame Safe":
// - ❌ AUCUNE synchro Firestore déclenchée ici (plus de pullFromRemote() dans initState)
// - ✅ Le tableau des 5 prochaines missions vient uniquement de la base locale (Drift)
// - ✅ La bannière "Message du chef" reste affichée (stream Firestore côté widget dédié)
// - ✅ Tout le travail potentiellement lourd est repoussé hors 1ʳᵉ frame (et hors écran d'accueil)
//
// But: éviter le jank au démarrage en supprimant le gros travail réseau qui avait lieu
// dans HomeDashboard.initState() (pullFromRemote), tout en gardant la même UI.
//
// Remarque: la synchro globale "delta + sentinelles" est orchestrée par SyncService ailleurs.
// Ici, le dashboard lit juste le cache local.

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' ;
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';
import '../data/chef_message_dao.dart';
import '../widgets/chef_message_banner.dart';

class HomeDashboard extends StatefulWidget {
  final AppDatabase db;
  final ChefMessageDao chefDao;   // conservé pour compat, pas utilisé ici
  final String currentUser;       // trigramme (affiché éventuellement par des widgets enfants)

  const HomeDashboard({
    Key? key,
    required this.db,
    required this.chefDao,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late final MissionDao _missionDao;
  late Future<List<Mission>> _futureNextMissions;

  @override
  void initState() {
    super.initState();
    _missionDao = MissionDao(widget.db);
    _futureNextMissions = _loadNextMissions(); // ⚠️ Local only
  }

  Future<List<Mission>> _loadNextMissions() async {
    // 5 prochaines missions à partir d'aujourd'hui (tous vecteurs)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final query = widget.db.select(widget.db.missions)
      ..where((t) => t.date.isBiggerOrEqualValue(today))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc)])
      ..limit(5);

    return query.get();
  }

  // UI helpers
  String _formatDate(DateTime d) => DateFormat('EEE dd/MM', 'fr_FR').format(d);
  String _formatPilotes(Mission m) {
    final p2 = (m.pilote2 ?? '').isNotEmpty ? '/${m.pilote2}' : '';
    final p3 = (m.pilote3 ?? '').isNotEmpty ? '/${m.pilote3}' : '';
    return '${m.pilote1}$p2$p3';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // On relit simplement le local ; la synchro distante est gérée par SyncService.
        setState(() {
          _futureNextMissions = _loadNextMissions();
        });
        await _futureNextMissions;
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ───────────────────────────────────── Bannière "Message du chef"
          // Le widget interne gère son propre stream Firestore, ACK, etc.
          const ChefMessageBanner(),

          const SizedBox(height: 12),

          // ───────────────────────────────────── Carte "Prochaines missions"
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.flight_takeoff),
                      SizedBox(width: 8),
                      Text('Prochaines missions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Mission>>(
                    future: _futureNextMissions,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: LinearProgressIndicator(),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red)),
                        );
                      }
                      final list = snap.data ?? const <Mission>[];
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Aucune mission à venir en local.'),
                        );
                      }

                      return ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, i) {
                          final m = list[i];
                          return Row(
                            children: [
                              // Date + destination
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_formatDate(m.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(m.destinationCode, style: const TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              ),
                              // Vecteur
                              Expanded(
                                flex: 2,
                                child: Text(m.vecteur, textAlign: TextAlign.center),
                              ),
                              // Pilotes
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _formatPilotes(m),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontFeatures: []),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
