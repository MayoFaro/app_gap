// lib/data/app_database.dart
//
// Base de données Drift (locale). On ajoute :
//  - PlanningEvents.rank (nullable) pour l'ordre intra-journée des TWR
//  - (déjà présent) PlanningEvents.uid et PlanningEvents.firestoreId pour la synchro Firestore
//
// ✅ schemaVersion passe à 8 avec migration qui ajoute la colonne "rank" si besoin.

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
  TextColumn get fonction     => text().withLength(min: 3, max: 15)();
  TextColumn get role         => text().withLength(min: 3, max: 15)();
  TextColumn get group        => text().withLength(min: 4, max: 6)();
  TextColumn get fullName     => text().nullable()();
  TextColumn get phone        => text().nullable()();
  TextColumn get email        => text().nullable()();
  BoolColumn  get isAdmin     => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {trigramme};
}

/// Table des missions (vols)
class Missions extends Table {
  IntColumn      get id               => integer().autoIncrement()();
  DateTimeColumn get date             => dateTime()();
  TextColumn     get vecteur          => text()();
  TextColumn     get pilote1          => text()();
  TextColumn     get pilote2          => text().nullable()();
  TextColumn     get pilote3          => text().nullable()();
  TextColumn     get destinationCode  => text()();
  TextColumn     get description      => text().nullable()();
  DateTimeColumn get actualDeparture  => dateTime().nullable()();
  DateTimeColumn get actualArrival    => dateTime().nullable()();
  TextColumn     get remoteId         => text().nullable()(); // id du doc Firestore
  DateTimeColumn get createdAt        =>
      dateTime().withDefault(currentDateAndTime)(); // set côté local
  DateTimeColumn get updatedAt        => dateTime().nullable()(); // MAJ locales

  /// Nouveau champ: synchro Firestore
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn     get hourStart        => text().nullable()();
}


/// Table des événements de planification
///
/// Champs spécifiques à la synchro Firestore :
///  - uid         : UID FirebaseAuth (qui part dans Firestore -> field 'user')
///  - firestoreId : id du document Firestore correspondant (nullable si offline)
///  - rank        : rang intra-journée (1..3) pour les TWR (nullable pour les autres types)
class PlanningEvents extends Table {
  IntColumn      get id          => integer().autoIncrement()();
  TextColumn     get user        => text().withLength(min: 3, max: 3)(); // trigramme local
  TextColumn     get typeEvent   => text().withLength(min: 2, max: 4)();
  DateTimeColumn get dateStart   => dateTime()();
  DateTimeColumn get dateEnd     => dateTime()();

  // Synchro Firestore
  TextColumn     get uid         => text().withLength(min: 1, max: 64)
      .withDefault(const Constant(''))();
  TextColumn     get firestoreId => text().nullable()();

  // Rang TWR (1,2,3). Nullable car inutile pour les autres types.
  IntColumn      get rank        => integer().nullable()();
}

/// Table des messages du chef
// lib/data/chef_message_tables.dart
//
// Tables Drift pour les "messages du chef" et leurs ACKs.
// - ChefMessages : messages publiés par les chefs/CDT
// - ChefMessageAcks : accusés de lecture (un par trigramme)
//
// Remarques :
// - remoteId : id du doc Firestore (permet l'upsert côté sync)
// - La colonne SQL est nommée 'grp' pour éviter tout conflit avec le mot-clé SQL GROUP
//   mais exposée en tant que 'group' côté Dart.


class ChefMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Id du document Firestore
  TextColumn get remoteId => text().unique()(); // not null + unique

  // Contenu texte libre
  TextColumn get content => text()();

  // Groupe ciblé: 'tous' | 'avion' | 'helico'
  TextColumn get group => text().named('grp')(); // colonne SQL 'grp', champ Dart 'group'

  // Auteur (trigramme), et rôle affiché ('chef' | 'cdt')
  TextColumn get author => text()();
  TextColumn get authorRole => text()();

  // Horodatages (server-side en Firestore ; on les recopie ici)
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class ChefMessageAcks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get messageId =>
      integer().references(ChefMessages, #id, onDelete: KeyAction.cascade)();

  TextColumn get trigramme => text()();
  TextColumn get uid => text().nullable()();

  DateTimeColumn get seenAt =>
      dateTime().withDefault(currentDateAndTime)();

  // Un seul ACK par (message, trigramme)
  @override
  List<Set<Column>> get uniqueKeys => [
    {messageId, trigramme}
  ];
}


/// Table des notifications
class Notifications extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  TextColumn     get type      => text().withLength(min: 1, max: 20)();
  TextColumn     get payload   => text().nullable()();
  TextColumn     get group     => text().withLength(min: 4, max: 6)();
  BoolColumn     get isRead    => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

/// Table des aéroports
class Airports extends Table {
  TextColumn get code => text().withLength(min: 4, max: 4)();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {code};
}

@DriftDatabase(
  tables: [
    Users,
    Missions,
    ChefMessageAcks,
    PlanningEvents,
    ChefMessages,
    Notifications,
    Airports,
  ],
  daos: [
    MissionDao,
    PlanningDao,
    ChefMessageDao,
    NotificationDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  // En test, DB en mémoire
  AppDatabase() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 10; // <- bump (ajout de rank)

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 7) {
        await m.addColumn(planningEvents, planningEvents.uid);
        await m.addColumn(planningEvents, planningEvents.firestoreId);
      }
      if (from < 8) {
        await m.addColumn(planningEvents, planningEvents.rank);
      }
      if (from < 9) {
        await m.addColumn(missions, missions.remoteId);
        await m.addColumn(missions, missions.createdAt);
        await m.addColumn(missions, missions.updatedAt);
      }
      if (from < 10) {
        await m.addColumn(missions, missions.isSynced);
        await m.addColumn(missions, missions.hourStart); // ajout du champ
      }
      await m.createAll();
    },
  );
}

/// (Prod) Ouvre une DB fichier
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_gap.sqlite'));
    return NativeDatabase(file);
  });
}
