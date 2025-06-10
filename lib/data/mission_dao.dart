// lib/data/mission_dao.dart
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'mission_dao.g.dart';

@DriftAccessor(tables: [Missions])
class MissionDao extends DatabaseAccessor<AppDatabase> with _$MissionDaoMixin {
  MissionDao(super.db);

  Future<List<Mission>> getAllMissions() => select(missions).get();
  Future<int> insertMission(MissionsCompanion entry) => into(missions).insert(entry);
  Future updateMission(Mission m) => update(missions).replace(m);
  Future deleteMission(int id) =>
      (delete(missions)..where((tbl) => tbl.id.equals(id))).go();
}
