// lib/screens/planning_events_migrator.dart
//
// Utilitaire de normalisation de la collection planningEvents.
// Contrat visé : user = TRIGRAMME (3 lettres, UPPERCASE), trigramme = TRIGRAMME (miroir), uid = Firebase UID.
// - Ne modifie pas typeEvent (on conserve la valeur existante).
// - Met à jour updatedAt.
// - Retourne des statistiques (fixed/skipped/errors) pour affichage.
//
// Usage :
// final migrator = PlanningEventsMigrator(firestore: FirebaseFirestore.instance);
// final stats = await migrator.normalize(dryRun: true); // lecture seule
// print("fixed=${stats.fixed}, skipped=${stats.skipped}, errors=${stats.errors}");

import 'package:cloud_firestore/cloud_firestore.dart';

class PlanningEventsMigrationStats {
  final int fixed;
  final int skipped;
  final int errors;
  final bool dryRun;

  const PlanningEventsMigrationStats({
    required this.fixed,
    required this.skipped,
    required this.errors,
    required this.dryRun,
  });

  @override
  String toString() =>
      'PlanningEventsMigrationStats(fixed=$fixed, skipped=$skipped, errors=$errors, dryRun=$dryRun)';
}

class PlanningEventsMigrator {
  final FirebaseFirestore _fs;
  PlanningEventsMigrator({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  /// Normalise les documents de la collection `planningEvents`.
  ///
  /// - `dryRun=true` : ne modifie rien, mais comptabilise combien **seraient** corrigés.
  /// - `batchSize` : nb d'opérations Firestore par batch (max 500).
  ///
  /// Retourne des statistiques : `fixed`, `skipped`, `errors`.
  Future<PlanningEventsMigrationStats> normalize({
    bool dryRun = true,
    int batchSize = 250,
  }) async {
    int fixed = 0;
    int skipped = 0;
    int errors = 0;

    try {
      final coll = _fs.collection('planningEvents');
      final usersColl = _fs.collection('users');

      final snap = await coll.get();

      WriteBatch? batch;
      int inBatch = 0;

      String? _resolveTri(Map<String, dynamic> data) {
        final trig = (data['trigramme'] as String?)?.trim();
        if (trig != null && trig.length == 3) return trig.toUpperCase();

        final userField = (data['user'] as String?)?.trim();
        if (userField != null && userField.length == 3) return userField.toUpperCase();

        // pas de trigramme évident
        return null;
      }

      for (final d in snap.docs) {
        try {
          final data = d.data() as Map<String, dynamic>;
          final uid = (data['uid'] as String?)?.trim();

          // 1) Essaie de déduire un trigramme
          String? tri = _resolveTri(data);

          // 2) Si toujours pas, on tente via /users/{uid}
          if (tri == null && uid != null && uid.isNotEmpty) {
            try {
              final u = await usersColl.doc(uid).get();
              if (u.exists) {
                final triFromUser = (u.data()?['trigramme'] as String?)?.trim();
                if (triFromUser != null && triFromUser.length == 3) {
                  tri = triFromUser.toUpperCase();
                }
              }
            } catch (_) {
              // ignore, on comptera en skipped si on ne peut pas résoudre
            }
          }

          if (tri == null) {
            skipped++;
            continue;
          }

          // 3) Déjà conforme ?
          final userField = (data['user'] as String?)?.trim();
          final trigField = (data['trigramme'] as String?)?.trim();
          final needsFix = (userField != tri) || (trigField != tri) || (uid == null);

          if (!needsFix) {
            // tout est déjà bon → rien à faire
            continue;
          }

          if (dryRun) {
            fixed++; // compterait comme corrigé en mode réel
            continue;
          }

          // 4) Correction en batch
          batch ??= _fs.batch();
          batch.update(d.reference, {
            'user': tri,
            'trigramme': tri,
            if (uid == null) 'uid': '', // on met au moins une chaîne vide si inconnu
            'updatedAt': FieldValue.serverTimestamp(),
          });
          inBatch++;
          fixed++;

          if (inBatch >= batchSize) {
            await batch.commit();
            batch = null;
            inBatch = 0;
          }
        } catch (_) {
          errors++;
          // on continue sur les autres docs
        }
      }

      if (!dryRun && batch != null && inBatch > 0) {
        await batch.commit();
      }
    } catch (_) {
      // Erreur globale (ex: droits) : on l’impute à `errors`
      errors++;
    }

    return PlanningEventsMigrationStats(
      fixed: fixed,
      skipped: skipped,
      errors: errors,
      dryRun: dryRun,
    );
  }
}
