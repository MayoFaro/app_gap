// lib/services/sync_service.dart
//
// ✅ Correctif MAJEUR _syncUsers :
//    - Si la table locale "users" est VIDE → on force un IMPORT COMPLET (peu importe lastSync)
//    - Filet de sécurité : si après l’incrémentale, le local reste anormalement faible, on refait un full import
// ✅ Le reste (missions, planning, chefMessages, organigramme) inchangé
//
// Remplace intégralement ton fichier par celui-ci.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/cupertino.dart'; // for debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide Column, Query;

import '../data/app_database.dart';
import '../data/chef_message_dao.dart';
import '../models/user_model.dart';

enum Fonction { chef, cdt, none }

class SyncService {
  final AppDatabase db;
  final Fonction fonction;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  SyncService({required this.db, required this.fonction});

  Future<void> syncAll() async {
    debugPrint("SYNC: Début synchronisation pour fonction=$fonction");

    await _syncUsers();           // ✅ correctif ici
    await _syncChefMessages();
    await _syncOrganigramme();
    await _syncMissions();
    await _syncPlanningEvents();

    debugPrint("SYNC: Fin de la synchronisation");
  }

  // ---------------------------------------------------------------------------
  // HELPERS lastSync
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

  DateTime _startOfTodayLocal() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ---------------------------------------------------------------------------
  // USERS (correctif)
  Future<void> _syncUsers() async {
    try {
        final existing = await db.select(db.users).get();
        debugPrint('SYNC[users][diagnostic] local=${existing.length}');
        final localCount = existing.length;
        final lastSync = await _getLastSync('users');

        // ✅ 1) Si la table locale est vide → FULL IMPORT (peu importe lastSync)
        if (localCount == 0) {
          debugPrint('SYNC[users]: table locale vide → FULL import Firestore…');
          await _fullImportUsers();
          await _setLastSync('users', DateTime.now());
          return;
         }

      // ✅ 2) Sinon, incrémentale sur updatedAt > lastSync
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

      // ✅ 3) Filet de sécurité : si local anormal (<5) ou si aucune maj, on force un full
      final after = await db.select(db.users).get();
      if (after.length < 5) {
        debugPrint('SYNC[users][safety]: local<5 → FULL import');
        await _fullImportUsers();
      }

      await _setLastSync('users', DateTime.now());
      debugPrint('SYNC[users][inc]: done (upserts=$touched)');
    } catch (e, st) {
      debugPrint('SYNC[users][ERROR]: $e');
      debugPrint(st.toString());
    }
  }

  /// Import complet de la collection users avec déduplication par trigramme.
  Future<void> _fullImportUsers() async {
    final snap = await firestore.collection('users').get();
    debugPrint('SYNC[users][full]: Firestore count=${snap.docs.length}');
    if (snap.docs.isEmpty) return;

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
        } // sinon on garde prev
      }
    }

    final inserts = byTrig.values.map((p) => p.comp).toList(growable: false);
    debugPrint('SYNC[users][full]: prêts à insérer ${inserts.length} (dup=$duplicates, uidWins=$uidWins)');

    try {
      await db.batch((b) => b.insertAllOnConflictUpdate(db.users, inserts));
      debugPrint('SYNC[users][full]: UPSERT batch OK');
    } catch (_) {
      for (final row in inserts) {
        await db.into(db.users).insertOnConflictUpdate(row);
      }
      debugPrint('SYNC[users][full]: UPSERT boucle OK');
    }
  }

  // ---------------------------------------------------------------------------
  // CHEF MESSAGES
  Future<void> _syncChefMessages() async {
    debugPrint('SYNC[chefMessages]: start');

    final dao = ChefMessageDao(db);
    final today = _startOfTodayLocal();

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

      final acksSnap = await firestore
          .collection('chefMessages').doc(remoteId)
          .collection('acks').orderBy('seenAt', descending: false).get();

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
  // MISSIONS
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
  // PLANNING EVENTS
  Future<void> _syncPlanningEvents() async {
    debugPrint('SYNC[planningEvents]: start (fonction=$fonction)');

    final qBase = _buildPlanningEventsQuery();
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

  Future<bool> _upsertPlanningEventFromFirestore(String docId, Map<String, dynamic> data) async {
    try {
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

      final existing = await (db.select(db.planningEvents)
        ..where((t) => t.firestoreId.equals(docId))).getSingleOrNull();

      final comp = PlanningEventsCompanion.insert(
        user: trigram,
        typeEvent: typeEvent,
        dateStart: dateStart,
        dateEnd: dateEnd,
        uid: Value(uid),
        firestoreId: Value(docId),
        rank: Value(rank),
      );

      if (existing == null) {
        await db.into(db.planningEvents).insert(comp);
      } else {
        await (db.update(db.planningEvents)..where((t) => t.id.equals(existing.id))).write(comp);
      }

      return true;
    } catch (e, st) {
      debugPrint('SYNC[planning][ERROR][$docId]: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  String? _extractTrigramForPlanning(Map<String, dynamic> data) {
    String? s = (data['user'] as String?);
    if (s != null && s.trim().length == 3) return s.trim().toUpperCase();
    s = (data['trigramme'] as String?) ?? (data['trigram'] as String?) ?? (data['userTrigram'] as String?);
    if (s != null && s.trim().length == 3) return s.trim().toUpperCase();
    return null;
  }

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

  DateTime? _pickEffectiveTimestamp(Map<String, dynamic> data) {
    final u = data['updatedAt'];
    final c = data['createdAt'];
    if (u is Timestamp) return u.toDate();
    if (c is Timestamp) return c.toDate();
    return null;
  }
}

class _UserPick {
  final UsersCompanion comp;
  final bool isUid;
  final String docId;
  _UserPick({required this.comp, required this.isUid, required this.docId});
}
