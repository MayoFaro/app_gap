// lib/data/planning_dao.dart

import 'package:drift/drift.dart';
import 'app_database.dart';

part 'planning_dao.g.dart';

@DriftAccessor(tables: [Users, PlanningEvents])
class PlanningDao extends DatabaseAccessor<AppDatabase> with _$PlanningDaoMixin {
  PlanningDao(AppDatabase db) : super(db);

  /// Écoute en temps réel les événements pour un utilisateur donné.
  Stream<List<PlanningEvent>> watchEventsForUser(String user) {
    return (select(planningEvents)
      ..where((e) => e.user.equals(user)))
        .watch();
  }

  /// Insère un événement (1-day ou X-days).
  Future<void> insertEvent({
    required String user,
    required String typeEvent,
    required DateTime dateStart,
    required DateTime dateEnd,
  }) {
    return into(planningEvents).insert(
      PlanningEventsCompanion.insert(
        user: user,
        typeEvent: typeEvent,
        dateStart: dateStart,
        dateEnd: dateEnd,
      ),
    );
  }

  /// Met à jour les bornes d’un événement existant.
  /// Retourne le nombre de lignes affectées.
  Future<int> updateEvent({
    required int id,
    required DateTime dateStart,
    required DateTime dateEnd,
  }) {
    return (update(planningEvents)..where((e) => e.id.equals(id))).write(
      PlanningEventsCompanion(
        dateStart: Value(dateStart),
        dateEnd: Value(dateEnd),
      ),
    );
  }

  /// Supprime un événement par son identifiant.
  Future<int> deleteEvent(int id) {
    return (delete(planningEvents)..where((e) => e.id.equals(id))).go();
  }
}
