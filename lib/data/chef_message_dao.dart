// lib/data/chef_message_dao.dart
//
// DAO Drift pour les messages du chef + acks.
// - Lecture locale (Drift)
// - Upsert depuis Firestore (utilisé par SyncService)
// - ACK local + push Firestore (pratique depuis le Dashboard)
//
// NB: Ce DAO suppose que les tables ChefMessages / ChefMessageAcks
// ont été ajoutées à AppDatabase (voir patch dans la section 4).

import 'package:drift/drift.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart' as auth;

import 'app_database.dart';

part 'chef_message_dao.g.dart';

@DriftAccessor(tables: [ChefMessages, ChefMessageAcks])
class ChefMessageDao extends DatabaseAccessor<AppDatabase>
    with _$ChefMessageDaoMixin {
  ChefMessageDao(AppDatabase db) : super(db);

  // ---------------------------------------------------------------------------
  // LECTURE LOCALE
  // ---------------------------------------------------------------------------

  /// Tous les messages triés du plus récent au plus ancien
  Future<List<ChefMessage>> getAllMessages() {
    return (select(chefMessages)
      ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]))
        .get();
  }

  /// Acks pour un message local [messageId], triés chronologiquement
  Future<List<ChefMessageAck>> getAcks(int messageId) {
    return (select(chefMessageAcks)
      ..where((t) => t.messageId.equals(messageId))
      ..orderBy([
            (t) => OrderingTerm(expression: t.seenAt, mode: OrderingMode.asc)
      ]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // ÉCRITURE LOCALE
  // ---------------------------------------------------------------------------

  Future<int> insertMessage(ChefMessagesCompanion entry) {
    return into(chefMessages).insert(entry,
        mode: InsertMode.insertOrReplace); // remplace si même PK
  }

  Future<int> deleteMessage(int id) {
    // Grâce à onDelete: cascade, les ACKs seront supprimés aussi
    return (delete(chefMessages)..where((t) => t.id.equals(id))).go();
  }

  /// Ajoute/Met à jour un ACK local et pousse aussi l’ACK vers Firestore si possible
  Future<void> acknowledge(int messageId, String trigramme) async {
    // 1) Local: upsert ACK
    // On tente d'insérer; si (messageId, trigramme) existe déjà, on met juste seenAt=now
    final existingAck = await (select(chefMessageAcks)
      ..where((t) =>
      t.messageId.equals(messageId) & t.trigramme.equals(trigramme)))
        .getSingleOrNull();

    final now = DateTime.now();
    if (existingAck == null) {
      await into(chefMessageAcks).insert(
        ChefMessageAcksCompanion.insert(
          messageId: messageId,
          trigramme: trigramme,
          seenAt: Value(now),
          uid: const Value(null),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (update(chefMessageAcks)..where((t) => t.id.equals(existingAck.id)))
          .write(ChefMessageAcksCompanion(seenAt: Value(now)));
    }

    // 2) Remote: push ACK dans /chefMessages/{remoteId}/acks/{uid}
    final msg = await (select(chefMessages)..where((t) => t.id.equals(messageId)))
        .getSingleOrNull();
    final remoteId = msg?.remoteId;
    if (remoteId == null || remoteId.isEmpty) return;

    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final acksRef = fs.FirebaseFirestore.instance
        .collection('chefMessages')
        .doc(remoteId)
        .collection('acks')
        .doc(uid);

    await acksRef.set({
      'uid': uid,
      'trigramme': trigramme,
      'seenAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // HELPERS D’UPSERT (utilisés par le SyncService)
  // ---------------------------------------------------------------------------

  /// Upsert d’un message Firestore vers Drift à partir de son [remoteId]
  /// Retourne l'ID local.
  Future<int> upsertMessageFromRemote({
    required String remoteId,
    required String content,
    required String group,
    required String author,
    required String authorRole,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) async {
    // Existe déjà ? on récupère la ligne pour garder son id local
    final existing = await (select(chefMessages)
      ..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();

    if (existing == null) {
      return await into(chefMessages).insert(
        ChefMessagesCompanion.insert(
          remoteId: remoteId,
          content: content,
          group: group,
          author: author.toUpperCase(),
          authorRole: authorRole,
          createdAt: createdAt,
          updatedAt: Value(updatedAt),
        ),
      );
    } else {
      await (update(chefMessages)..where((t) => t.id.equals(existing.id)))
          .write(ChefMessagesCompanion(
        content: Value(content),
        group: Value(group),
        author: Value(author.toUpperCase()),
        authorRole: Value(authorRole),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      ));
      return existing.id;
    }
  }

  /// Upsert d’un ACK Firestore vers Drift
  Future<void> upsertAckFromRemote({
    required int localMessageId,
    required String trigramme,
    String? uid,
    DateTime? seenAt,
  }) async {
    final exists = await (select(chefMessageAcks)
      ..where((t) =>
      t.messageId.equals(localMessageId) &
      t.trigramme.equals(trigramme.toUpperCase())))
        .getSingleOrNull();

    if (exists == null) {
      await into(chefMessageAcks).insert(
        ChefMessageAcksCompanion.insert(
          messageId: localMessageId,
          trigramme: trigramme.toUpperCase(),
          uid: Value(uid),
          seenAt: Value(seenAt ?? DateTime.now()),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (update(chefMessageAcks)..where((t) => t.id.equals(exists.id))).write(
        ChefMessageAcksCompanion(
          uid: Value(uid),
          seenAt: Value(seenAt ?? exists.seenAt),
        ),
      );
    }
  }
}
