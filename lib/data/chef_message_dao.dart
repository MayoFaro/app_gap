// lib/data/chef_message_dao.dart
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'chef_message_dao.g.dart';

@DriftAccessor(tables: [ChefMessages])
class ChefMessageDao extends DatabaseAccessor<AppDatabase> with _$ChefMessageDaoMixin {
  ChefMessageDao(super.db);

  /// Récupère tous les messages du chef, triés par date décroissante
  Future<List<ChefMessage>> getAllMessages() {
    return (select(chefMessages)
      ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.desc),
      ]))
        .get();
  }

  /// Insère un nouveau message
  Future<int> insertMessage(ChefMessagesCompanion entry) {
    return into(chefMessages).insert(entry);
  }

  /// Supprime un message par ID
  Future<int> deleteMessage(int id) {
    return (delete(chefMessages)..where((tbl) => tbl.id.equals(id))).go();
  }
}
