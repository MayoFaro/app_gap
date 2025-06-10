// lib/data/notification_dao.dart
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'notification_dao.g.dart';

@DriftAccessor(tables: [Notifications])
class NotificationDao extends DatabaseAccessor<AppDatabase> with _$NotificationDaoMixin {
  NotificationDao(super.db);

  /// Récupère toutes les notifications pour un groupe donné
  Future<List<Notification>> getForGroup(String group) {
    return (select(notifications)
      ..where((tbl) => tbl.group.equals(group))
      ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
      ]))
        .get();
  }

  /// Insère une notification
  Future<int> insertNotification(NotificationsCompanion entry) {
    return into(notifications).insert(entry);
  }

  /// Marque une notification comme lue
  Future<int> markRead(int id) {
    return (update(notifications)..where((t) => t.id.equals(id)))
        .write(NotificationsCompanion(isRead: const Value(true)));
  }

  /// Supprime une notification
  Future<int> deleteNotification(int id) {
    return (delete(notifications)..where((t) => t.id.equals(id))).go();
  }
}

extension NotificationStreams on NotificationDao {
  /// Renvoie un Stream qui émet à chaque changement de la table
  Stream<List<Notification>> watchForGroup(String group) {
    return (select(notifications)
      ..where((tbl) => tbl.group.equals(group))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
        .watch();
  }
}
