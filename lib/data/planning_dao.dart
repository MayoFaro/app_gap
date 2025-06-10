// lib/data/planning_dao.dart
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'planning_dao.g.dart';

@DriftAccessor(tables: [PlanningEvents])
class PlanningDao extends DatabaseAccessor<AppDatabase> with _$PlanningDaoMixin {
  PlanningDao(super.db);

  /// Récupère tous les événements du planning
  Future<List<PlanningEvent>> getAllEvents() => select(planningEvents).get();

  /// Insère un nouvel événement
  Future<int> insertEvent(PlanningEventsCompanion entry) => into(planningEvents).insert(entry);

  /// Met à jour un événement existant
  Future<bool> updateEvent(PlanningEvent event) => update(planningEvents).replace(event);

  /// Supprime un événement par ID
  Future<int> deleteEvent(int id) =>
      (delete(planningEvents)..where((tbl) => tbl.id.equals(id))).go();
}
