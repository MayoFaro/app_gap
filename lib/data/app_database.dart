// lib/data/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Table des utilisateurs avec droits d'administration
class Users extends Table {
  TextColumn get trigramme    => text().withLength(min: 3, max: 3)();
  TextColumn get passwordHash => text().withLength(min: 4, max: 4)();
  TextColumn get role         => text().withLength(min: 3, max: 15)();
  TextColumn get group        => text().withLength(min: 4, max: 6)();
  TextColumn get fullName     => text().nullable()();
  TextColumn get phone        => text().nullable()();
  TextColumn get email        => text().nullable()();
  BoolColumn get isAdmin      => boolean().withDefault(const Constant(false))();

  @override Set<Column> get primaryKey => {trigramme};
}

// Table des missions
class Missions extends Table {
  IntColumn get id               => integer().autoIncrement()();
  DateTimeColumn get date        => dateTime()();
  TextColumn get hourStart       => text()();
  TextColumn get hourEnd         => text()();
  TextColumn get vecteur         => text().withLength(min: 4, max: 6)();
  TextColumn get destinationCode => text().withLength(min: 4, max: 4)();
  TextColumn get description     => text().withLength(max: 50).nullable()();
  TextColumn get createdBy       => text().withLength(min: 3, max: 3)();
  TextColumn get pilote1         => text().withLength(min: 3, max: 3)();
  TextColumn get pilote2         => text().withLength(min: 3, max: 3).nullable()();
  TextColumn get mec1            => text().withLength(min: 3, max: 3).nullable()();
  TextColumn get mec2            => text().withLength(min: 3, max: 3).nullable()();
  DateTimeColumn get actualDeparture => dateTime().nullable()();
  DateTimeColumn get actualArrival   => dateTime().nullable()();
}

// Table du planning
class PlanningEvents extends Table {
  IntColumn get id          => integer().autoIncrement()();
  TextColumn get user       => text().withLength(min: 3, max: 3)();
  DateTimeColumn get dateStart => dateTime()();
  DateTimeColumn get dateEnd   => dateTime()();
  TextColumn get typeEvent  => text().withLength(min: 2, max: 4)();
  TextColumn get description=> text().withLength(max: 50).nullable()();
}

// Table des terrains
class Airports extends Table {
  TextColumn get code => text().withLength(min: 4, max: 4)();
  TextColumn get name => text().withLength(max: 100)();
  @override Set<Column> get primaryKey => {code};
}

// Table des notifications
class Notifications extends Table {
  IntColumn get id          => integer().autoIncrement()();
  TextColumn get group      => text().withLength(min: 4, max: 6)();
  TextColumn get type       => text().withLength(min: 1, max: 20)();
  TextColumn get originator => text().withLength(min: 3, max: 3)();
  TextColumn get payload    => text().nullable()();
  BoolColumn get isRead     => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime()();
}

// Table des messages du chef
class ChefMessages extends Table {
  IntColumn get id         => integer().autoIncrement()();
  TextColumn get content    => text().nullable()();
  TextColumn get authorRole => text().withLength(min: 3, max: 15)();
  TextColumn get group      => text().withLength(min: 4, max: 6)();
  DateTimeColumn get timestamp => dateTime()();
}

@DriftDatabase(
  tables: [Users, Missions, PlanningEvents, Airports, Notifications, ChefMessages],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // Version 2 inclut isAdmin
}

// Ouvre la base de données (SQLite) stockée localement
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_db.sqlite'));
    return NativeDatabase(file);
  });
}

/*
Pour appliquer ce schéma "from scratch" :
1) Supprime tout fichier existant 'app_db.sqlite'.
2) Regénère le code Drift :
   flutter pub run build_runner build --delete-conflicting-outputs
3) Lance l'application, la base sera recréée avec toutes les tables et colonnes.
*/
