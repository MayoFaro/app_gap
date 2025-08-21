// File: lib/services/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/cupertino.dart'; // for debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide Column, Query;

import '../data/app_database.dart'; // Drift (tables & companions)
import '../data/chef_message_dao.dart';
import '../models/user_model.dart'; // (optionnel) si besoin

/// Enum de pilotage de la stratégie de synchro.
enum Fonction { chef, cdt, none }

/// Service unique de synchronisation Firestore → Drift.
class SyncService {
  final AppDatabase db;
  final Fonction fonction;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  SyncService({required this.db, required this.fonction});

  Future<void> syncAll() async {
    debugPrint("SYNC: Début synchronisation pour fonction=$fonction");

    await _syncUsers();           // Full (1er run) + incrémentale (updatedAt)
    await _syncChefMessages();    // createdAt >= today
    await _syncOrganigramme();    // Full + incrémentale (updatedAt)
    await _syncMissions();        // Stratégie dépend de fonction + upsert réel
    await _syncPlanningEvents();  // createdAt (non-chef) ; full+inc chef/cdt

    debugPrint("SYNC: Fin de la synchronisation");
  }

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------
  Future<void> _syncUsers() async {
    try {
      final existing = await db.select(db.users).get();
      final lastSync = await _getLastSync('users');
      final isFirstRun = existing.isEmpty && (lastSync == null);

      if (isFirstRun) {
        debugPrint('SYNC[users]: table locale vide → lecture Firestore…');
        final snap = await firestore.collection('users').get();
        debugPrint('SYNC[users]: Firestore count=${snap.docs.length}');
        if (snap.docs.isEmpty) {
          await _setLastSync('users', DateTime.now());
          return;
        }

        final Map<String, _UserPick> byTrig = {};
        int duplicates = 0;
        int uidWins = 0;

        for (final d in snap.docs) {
          final data = d.data();
          final triRaw      = (data['trigramme'] ?? data['trigram'] ?? '').toString().trim();
          final grpRaw      = (data['group'] ?? data['groupe'] ?? '').toString().trim();
          final roleRaw     = (data['role'] ?? '').toString().trim();
          final fonctionRaw = (data['fonction'] ?? '').toString().trim();
          if (triRaw.isEmpty) continue;

          final grp = grpRaw.toLowerCase();
          final role = roleRaw.toLowerCase();
          final fonction = (fonctionRaw.isEmpty ? 'rien' : fonctionRaw.toLowerCase());
          if (grp.isEmpty || role.isEmpty) continue;

          final looksLikeUid = (d.id != triRaw && d.id.length > 8);
          final comp = UsersCompanion.insert(
            trigramme: triRaw,
            group: grp,
            role: role,
            fonction: fonction,
          );

          final cand = _UserPick(comp: comp, isUid: looksLikeUid, docId: d.id);
          final prev = byTrig[triRaw];
          if (prev == null) {
            byTrig[triRaw] = cand;
          } else {
            duplicates++;
            if (!prev.isUid && cand.isUid) {
              byTrig[triRaw] = cand; uidWins++;
            } else if (prev.isUid && !cand.isUid) {
              // keep prev
            } else {
              byTrig[triRaw] = cand;
            }
          }
        }

        final inserts = byTrig.values.map((p) => p.comp).toList(growable: false);
        if (inserts.isEmpty) {
          await _setLastSync('users', DateTime.now());
          return;
        }

        debugPrint('SYNC[users]: prêts à insérer ${inserts.length} lignes (après dédup). '
            'doublons détectés=$duplicates, uid préférés=$uidWins');

        try {
          await db.batch((b) => b.insertAllOnConflictUpdate(db.users, inserts));
          debugPrint('SYNC[users]: UPSERT batch réussi.');
        } catch (_) {
          for (final row in inserts) {
            await db.into(db.users).insertOnConflictUpdate(row);
          }
          debugPrint('SYNC[users]: UPSERT boucle réussi.');
        }

        await _setLastSync('users', DateTime.now());
        return;
      }

      // incrémentale
      debugPrint('SYNC[users][inc]: start (lastSync=$lastSync)');
      const pageSize = 300;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      final qBase = firestore.collection('users').orderBy('updatedAt', descending: false);

      int touched = 0;
      while (true) {
        Query<Map<String, dynamic>> q = qBase.limit(pageSize);
        if (cursor != null) q = q.startAfterDocument(cursor);

        final snap = await q.get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final data = doc.data();
          final ts = data['updatedAt'];
          if (ts is! Timestamp) continue;
          if (lastSync != null && !ts.toDate().isAfter(lastSync)) continue;

          final triRaw      = (data['trigramme'] ?? data['trigram'] ?? '').toString().trim();
          final grpRaw      = (data['group'] ?? data['groupe'] ?? '').toString().trim();
          final roleRaw     = (data['role'] ?? '').toString().trim();
          final fonctionRaw = (data['fonction'] ?? '').toString().trim();
          if (triRaw.isEmpty) continue;

          final grp = grpRaw.toLowerCase();
          final role = roleRaw.toLowerCase();
          final fonctionStr = (fonctionRaw.isEmpty ? 'rien' : fonctionRaw.toLowerCase());
          if (grp.isEmpty || role.isEmpty) continue;

          final comp = UsersCompanion.insert(
            trigramme: triRaw, group: grp, role: role, fonction: fonctionStr,
          );
          await db.into(db.users).insertOnConflictUpdate(comp);
          touched++;
          debugPrint('SYNC[users][inc->upsert]: ${doc.id} ($triRaw)');
        }

        cursor = snap.docs.length < pageSize ? null : snap.docs.last;
        if (cursor == null) break;
      }

      await _setLastSync('users', DateTime.now());
      debugPrint('SYNC[users][inc]: done (upserts=$touched)');
    } catch (e, st) {
      debugPrint('SYNC[users][ERROR]: $e');
      debugPrint(st.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // CHEF MESSAGES
  // ---------------------------------------------------------------------------
  Future<void> _syncChefMessages() async {
    debugPrint('SYNC[chefMessages]: start');

    final dao = ChefMessageDao(db); // <-- adapte si ton champ s'appelle autrement
    final today = _startOfTodayLocal();

    // 1) Récupération des messages depuis Firestore (>= aujourd'hui 00:00)
    final q = firestore
        .collection('chefMessages')
        .where('createdAt', isGreaterThanOrEqualTo: fs.Timestamp.fromDate(today))
        .orderBy('createdAt', descending: false);

    final snap = await q.get();

    int upserts = 0;
    int acksUpserts = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteId = doc.id;

      final content = (data['content'] as String?)?.trim() ?? '';
      final group = (data['group'] as String? ?? 'tous').toLowerCase();
      final author = ((data['author'] as String?) ?? '--').toUpperCase();
      final authorRole = (data['authorRole'] as String? ?? 'chef').toLowerCase();

      final tsCreated = data['createdAt'];
      final tsUpdated = data['updatedAt'];
      final createdAt = (tsCreated is fs.Timestamp) ? tsCreated.toDate() : DateTime.now();
      final updatedAt = (tsUpdated is fs.Timestamp) ? tsUpdated.toDate() : null;

      // 1.a Upsert du message en local
      final localId = await dao.upsertMessageFromRemote(
        remoteId: remoteId,
        content: content,
        group: group,
        author: author,
        authorRole: authorRole,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      upserts++;

      // 1.b Récupération des ACKs distants, upsert en local
      final acksSnap = await firestore
          .collection('chefMessages')
          .doc(remoteId)
          .collection('acks')
          .orderBy('seenAt', descending: false)
          .get();

      for (final a in acksSnap.docs) {
        final ad = a.data();
        final trig = (ad['trigramme'] as String? ?? '--').toUpperCase();
        final uid = (ad['uid'] as String?);
        final ts = ad['seenAt'];
        final when = (ts is fs.Timestamp) ? ts.toDate() : null;

        await dao.upsertAckFromRemote(
          localMessageId: localId,
          trigramme: trig,
          uid: uid,
          seenAt: when,
        );
        acksUpserts++;
      }
    }

    debugPrint('SYNC[chefMessages]: messages upsert=$upserts, acks upsert=$acksUpserts');
    debugPrint('SYNC[chefMessages]: done');
  }


  // ---------------------------------------------------------------------------
  // ORGANIGRAMME
  // ---------------------------------------------------------------------------
  Future<void> _syncOrganigramme() async {
    debugPrint('SYNC[organigramme]: start');

    final qBase = firestore.collection('organigramme').orderBy('updatedAt', descending: false);
    const pageSize = 300;
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    final lastSync = await _getLastSync('organigramme');

    while (true) {
      Query<Map<String, dynamic>> q = qBase.limit(pageSize);
      if (cursor != null) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['updatedAt'];
        if (lastSync != null) {
          if (ts is! Timestamp) continue;
          if (!ts.toDate().isAfter(lastSync)) continue;
        }

        // TODO: upsert Drift (organigramme)
        debugPrint('SYNC[pull->update][org]: ${doc.id}');
      }

      cursor = snap.docs.length < pageSize ? null : snap.docs.last;
      if (cursor == null) break;
    }

    await _setLastSync('organigramme', DateTime.now());
    debugPrint('SYNC[organigramme]: done');
  }

  // ---------------------------------------------------------------------------
  // MISSIONS : upsert réel (identique à MissionDao.pullFromRemote)
  // ---------------------------------------------------------------------------
  Future<void> _syncMissions() async {
    debugPrint('SYNC[missions]: start (fonction=$fonction)');

    final qBase = _buildMissionsQuery();
    const pageSize = 300;
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    final lastSync = (fonction == Fonction.chef) ? await _getLastSync('missions') : null;

    while (true) {
      Query<Map<String, dynamic>> q = qBase.limit(pageSize);
      if (cursor != null) q = q.startAfterDocument(cursor);

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final data = doc.data();
        if (lastSync != null) {
          final ts = data['updatedAt'];
          if (ts is! Timestamp) continue;
          if (!ts.toDate().isAfter(lastSync)) continue;
        }
        await _upsertMissionFromFirestore(doc.id, data);
      }

      cursor = snap.docs.length < pageSize ? null : snap.docs.last;
      if (cursor == null) break;
    }

    if (fonction == Fonction.chef) {
      await _setLastSync('missions', DateTime.now());
    }
    debugPrint('SYNC[missions]: done');
  }

  // ---------------------------------------------------------------------------
  // PLANNING EVENTS : upsert réel (pull)
  //  - chef/cdt : full scan paginé par createdAt, filtre inc. sur (updatedAt ?? createdAt)
  //  - none     : where createdAt >= today
  // ---------------------------------------------------------------------------
  Future<void> _syncPlanningEvents() async {
    debugPrint('SYNC[planningEvents]: start (fonction=$fonction)');

    final qBase = _buildPlanningEventsQuery(); // créé selon fonction
    const pageSize = 300;
    DocumentSnapshot<Map<String, dynamic>>? cursor;

    final bool fullScan = (fonction == Fonction.chef || fonction == Fonction.cdt);
    final DateTime? lastSync = fullScan ? await _getLastSync('planning') : null;

    int touched = 0;
    while (true) {
      Query<Map<String, dynamic>> q = qBase.limit(pageSize);
      if (cursor != null) q = q.startAfterDocument(cursor);

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final data = doc.data();

        // chef/cdt → filtre inc. sur (updatedAt ?? createdAt)
        if (lastSync != null) {
          final DateTime? eff = _pickEffectiveTimestamp(data);
          if (eff == null || !eff.isAfter(lastSync)) continue;
        }

        final ok = await _upsertPlanningEventFromFirestore(doc.id, data);
        if (ok) {
          touched++;
          debugPrint('SYNC[pull->update][planning]: ${doc.id}');
        }
      }

      cursor = snap.docs.length < pageSize ? null : snap.docs.last;
      if (cursor == null) break;
    }

    if (fullScan) {
      await _setLastSync('planning', DateTime.now());
    }

    debugPrint('SYNC[planningEvents]: done (upserts~$touched)');
  }

  // =========================== HELPERS PRIVÉS ================================

  /// Upsert **réel** d'une mission (insert/update/push selon fraîcheur).
  Future<void> _upsertMissionFromFirestore(String remoteId, Map<String, dynamic> data) async {
    try {
      final tsDate = data['date'];
      if (tsDate is! Timestamp) {
        debugPrint('SYNC[missions][WARN]: doc $remoteId sans champ "date" Timestamp → skip');
        return;
      }
      final dt = tsDate.toDate();
      final vecteur = (data['vecteur'] as String?) ?? '';
      final pilote1 = (data['pilote1'] as String?) ?? '';
      final pilote2 = data['pilote2'] as String?;
      final pilote3 = data['pilote3'] as String?;
      final destinationCode = (data['destinationCode'] as String?) ?? '';
      final description = data['description'] as String?;
      final createdAtRemote =
      (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();
      final updatedAtRemote =
      (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now();

      final existing = await (db.select(db.missions)..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

      final comp = MissionsCompanion.insert(
        date: dt,
        vecteur: vecteur,
        pilote1: pilote1,
        pilote2: Value(pilote2),
        pilote3: Value(pilote3),
        destinationCode: destinationCode,
        description: Value(description),
        createdAt: Value(createdAtRemote),
        updatedAt: Value(updatedAtRemote),
        remoteId: Value(remoteId),
        isSynced: const Value(true),
      );

      if (existing == null) {
        await db.into(db.missions).insert(comp);
        debugPrint("SYNC[pull->insert]: $remoteId");
      } else {
        final localUpdated = existing.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (updatedAtRemote.isAfter(localUpdated)) {
          await (db.update(db.missions)..where((t) => t.id.equals(existing.id))).write(comp);
          debugPrint("SYNC[pull->update]: $remoteId");
        } else {
          // push local vers Firestore si besoin
          await firestore.collection('missions').doc(existing.remoteId!).set({
            'date': Timestamp.fromDate(existing.date),
            'vecteur': existing.vecteur,
            'pilote1': existing.pilote1,
            if (existing.pilote2 != null) 'pilote2': existing.pilote2,
            if (existing.pilote3 != null) 'pilote3': existing.pilote3,
            'destinationCode': existing.destinationCode,
            if (existing.description != null) 'description': existing.description,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));
          await (db.update(db.missions)..where((t) => t.id.equals(existing.id)))
              .write(const MissionsCompanion(isSynced: Value(true)));
          debugPrint("SYNC[pull->pushLocal]: $remoteId");
        }
      }
    } catch (e, st) {
      debugPrint('SYNC[missions][ERROR][$remoteId]: $e');
      debugPrint(st.toString());
    }
  }

  /// Upsert **réel** d’un planningEvent (insert/update).
  /// - Match par `firestoreId` = doc.id
  /// - Mapping trigramme local: `user` (3 lettres) ou `trigramme`/`trigram`/`userTrigram`
  /// - Dates requises: `dateStart` et `dateEnd` (Timestamp)
  /// - `uid` (si présent) stocké dans la colonne locale `uid`
  Future<bool> _upsertPlanningEventFromFirestore(String docId, Map<String, dynamic> data) async {
    try {
      // 1) Extractions robustes
      final String? trigram = _extractTrigramForPlanning(data);
      if (trigram == null) {
        debugPrint('SYNC[planning][WARN]: $docId sans trigramme exploitable → skip');
        return false;
      }

      final typeEvent = (data['typeEvent'] ?? data['type']) as String?;
      if (typeEvent == null || typeEvent.isEmpty) {
        debugPrint('SYNC[planning][WARN]: $docId sans typeEvent/type → skip');
        return false;
      }

      final tsStart = data['dateStart'];
      final tsEnd = data['dateEnd'];
      if (tsStart is! Timestamp || tsEnd is! Timestamp) {
        debugPrint('SYNC[planning][WARN]: $docId sans dateStart/dateEnd Timestamp → skip');
        return false;
      }
      final dateStart = tsStart.toDate();
      final dateEnd = tsEnd.toDate();

      final String uid = (data['uid'] as String?) ?? '';
      final int? rank = (data['rank'] is int) ? (data['rank'] as int) : null;

      // 2) Existe-t-il déjà localement ?
      final existing = await (db.select(db.planningEvents)
        ..where((t) => t.firestoreId.equals(docId)))
          .getSingleOrNull();

      final comp = PlanningEventsCompanion.insert(
        user: trigram,                  // 3 lettres
        typeEvent: typeEvent,
        dateStart: dateStart,
        dateEnd: dateEnd,
        uid: Value(uid),                // UID (peut être vide)
        firestoreId: Value(docId),
        rank: Value(rank),
      );

      if (existing == null) {
        // INSERT
        await db.into(db.planningEvents).insert(comp);
      } else {
        // UPDATE (on reflète la source serveur)
        await (db.update(db.planningEvents)..where((t) => t.id.equals(existing.id))).write(comp);
      }

      return true;
    } catch (e, st) {
      debugPrint('SYNC[planning][ERROR][$docId]: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  /// Heuristique : récupère un trigramme (3 lettres) depuis le doc Firestore.
  /// - si `user` existe et length==3 → pris
  /// - sinon on tente `trigramme` / `trigram` / `userTrigram`
  /// - sinon null (skip)
  String? _extractTrigramForPlanning(Map<String, dynamic> data) {
    String? s = (data['user'] as String?);
    if (s != null && s.trim().length == 3) return s.trim().toUpperCase();
    s = (data['trigramme'] as String?) ?? (data['trigram'] as String?) ?? (data['userTrigram'] as String?);
    if (s != null && s.trim().length == 3) return s.trim().toUpperCase();
    return null;
  }

  /// Début de journée locale (00:00:00).
  DateTime _startOfTodayLocal() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<DateTime?> _getLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('sync_last_$key');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _setLastSync(String key, DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sync_last_$key', dt.millisecondsSinceEpoch);
  }

  // ---------------------------- Query Builders -------------------------------

  Query<Map<String, dynamic>> _buildMissionsQuery() {
    final col = firestore.collection('missions');
    final today = _startOfTodayLocal();

    if (fonction == Fonction.chef) {
      return col.orderBy('updatedAt', descending: false);
    } else {
      return col
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('date', descending: false);
    }
  }

  /// planningEvents :
  /// - chef/cdt : full scan par createdAt ; inc. via (updatedAt ?? createdAt)
  /// - none     : where createdAt >= today
  Query<Map<String, dynamic>> _buildPlanningEventsQuery() {
    final col = firestore.collection('planningEvents');
    final today = _startOfTodayLocal();

    if (fonction == Fonction.chef || fonction == Fonction.cdt) {
      return col.orderBy('createdAt', descending: false);
    } else {
      return col
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('createdAt', descending: false);
    }
  }

  /// Timestamp “effectif” pour l’incrémentale planning.
  DateTime? _pickEffectiveTimestamp(Map<String, dynamic> data) {
    final u = data['updatedAt'];
    final c = data['createdAt'];
    if (u is Timestamp) return u.toDate();
    if (c is Timestamp) return c.toDate();
    return null;
  }
}

/// Structure interne pour la déduplication users
class _UserPick {
  final UsersCompanion comp;
  final bool isUid;
  final String docId;
  _UserPick({required this.comp, required this.isUid, required this.docId});
}
