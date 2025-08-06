// lib/data/chef_message_dao.dart
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'chef_message_dao.g.dart';

@DriftAccessor(tables: [ChefMessages, ChefMessageAcks]) //Undefined name 'ChefMessages'.
class ChefMessageDao extends DatabaseAccessor<AppDatabase> with _$ChefMessageDaoMixin {
  ChefMessageDao(super.db);

  /// Récupère tous les messages du chef, triés par date décroissante
  Future<List<ChefMessage>> getAllMessages() {
    return (select(chefMessages)
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
    ).get();
  }

  /// Insère un nouveau message
  Future<int> insertMessage(ChefMessagesCompanion entry) {
    return into(chefMessages).insert(entry);
  }

  /// Supprime un message par ID (global)
  Future<int> deleteMessage(int id) {
    return (delete(chefMessages)..where((t) => t.id.equals(id))).go();
  }

  /// Acknowledge that [trigramme] has seen message [messageId]
  Future<int> acknowledge(int messageId, String trigramme) {
    return into(chefMessageAcks).insert(
      ChefMessageAcksCompanion.insert(
        messageId: messageId,
        trigramme: trigramme,
      ),
    );
  }

  /// Retrieve all acknowledgements for [messageId]
  Future<List<ChefMessageAck>> getAcks(int messageId) {
    return (select(chefMessageAcks)
      ..where((t) => t.messageId.equals(messageId))
      ..orderBy([(t) => OrderingTerm(expression: t.seenAt, mode: OrderingMode.asc)])
    ).get();
  }
}


