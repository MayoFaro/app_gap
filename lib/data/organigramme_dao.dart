// lib/data/organigramme_dao.dart
//
// DAO pour l'organigramme (local) + helpers d'upsert.
// -> Pas d'accès Firestore direct ici (ça reste dans le use-case de sync).
//
// Intégration: ajoute OrganigrammeNodes à AppDatabase (voir note plus bas).

import 'package:drift/drift.dart';
import 'app_database.dart';
import 'organigramme_tables.dart';

part 'organigramme_dao.g.dart';

@DriftAccessor(tables: [OrganigrammeNodes])
class OrganigrammeDao extends DatabaseAccessor<AppDatabase>
    with _$OrganigrammeDaoMixin {
  OrganigrammeDao(AppDatabase db) : super(db);

  // --- READ ---------------------------------------------------------------

  Future<List<OrganigrammeNode>> getAll() =>
      select(organigrammeNodes).get();

  Future<OrganigrammeNode?> getByUserId(String userId) =>
      (select(organigrammeNodes)..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

  Stream<List<OrganigrammeNode>> watchAll() =>
      (select(organigrammeNodes)).watch();

  // --- UPSERT -------------------------------------------------------------

  /// Upsert d'un nœud (utilisé par la sync)
  Future<void> upsertNode({
    required String userId,
    String? parentId,
    DateTime? updatedAt,
  }) async {
    final existing = await getByUserId(userId);
    if (existing == null) {
      await into(organigrammeNodes).insert(
        OrganigrammeNodesCompanion.insert(
          userId: userId,
          parentId: Value(parentId),
          updatedAt: Value(updatedAt),
        ),
      );
    } else {
      await (update(organigrammeNodes)..where((t) => t.userId.equals(userId)))
          .write(OrganigrammeNodesCompanion(
        parentId: Value(parentId),
        updatedAt: Value(updatedAt),
      ));
    }
  }

  /// Supprime les nœuds absents du remote (nettoyage)
  Future<int> deleteWhereNotIn(Set<String> keepUserIds) async {
    return (delete(organigrammeNodes)
      ..where((t) => t.userId.isNotIn(keepUserIds.toList())))
        .go();
  }
}
