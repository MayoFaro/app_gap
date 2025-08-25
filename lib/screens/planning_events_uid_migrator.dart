import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Résultats de migration UID
class UidMigrationStats {
  int fixed = 0;
  int skipped = 0;
  int errors = 0;

  @override
  String toString() => 'UidMigrationStats(fixed=$fixed, skipped=$skipped, errors=$errors)';
}

/// Écran utilitaire pour remplir le champ `uid` des documents `planningEvents`
/// à partir de la collection `users`.
///
/// Règles de mapping :
/// - On construit un index trigramme -> uid **en privilégiant le doc.id long (UID FirebaseAuth)**.
/// - Si seul un doc seed `users/{TRI}` existe, on l'utilise en dernier recours (log d'alerte).
/// - On met à jour uniquement les events dont `uid` est vide (string vide ou champ manquant).
///
/// Usage :
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const PlanningEventsUidMigrator(dryRun: true),
/// ));
class PlanningEventsUidMigrator extends StatefulWidget {
  final bool dryRun; // true = affichage uniquement, false = maj réelle

  const PlanningEventsUidMigrator({Key? key, this.dryRun = false})
      : super(key: key);

  @override
  State<PlanningEventsUidMigrator> createState() =>
      _PlanningEventsUidMigratorState();
}

class _PlanningEventsUidMigratorState extends State<PlanningEventsUidMigrator> {
  bool _running = false;
  String _log = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.dryRun
          ? "Migration UID (dry run)"
          : "Migration UID (écriture réelle)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.play_arrow),
              label: Text(widget.dryRun
                  ? "Dry Run (pas d'écriture)"
                  : "⚠️ Lancer migration réelle"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log.isEmpty ? "Logs…" : _log,
                    style: const TextStyle(fontFamily: "monospace"),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _log = "Démarrage migration UID…\n";
    });

    final stats = UidMigrationStats();

    try {
      final fs = FirebaseFirestore.instance;

      // 1) Construire un index trigramme -> meilleur UID
      //    - si plusieurs docs /users ont le même trigramme,
      //      on garde PRIORITAIREMENT le doc.id "long" (UID FirebaseAuth, > 8 chars).
      final triToUid = <String, String>{};
      final triHadSeedOnly = <String, bool>{}; // pour logs (cas où seul seed existe)

      final userSnap = await fs.collection("users").get();
      for (final doc in userSnap.docs) {
        final data = doc.data();
        final triRaw = (data['trigramme'] ?? data['trigram'] ?? '').toString().trim();
        if (triRaw.isEmpty) {
          // Cas legacy extrême: pas de champ trigramme ; si doc.id ressemble à un trigramme, on peut le récupérer
          if (doc.id.length == 3) {
            final tri = doc.id.toUpperCase();
            // seed pur, on ne peut pas extraire mieux que doc.id=TRI ici
            triToUid.putIfAbsent(tri, () => doc.id); // provisoire
            triHadSeedOnly[tri] = true;
          }
          continue;
        }

        final tri = triRaw.toUpperCase();
        final looksLikeUid = doc.id.length > 8; // heuristique simple

        if (!triToUid.containsKey(tri)) {
          // Première fois qu'on voit ce trigramme
          triToUid[tri] = doc.id;
          triHadSeedOnly[tri] = !looksLikeUid; // true si seed en 1er
        } else {
          // Déjà une entrée : on remplace SEULEMENT si on tombe sur un vrai UID
          final current = triToUid[tri]!;
          final currentLooksLikeUid = current.length > 8;

          if (looksLikeUid && !currentLooksLikeUid) {
            // on passe d'un seed -> UID : upgrade
            triToUid[tri] = doc.id;
            triHadSeedOnly[tri] = false; // on a trouvé mieux
          }
          // si current est déjà un UID, on garde current
          // si les deux sont seeds, on laisse le premier (pas d'enjeu)
        }
      }

      // 2) Parcours des planningEvents
      final evSnap = await fs.collection("planningEvents").get();

      for (final doc in evSnap.docs) {
        try {
          final data = doc.data();

          // Champ uid actuel
          final uidRaw = (data['uid'] ?? '').toString().trim();
          if (uidRaw.isNotEmpty) {
            stats.skipped++;
            continue; // déjà rempli
          }

          // Déterminer le trigramme de l'event (user ou trigramme)
          String trig = (data['user'] ?? data['trigramme'] ?? '').toString().trim().toUpperCase();
          if (trig.isEmpty && doc.id.length == 3) {
            trig = doc.id.toUpperCase(); // ultra-legacy: très improbable mais safe
          }
          if (trig.isEmpty) {
            _append("IGNORÉ ${doc.id}: trigramme introuvable");
            stats.skipped++;
            continue;
          }

          final mappedUid = triToUid[trig];
          if (mappedUid == null) {
            _append("ERREUR ${doc.id}: aucun user doc trouvé pour trig=$trig");
            stats.errors++;
            continue;
          }

          if (widget.dryRun) {
            final usedSeed = mappedUid.length <= 8;
            _append("DRYRUN ${doc.id}: trig=$trig → uid=$mappedUid${usedSeed ? '  [SEED]' : ''}");
            stats.fixed++;
          } else {
            await doc.reference.update({'uid': mappedUid});
            final usedSeed = mappedUid.length <= 8;
            _append("FIXED ${doc.id}: trig=$trig → uid=$mappedUid${usedSeed ? '  [SEED]' : ''}");
            stats.fixed++;
          }
        } catch (e) {
          _append("ERREUR ${doc.id}: $e");
          stats.errors++;
        }
      }

      // 3) Petit résumé sur les trigrammes où seul un seed a été vu (et aucun UID)
      final onlySeeds = triHadSeedOnly.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList()
        ..sort();

      if (onlySeeds.isNotEmpty) {
        _append("\n[INFO] Trigrammes pour lesquels **aucun doc UID** n'a été trouvé (seed utilisé) :");
        _append(onlySeeds.join(', '));
      }
    } catch (e, st) {
      _append("EXCEPTION globale: $e\n$st");
    }

    _append(
        "\n=== FIN ===\nCorrigés=${stats.fixed}, ignorés=${stats.skipped}, erreurs=${stats.errors}");

    setState(() {
      _running = false;
    });
  }

  void _append(String line) {
    setState(() {
      _log += "$line\n";
    });
  }
}
