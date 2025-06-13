import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'mission_dao.dart';
import 'planning_dao.dart';
import 'chef_message_dao.dart';
import 'notification_dao.dart';

part 'app_database.g.dart';

/// Table des utilisateurs
class Users extends Table {
  TextColumn get trigramme    => text().withLength(min: 3, max: 3)();
  TextColumn get passwordHash => text().withLength(min: 4, max: 4)();
  TextColumn get fonction     => text().withLength(min: 3, max: 15)();
  TextColumn get role         => text().withLength(min: 3, max: 15)();
  TextColumn get group        => text().withLength(min: 4, max: 6)();
  TextColumn get fullName     => text().nullable()();
  TextColumn get phone        => text().nullable()();
  TextColumn get email        => text().nullable()();
  BoolColumn get isAdmin      => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {trigramme};
}

/// Table des missions (vols)
class Missions extends Table {
  IntColumn get id               => integer().autoIncrement()();
  DateTimeColumn get date        => dateTime()();
  TextColumn get vecteur         => text()();
  TextColumn get pilote1         => text()();
  TextColumn get pilote2         => text().nullable()();
  TextColumn get destinationCode => text()();
  TextColumn get description     => text().nullable()();
}

/// Table des événements de planification
class PlanningEvents extends Table {
  IntColumn get id         => integer().autoIncrement()();
  TextColumn get user      => text().withLength(min: 3, max: 3)();
  TextColumn get typeEvent => text().withLength(min: 2, max: 4)();
  DateTimeColumn get dateStart => dateTime()();
  DateTimeColumn get dateEnd   => dateTime()();
}

/// Table des messages du chef
class ChefMessages extends Table {
  IntColumn get id            => integer().autoIncrement()();
  TextColumn get content      => text().withLength(min: 1, max: 500)();
  TextColumn get authorRole   => text().withLength(min: 3, max: 15)();
  TextColumn get group        => text().withLength(min: 4, max: 6)();
  DateTimeColumn get timestamp=> dateTime().withDefault(currentDateAndTime)();
}

/// Table des notifications
class Notifications extends Table {
  IntColumn get id         => integer().autoIncrement()();
  TextColumn get type      => text().withLength(min: 1, max: 20)();
  TextColumn get payload   => text().nullable()();
  TextColumn get group     => text().withLength(min: 4, max: 6)();
  BoolColumn get isRead    => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

/// Base de données principale pour appGAP
@DriftDatabase(
  tables: [
    Users,
    Missions,
    PlanningEvents,
    ChefMessages,
    Notifications,
  ],
  daos: [
    MissionDao,
    PlanningDao,
    ChefMessageDao,
    NotificationDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Recréation automatique des tables manquantes et des colonnes
      await m.createAll();
    },
  );
}

/// Ouvre la connexion vers le fichier SQLite local
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_gap.sqlite'));
    return NativeDatabase(file);
  });
}
