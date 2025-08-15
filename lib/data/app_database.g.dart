// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trigrammeMeta =
      const VerificationMeta('trigramme');
  @override
  late final GeneratedColumn<String> trigramme = GeneratedColumn<String>(
      'trigramme', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 3),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _fonctionMeta =
      const VerificationMeta('fonction');
  @override
  late final GeneratedColumn<String> fonction = GeneratedColumn<String>(
      'fonction', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 15),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 15),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
      'group', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 4, maxTextLength: 6),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _fullNameMeta =
      const VerificationMeta('fullName');
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
      'full_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAdminMeta =
      const VerificationMeta('isAdmin');
  @override
  late final GeneratedColumn<bool> isAdmin = GeneratedColumn<bool>(
      'is_admin', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_admin" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [trigramme, fonction, role, group, fullName, phone, email, isAdmin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trigramme')) {
      context.handle(_trigrammeMeta,
          trigramme.isAcceptableOrUnknown(data['trigramme']!, _trigrammeMeta));
    } else if (isInserting) {
      context.missing(_trigrammeMeta);
    }
    if (data.containsKey('fonction')) {
      context.handle(_fonctionMeta,
          fonction.isAcceptableOrUnknown(data['fonction']!, _fonctionMeta));
    } else if (isInserting) {
      context.missing(_fonctionMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('group')) {
      context.handle(
          _groupMeta, group.isAcceptableOrUnknown(data['group']!, _groupMeta));
    } else if (isInserting) {
      context.missing(_groupMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(_fullNameMeta,
          fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('is_admin')) {
      context.handle(_isAdminMeta,
          isAdmin.isAcceptableOrUnknown(data['is_admin']!, _isAdminMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trigramme};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      trigramme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trigramme'])!,
      fonction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fonction'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      group: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group'])!,
      fullName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_name']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      isAdmin: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_admin'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String trigramme;
  final String fonction;
  final String role;
  final String group;
  final String? fullName;
  final String? phone;
  final String? email;
  final bool isAdmin;
  const User(
      {required this.trigramme,
      required this.fonction,
      required this.role,
      required this.group,
      this.fullName,
      this.phone,
      this.email,
      required this.isAdmin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trigramme'] = Variable<String>(trigramme);
    map['fonction'] = Variable<String>(fonction);
    map['role'] = Variable<String>(role);
    map['group'] = Variable<String>(group);
    if (!nullToAbsent || fullName != null) {
      map['full_name'] = Variable<String>(fullName);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['is_admin'] = Variable<bool>(isAdmin);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      trigramme: Value(trigramme),
      fonction: Value(fonction),
      role: Value(role),
      group: Value(group),
      fullName: fullName == null && nullToAbsent
          ? const Value.absent()
          : Value(fullName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      isAdmin: Value(isAdmin),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      trigramme: serializer.fromJson<String>(json['trigramme']),
      fonction: serializer.fromJson<String>(json['fonction']),
      role: serializer.fromJson<String>(json['role']),
      group: serializer.fromJson<String>(json['group']),
      fullName: serializer.fromJson<String?>(json['fullName']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      isAdmin: serializer.fromJson<bool>(json['isAdmin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trigramme': serializer.toJson<String>(trigramme),
      'fonction': serializer.toJson<String>(fonction),
      'role': serializer.toJson<String>(role),
      'group': serializer.toJson<String>(group),
      'fullName': serializer.toJson<String?>(fullName),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'isAdmin': serializer.toJson<bool>(isAdmin),
    };
  }

  User copyWith(
          {String? trigramme,
          String? fonction,
          String? role,
          String? group,
          Value<String?> fullName = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> email = const Value.absent(),
          bool? isAdmin}) =>
      User(
        trigramme: trigramme ?? this.trigramme,
        fonction: fonction ?? this.fonction,
        role: role ?? this.role,
        group: group ?? this.group,
        fullName: fullName.present ? fullName.value : this.fullName,
        phone: phone.present ? phone.value : this.phone,
        email: email.present ? email.value : this.email,
        isAdmin: isAdmin ?? this.isAdmin,
      );
  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('trigramme: $trigramme, ')
          ..write('fonction: $fonction, ')
          ..write('role: $role, ')
          ..write('group: $group, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('isAdmin: $isAdmin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      trigramme, fonction, role, group, fullName, phone, email, isAdmin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.trigramme == this.trigramme &&
          other.fonction == this.fonction &&
          other.role == this.role &&
          other.group == this.group &&
          other.fullName == this.fullName &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.isAdmin == this.isAdmin);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> trigramme;
  final Value<String> fonction;
  final Value<String> role;
  final Value<String> group;
  final Value<String?> fullName;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<bool> isAdmin;
  final Value<int> rowid;
  const UsersCompanion({
    this.trigramme = const Value.absent(),
    this.fonction = const Value.absent(),
    this.role = const Value.absent(),
    this.group = const Value.absent(),
    this.fullName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String trigramme,
    required String fonction,
    required String role,
    required String group,
    this.fullName = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : trigramme = Value(trigramme),
        fonction = Value(fonction),
        role = Value(role),
        group = Value(group);
  static Insertable<User> custom({
    Expression<String>? trigramme,
    Expression<String>? fonction,
    Expression<String>? role,
    Expression<String>? group,
    Expression<String>? fullName,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<bool>? isAdmin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trigramme != null) 'trigramme': trigramme,
      if (fonction != null) 'fonction': fonction,
      if (role != null) 'role': role,
      if (group != null) 'group': group,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (isAdmin != null) 'is_admin': isAdmin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? trigramme,
      Value<String>? fonction,
      Value<String>? role,
      Value<String>? group,
      Value<String?>? fullName,
      Value<String?>? phone,
      Value<String?>? email,
      Value<bool>? isAdmin,
      Value<int>? rowid}) {
    return UsersCompanion(
      trigramme: trigramme ?? this.trigramme,
      fonction: fonction ?? this.fonction,
      role: role ?? this.role,
      group: group ?? this.group,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trigramme.present) {
      map['trigramme'] = Variable<String>(trigramme.value);
    }
    if (fonction.present) {
      map['fonction'] = Variable<String>(fonction.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (isAdmin.present) {
      map['is_admin'] = Variable<bool>(isAdmin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('trigramme: $trigramme, ')
          ..write('fonction: $fonction, ')
          ..write('role: $role, ')
          ..write('group: $group, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MissionsTable extends Missions with TableInfo<$MissionsTable, Mission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _vecteurMeta =
      const VerificationMeta('vecteur');
  @override
  late final GeneratedColumn<String> vecteur = GeneratedColumn<String>(
      'vecteur', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pilote1Meta =
      const VerificationMeta('pilote1');
  @override
  late final GeneratedColumn<String> pilote1 = GeneratedColumn<String>(
      'pilote1', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pilote2Meta =
      const VerificationMeta('pilote2');
  @override
  late final GeneratedColumn<String> pilote2 = GeneratedColumn<String>(
      'pilote2', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pilote3Meta =
      const VerificationMeta('pilote3');
  @override
  late final GeneratedColumn<String> pilote3 = GeneratedColumn<String>(
      'pilote3', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _destinationCodeMeta =
      const VerificationMeta('destinationCode');
  @override
  late final GeneratedColumn<String> destinationCode = GeneratedColumn<String>(
      'destination_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actualDepartureMeta =
      const VerificationMeta('actualDeparture');
  @override
  late final GeneratedColumn<DateTime> actualDeparture =
      GeneratedColumn<DateTime>('actual_departure', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _actualArrivalMeta =
      const VerificationMeta('actualArrival');
  @override
  late final GeneratedColumn<DateTime> actualArrival =
      GeneratedColumn<DateTime>('actual_arrival', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        date,
        vecteur,
        pilote1,
        pilote2,
        pilote3,
        destinationCode,
        description,
        actualDeparture,
        actualArrival,
        remoteId,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missions';
  @override
  VerificationContext validateIntegrity(Insertable<Mission> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('vecteur')) {
      context.handle(_vecteurMeta,
          vecteur.isAcceptableOrUnknown(data['vecteur']!, _vecteurMeta));
    } else if (isInserting) {
      context.missing(_vecteurMeta);
    }
    if (data.containsKey('pilote1')) {
      context.handle(_pilote1Meta,
          pilote1.isAcceptableOrUnknown(data['pilote1']!, _pilote1Meta));
    } else if (isInserting) {
      context.missing(_pilote1Meta);
    }
    if (data.containsKey('pilote2')) {
      context.handle(_pilote2Meta,
          pilote2.isAcceptableOrUnknown(data['pilote2']!, _pilote2Meta));
    }
    if (data.containsKey('pilote3')) {
      context.handle(_pilote3Meta,
          pilote3.isAcceptableOrUnknown(data['pilote3']!, _pilote3Meta));
    }
    if (data.containsKey('destination_code')) {
      context.handle(
          _destinationCodeMeta,
          destinationCode.isAcceptableOrUnknown(
              data['destination_code']!, _destinationCodeMeta));
    } else if (isInserting) {
      context.missing(_destinationCodeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('actual_departure')) {
      context.handle(
          _actualDepartureMeta,
          actualDeparture.isAcceptableOrUnknown(
              data['actual_departure']!, _actualDepartureMeta));
    }
    if (data.containsKey('actual_arrival')) {
      context.handle(
          _actualArrivalMeta,
          actualArrival.isAcceptableOrUnknown(
              data['actual_arrival']!, _actualArrivalMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mission(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      vecteur: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vecteur'])!,
      pilote1: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pilote1'])!,
      pilote2: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pilote2']),
      pilote3: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pilote3']),
      destinationCode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}destination_code'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      actualDeparture: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}actual_departure']),
      actualArrival: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}actual_arrival']),
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $MissionsTable createAlias(String alias) {
    return $MissionsTable(attachedDatabase, alias);
  }
}

class Mission extends DataClass implements Insertable<Mission> {
  final int id;
  final DateTime date;
  final String vecteur;
  final String pilote1;
  final String? pilote2;
  final String? pilote3;
  final String destinationCode;
  final String? description;
  final DateTime? actualDeparture;
  final DateTime? actualArrival;
  final String? remoteId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const Mission(
      {required this.id,
      required this.date,
      required this.vecteur,
      required this.pilote1,
      this.pilote2,
      this.pilote3,
      required this.destinationCode,
      this.description,
      this.actualDeparture,
      this.actualArrival,
      this.remoteId,
      required this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['vecteur'] = Variable<String>(vecteur);
    map['pilote1'] = Variable<String>(pilote1);
    if (!nullToAbsent || pilote2 != null) {
      map['pilote2'] = Variable<String>(pilote2);
    }
    if (!nullToAbsent || pilote3 != null) {
      map['pilote3'] = Variable<String>(pilote3);
    }
    map['destination_code'] = Variable<String>(destinationCode);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || actualDeparture != null) {
      map['actual_departure'] = Variable<DateTime>(actualDeparture);
    }
    if (!nullToAbsent || actualArrival != null) {
      map['actual_arrival'] = Variable<DateTime>(actualArrival);
    }
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  MissionsCompanion toCompanion(bool nullToAbsent) {
    return MissionsCompanion(
      id: Value(id),
      date: Value(date),
      vecteur: Value(vecteur),
      pilote1: Value(pilote1),
      pilote2: pilote2 == null && nullToAbsent
          ? const Value.absent()
          : Value(pilote2),
      pilote3: pilote3 == null && nullToAbsent
          ? const Value.absent()
          : Value(pilote3),
      destinationCode: Value(destinationCode),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      actualDeparture: actualDeparture == null && nullToAbsent
          ? const Value.absent()
          : Value(actualDeparture),
      actualArrival: actualArrival == null && nullToAbsent
          ? const Value.absent()
          : Value(actualArrival),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Mission.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mission(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      vecteur: serializer.fromJson<String>(json['vecteur']),
      pilote1: serializer.fromJson<String>(json['pilote1']),
      pilote2: serializer.fromJson<String?>(json['pilote2']),
      pilote3: serializer.fromJson<String?>(json['pilote3']),
      destinationCode: serializer.fromJson<String>(json['destinationCode']),
      description: serializer.fromJson<String?>(json['description']),
      actualDeparture: serializer.fromJson<DateTime?>(json['actualDeparture']),
      actualArrival: serializer.fromJson<DateTime?>(json['actualArrival']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'vecteur': serializer.toJson<String>(vecteur),
      'pilote1': serializer.toJson<String>(pilote1),
      'pilote2': serializer.toJson<String?>(pilote2),
      'pilote3': serializer.toJson<String?>(pilote3),
      'destinationCode': serializer.toJson<String>(destinationCode),
      'description': serializer.toJson<String?>(description),
      'actualDeparture': serializer.toJson<DateTime?>(actualDeparture),
      'actualArrival': serializer.toJson<DateTime?>(actualArrival),
      'remoteId': serializer.toJson<String?>(remoteId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Mission copyWith(
          {int? id,
          DateTime? date,
          String? vecteur,
          String? pilote1,
          Value<String?> pilote2 = const Value.absent(),
          Value<String?> pilote3 = const Value.absent(),
          String? destinationCode,
          Value<String?> description = const Value.absent(),
          Value<DateTime?> actualDeparture = const Value.absent(),
          Value<DateTime?> actualArrival = const Value.absent(),
          Value<String?> remoteId = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      Mission(
        id: id ?? this.id,
        date: date ?? this.date,
        vecteur: vecteur ?? this.vecteur,
        pilote1: pilote1 ?? this.pilote1,
        pilote2: pilote2.present ? pilote2.value : this.pilote2,
        pilote3: pilote3.present ? pilote3.value : this.pilote3,
        destinationCode: destinationCode ?? this.destinationCode,
        description: description.present ? description.value : this.description,
        actualDeparture: actualDeparture.present
            ? actualDeparture.value
            : this.actualDeparture,
        actualArrival:
            actualArrival.present ? actualArrival.value : this.actualArrival,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  @override
  String toString() {
    return (StringBuffer('Mission(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('vecteur: $vecteur, ')
          ..write('pilote1: $pilote1, ')
          ..write('pilote2: $pilote2, ')
          ..write('pilote3: $pilote3, ')
          ..write('destinationCode: $destinationCode, ')
          ..write('description: $description, ')
          ..write('actualDeparture: $actualDeparture, ')
          ..write('actualArrival: $actualArrival, ')
          ..write('remoteId: $remoteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      date,
      vecteur,
      pilote1,
      pilote2,
      pilote3,
      destinationCode,
      description,
      actualDeparture,
      actualArrival,
      remoteId,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mission &&
          other.id == this.id &&
          other.date == this.date &&
          other.vecteur == this.vecteur &&
          other.pilote1 == this.pilote1 &&
          other.pilote2 == this.pilote2 &&
          other.pilote3 == this.pilote3 &&
          other.destinationCode == this.destinationCode &&
          other.description == this.description &&
          other.actualDeparture == this.actualDeparture &&
          other.actualArrival == this.actualArrival &&
          other.remoteId == this.remoteId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MissionsCompanion extends UpdateCompanion<Mission> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> vecteur;
  final Value<String> pilote1;
  final Value<String?> pilote2;
  final Value<String?> pilote3;
  final Value<String> destinationCode;
  final Value<String?> description;
  final Value<DateTime?> actualDeparture;
  final Value<DateTime?> actualArrival;
  final Value<String?> remoteId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const MissionsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.vecteur = const Value.absent(),
    this.pilote1 = const Value.absent(),
    this.pilote2 = const Value.absent(),
    this.pilote3 = const Value.absent(),
    this.destinationCode = const Value.absent(),
    this.description = const Value.absent(),
    this.actualDeparture = const Value.absent(),
    this.actualArrival = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MissionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String vecteur,
    required String pilote1,
    this.pilote2 = const Value.absent(),
    this.pilote3 = const Value.absent(),
    required String destinationCode,
    this.description = const Value.absent(),
    this.actualDeparture = const Value.absent(),
    this.actualArrival = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : date = Value(date),
        vecteur = Value(vecteur),
        pilote1 = Value(pilote1),
        destinationCode = Value(destinationCode);
  static Insertable<Mission> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? vecteur,
    Expression<String>? pilote1,
    Expression<String>? pilote2,
    Expression<String>? pilote3,
    Expression<String>? destinationCode,
    Expression<String>? description,
    Expression<DateTime>? actualDeparture,
    Expression<DateTime>? actualArrival,
    Expression<String>? remoteId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (vecteur != null) 'vecteur': vecteur,
      if (pilote1 != null) 'pilote1': pilote1,
      if (pilote2 != null) 'pilote2': pilote2,
      if (pilote3 != null) 'pilote3': pilote3,
      if (destinationCode != null) 'destination_code': destinationCode,
      if (description != null) 'description': description,
      if (actualDeparture != null) 'actual_departure': actualDeparture,
      if (actualArrival != null) 'actual_arrival': actualArrival,
      if (remoteId != null) 'remote_id': remoteId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MissionsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? date,
      Value<String>? vecteur,
      Value<String>? pilote1,
      Value<String?>? pilote2,
      Value<String?>? pilote3,
      Value<String>? destinationCode,
      Value<String?>? description,
      Value<DateTime?>? actualDeparture,
      Value<DateTime?>? actualArrival,
      Value<String?>? remoteId,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return MissionsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      vecteur: vecteur ?? this.vecteur,
      pilote1: pilote1 ?? this.pilote1,
      pilote2: pilote2 ?? this.pilote2,
      pilote3: pilote3 ?? this.pilote3,
      destinationCode: destinationCode ?? this.destinationCode,
      description: description ?? this.description,
      actualDeparture: actualDeparture ?? this.actualDeparture,
      actualArrival: actualArrival ?? this.actualArrival,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (vecteur.present) {
      map['vecteur'] = Variable<String>(vecteur.value);
    }
    if (pilote1.present) {
      map['pilote1'] = Variable<String>(pilote1.value);
    }
    if (pilote2.present) {
      map['pilote2'] = Variable<String>(pilote2.value);
    }
    if (pilote3.present) {
      map['pilote3'] = Variable<String>(pilote3.value);
    }
    if (destinationCode.present) {
      map['destination_code'] = Variable<String>(destinationCode.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (actualDeparture.present) {
      map['actual_departure'] = Variable<DateTime>(actualDeparture.value);
    }
    if (actualArrival.present) {
      map['actual_arrival'] = Variable<DateTime>(actualArrival.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissionsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('vecteur: $vecteur, ')
          ..write('pilote1: $pilote1, ')
          ..write('pilote2: $pilote2, ')
          ..write('pilote3: $pilote3, ')
          ..write('destinationCode: $destinationCode, ')
          ..write('description: $description, ')
          ..write('actualDeparture: $actualDeparture, ')
          ..write('actualArrival: $actualArrival, ')
          ..write('remoteId: $remoteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ChefMessagesTable extends ChefMessages
    with TableInfo<$ChefMessagesTable, ChefMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChefMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 500),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _authorRoleMeta =
      const VerificationMeta('authorRole');
  @override
  late final GeneratedColumn<String> authorRole = GeneratedColumn<String>(
      'author_role', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 15),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
      'group', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 4, maxTextLength: 6),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, content, authorRole, group, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chef_messages';
  @override
  VerificationContext validateIntegrity(Insertable<ChefMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('author_role')) {
      context.handle(
          _authorRoleMeta,
          authorRole.isAcceptableOrUnknown(
              data['author_role']!, _authorRoleMeta));
    } else if (isInserting) {
      context.missing(_authorRoleMeta);
    }
    if (data.containsKey('group')) {
      context.handle(
          _groupMeta, group.isAcceptableOrUnknown(data['group']!, _groupMeta));
    } else if (isInserting) {
      context.missing(_groupMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChefMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChefMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      authorRole: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_role'])!,
      group: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $ChefMessagesTable createAlias(String alias) {
    return $ChefMessagesTable(attachedDatabase, alias);
  }
}

class ChefMessage extends DataClass implements Insertable<ChefMessage> {
  final int id;
  final String content;
  final String authorRole;
  final String group;
  final DateTime timestamp;
  const ChefMessage(
      {required this.id,
      required this.content,
      required this.authorRole,
      required this.group,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['author_role'] = Variable<String>(authorRole);
    map['group'] = Variable<String>(group);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  ChefMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChefMessagesCompanion(
      id: Value(id),
      content: Value(content),
      authorRole: Value(authorRole),
      group: Value(group),
      timestamp: Value(timestamp),
    );
  }

  factory ChefMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChefMessage(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      authorRole: serializer.fromJson<String>(json['authorRole']),
      group: serializer.fromJson<String>(json['group']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'authorRole': serializer.toJson<String>(authorRole),
      'group': serializer.toJson<String>(group),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  ChefMessage copyWith(
          {int? id,
          String? content,
          String? authorRole,
          String? group,
          DateTime? timestamp}) =>
      ChefMessage(
        id: id ?? this.id,
        content: content ?? this.content,
        authorRole: authorRole ?? this.authorRole,
        group: group ?? this.group,
        timestamp: timestamp ?? this.timestamp,
      );
  @override
  String toString() {
    return (StringBuffer('ChefMessage(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('authorRole: $authorRole, ')
          ..write('group: $group, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, authorRole, group, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChefMessage &&
          other.id == this.id &&
          other.content == this.content &&
          other.authorRole == this.authorRole &&
          other.group == this.group &&
          other.timestamp == this.timestamp);
}

class ChefMessagesCompanion extends UpdateCompanion<ChefMessage> {
  final Value<int> id;
  final Value<String> content;
  final Value<String> authorRole;
  final Value<String> group;
  final Value<DateTime> timestamp;
  const ChefMessagesCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.authorRole = const Value.absent(),
    this.group = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  ChefMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    required String authorRole,
    required String group,
    this.timestamp = const Value.absent(),
  })  : content = Value(content),
        authorRole = Value(authorRole),
        group = Value(group);
  static Insertable<ChefMessage> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<String>? authorRole,
    Expression<String>? group,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (authorRole != null) 'author_role': authorRole,
      if (group != null) 'group': group,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  ChefMessagesCompanion copyWith(
      {Value<int>? id,
      Value<String>? content,
      Value<String>? authorRole,
      Value<String>? group,
      Value<DateTime>? timestamp}) {
    return ChefMessagesCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      authorRole: authorRole ?? this.authorRole,
      group: group ?? this.group,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (authorRole.present) {
      map['author_role'] = Variable<String>(authorRole.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChefMessagesCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('authorRole: $authorRole, ')
          ..write('group: $group, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $ChefMessageAcksTable extends ChefMessageAcks
    with TableInfo<$ChefMessageAcksTable, ChefMessageAck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChefMessageAcksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
      'message_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES chef_messages(id)');
  static const VerificationMeta _trigrammeMeta =
      const VerificationMeta('trigramme');
  @override
  late final GeneratedColumn<String> trigramme = GeneratedColumn<String>(
      'trigramme', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 10),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<DateTime> seenAt = GeneratedColumn<DateTime>(
      'seen_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, messageId, trigramme, seenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chef_message_acks';
  @override
  VerificationContext validateIntegrity(Insertable<ChefMessageAck> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('trigramme')) {
      context.handle(_trigrammeMeta,
          trigramme.isAcceptableOrUnknown(data['trigramme']!, _trigrammeMeta));
    } else if (isInserting) {
      context.missing(_trigrammeMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(_seenAtMeta,
          seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChefMessageAck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChefMessageAck(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}message_id'])!,
      trigramme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trigramme'])!,
      seenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}seen_at'])!,
    );
  }

  @override
  $ChefMessageAcksTable createAlias(String alias) {
    return $ChefMessageAcksTable(attachedDatabase, alias);
  }
}

class ChefMessageAck extends DataClass implements Insertable<ChefMessageAck> {
  final int id;
  final int messageId;
  final String trigramme;
  final DateTime seenAt;
  const ChefMessageAck(
      {required this.id,
      required this.messageId,
      required this.trigramme,
      required this.seenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<int>(messageId);
    map['trigramme'] = Variable<String>(trigramme);
    map['seen_at'] = Variable<DateTime>(seenAt);
    return map;
  }

  ChefMessageAcksCompanion toCompanion(bool nullToAbsent) {
    return ChefMessageAcksCompanion(
      id: Value(id),
      messageId: Value(messageId),
      trigramme: Value(trigramme),
      seenAt: Value(seenAt),
    );
  }

  factory ChefMessageAck.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChefMessageAck(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<int>(json['messageId']),
      trigramme: serializer.fromJson<String>(json['trigramme']),
      seenAt: serializer.fromJson<DateTime>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<int>(messageId),
      'trigramme': serializer.toJson<String>(trigramme),
      'seenAt': serializer.toJson<DateTime>(seenAt),
    };
  }

  ChefMessageAck copyWith(
          {int? id, int? messageId, String? trigramme, DateTime? seenAt}) =>
      ChefMessageAck(
        id: id ?? this.id,
        messageId: messageId ?? this.messageId,
        trigramme: trigramme ?? this.trigramme,
        seenAt: seenAt ?? this.seenAt,
      );
  @override
  String toString() {
    return (StringBuffer('ChefMessageAck(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('trigramme: $trigramme, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, messageId, trigramme, seenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChefMessageAck &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.trigramme == this.trigramme &&
          other.seenAt == this.seenAt);
}

class ChefMessageAcksCompanion extends UpdateCompanion<ChefMessageAck> {
  final Value<int> id;
  final Value<int> messageId;
  final Value<String> trigramme;
  final Value<DateTime> seenAt;
  const ChefMessageAcksCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.trigramme = const Value.absent(),
    this.seenAt = const Value.absent(),
  });
  ChefMessageAcksCompanion.insert({
    this.id = const Value.absent(),
    required int messageId,
    required String trigramme,
    this.seenAt = const Value.absent(),
  })  : messageId = Value(messageId),
        trigramme = Value(trigramme);
  static Insertable<ChefMessageAck> custom({
    Expression<int>? id,
    Expression<int>? messageId,
    Expression<String>? trigramme,
    Expression<DateTime>? seenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (trigramme != null) 'trigramme': trigramme,
      if (seenAt != null) 'seen_at': seenAt,
    });
  }

  ChefMessageAcksCompanion copyWith(
      {Value<int>? id,
      Value<int>? messageId,
      Value<String>? trigramme,
      Value<DateTime>? seenAt}) {
    return ChefMessageAcksCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      trigramme: trigramme ?? this.trigramme,
      seenAt: seenAt ?? this.seenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (trigramme.present) {
      map['trigramme'] = Variable<String>(trigramme.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<DateTime>(seenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChefMessageAcksCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('trigramme: $trigramme, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }
}

class $PlanningEventsTable extends PlanningEvents
    with TableInfo<$PlanningEventsTable, PlanningEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanningEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userMeta = const VerificationMeta('user');
  @override
  late final GeneratedColumn<String> user = GeneratedColumn<String>(
      'user', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 3),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _typeEventMeta =
      const VerificationMeta('typeEvent');
  @override
  late final GeneratedColumn<String> typeEvent = GeneratedColumn<String>(
      'type_event', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 2, maxTextLength: 4),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _dateStartMeta =
      const VerificationMeta('dateStart');
  @override
  late final GeneratedColumn<DateTime> dateStart = GeneratedColumn<DateTime>(
      'date_start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _dateEndMeta =
      const VerificationMeta('dateEnd');
  @override
  late final GeneratedColumn<DateTime> dateEnd = GeneratedColumn<DateTime>(
      'date_end', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _firestoreIdMeta =
      const VerificationMeta('firestoreId');
  @override
  late final GeneratedColumn<String> firestoreId = GeneratedColumn<String>(
      'firestore_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
      'rank', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, user, typeEvent, dateStart, dateEnd, uid, firestoreId, rank];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planning_events';
  @override
  VerificationContext validateIntegrity(Insertable<PlanningEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user')) {
      context.handle(
          _userMeta, user.isAcceptableOrUnknown(data['user']!, _userMeta));
    } else if (isInserting) {
      context.missing(_userMeta);
    }
    if (data.containsKey('type_event')) {
      context.handle(_typeEventMeta,
          typeEvent.isAcceptableOrUnknown(data['type_event']!, _typeEventMeta));
    } else if (isInserting) {
      context.missing(_typeEventMeta);
    }
    if (data.containsKey('date_start')) {
      context.handle(_dateStartMeta,
          dateStart.isAcceptableOrUnknown(data['date_start']!, _dateStartMeta));
    } else if (isInserting) {
      context.missing(_dateStartMeta);
    }
    if (data.containsKey('date_end')) {
      context.handle(_dateEndMeta,
          dateEnd.isAcceptableOrUnknown(data['date_end']!, _dateEndMeta));
    } else if (isInserting) {
      context.missing(_dateEndMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    }
    if (data.containsKey('firestore_id')) {
      context.handle(
          _firestoreIdMeta,
          firestoreId.isAcceptableOrUnknown(
              data['firestore_id']!, _firestoreIdMeta));
    }
    if (data.containsKey('rank')) {
      context.handle(
          _rankMeta, rank.isAcceptableOrUnknown(data['rank']!, _rankMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanningEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanningEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      user: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user'])!,
      typeEvent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type_event'])!,
      dateStart: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_start'])!,
      dateEnd: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_end'])!,
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid'])!,
      firestoreId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firestore_id']),
      rank: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rank']),
    );
  }

  @override
  $PlanningEventsTable createAlias(String alias) {
    return $PlanningEventsTable(attachedDatabase, alias);
  }
}

class PlanningEvent extends DataClass implements Insertable<PlanningEvent> {
  final int id;
  final String user;
  final String typeEvent;
  final DateTime dateStart;
  final DateTime dateEnd;
  final String uid;
  final String? firestoreId;
  final int? rank;
  const PlanningEvent(
      {required this.id,
      required this.user,
      required this.typeEvent,
      required this.dateStart,
      required this.dateEnd,
      required this.uid,
      this.firestoreId,
      this.rank});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user'] = Variable<String>(user);
    map['type_event'] = Variable<String>(typeEvent);
    map['date_start'] = Variable<DateTime>(dateStart);
    map['date_end'] = Variable<DateTime>(dateEnd);
    map['uid'] = Variable<String>(uid);
    if (!nullToAbsent || firestoreId != null) {
      map['firestore_id'] = Variable<String>(firestoreId);
    }
    if (!nullToAbsent || rank != null) {
      map['rank'] = Variable<int>(rank);
    }
    return map;
  }

  PlanningEventsCompanion toCompanion(bool nullToAbsent) {
    return PlanningEventsCompanion(
      id: Value(id),
      user: Value(user),
      typeEvent: Value(typeEvent),
      dateStart: Value(dateStart),
      dateEnd: Value(dateEnd),
      uid: Value(uid),
      firestoreId: firestoreId == null && nullToAbsent
          ? const Value.absent()
          : Value(firestoreId),
      rank: rank == null && nullToAbsent ? const Value.absent() : Value(rank),
    );
  }

  factory PlanningEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanningEvent(
      id: serializer.fromJson<int>(json['id']),
      user: serializer.fromJson<String>(json['user']),
      typeEvent: serializer.fromJson<String>(json['typeEvent']),
      dateStart: serializer.fromJson<DateTime>(json['dateStart']),
      dateEnd: serializer.fromJson<DateTime>(json['dateEnd']),
      uid: serializer.fromJson<String>(json['uid']),
      firestoreId: serializer.fromJson<String?>(json['firestoreId']),
      rank: serializer.fromJson<int?>(json['rank']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'user': serializer.toJson<String>(user),
      'typeEvent': serializer.toJson<String>(typeEvent),
      'dateStart': serializer.toJson<DateTime>(dateStart),
      'dateEnd': serializer.toJson<DateTime>(dateEnd),
      'uid': serializer.toJson<String>(uid),
      'firestoreId': serializer.toJson<String?>(firestoreId),
      'rank': serializer.toJson<int?>(rank),
    };
  }

  PlanningEvent copyWith(
          {int? id,
          String? user,
          String? typeEvent,
          DateTime? dateStart,
          DateTime? dateEnd,
          String? uid,
          Value<String?> firestoreId = const Value.absent(),
          Value<int?> rank = const Value.absent()}) =>
      PlanningEvent(
        id: id ?? this.id,
        user: user ?? this.user,
        typeEvent: typeEvent ?? this.typeEvent,
        dateStart: dateStart ?? this.dateStart,
        dateEnd: dateEnd ?? this.dateEnd,
        uid: uid ?? this.uid,
        firestoreId: firestoreId.present ? firestoreId.value : this.firestoreId,
        rank: rank.present ? rank.value : this.rank,
      );
  @override
  String toString() {
    return (StringBuffer('PlanningEvent(')
          ..write('id: $id, ')
          ..write('user: $user, ')
          ..write('typeEvent: $typeEvent, ')
          ..write('dateStart: $dateStart, ')
          ..write('dateEnd: $dateEnd, ')
          ..write('uid: $uid, ')
          ..write('firestoreId: $firestoreId, ')
          ..write('rank: $rank')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, user, typeEvent, dateStart, dateEnd, uid, firestoreId, rank);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanningEvent &&
          other.id == this.id &&
          other.user == this.user &&
          other.typeEvent == this.typeEvent &&
          other.dateStart == this.dateStart &&
          other.dateEnd == this.dateEnd &&
          other.uid == this.uid &&
          other.firestoreId == this.firestoreId &&
          other.rank == this.rank);
}

class PlanningEventsCompanion extends UpdateCompanion<PlanningEvent> {
  final Value<int> id;
  final Value<String> user;
  final Value<String> typeEvent;
  final Value<DateTime> dateStart;
  final Value<DateTime> dateEnd;
  final Value<String> uid;
  final Value<String?> firestoreId;
  final Value<int?> rank;
  const PlanningEventsCompanion({
    this.id = const Value.absent(),
    this.user = const Value.absent(),
    this.typeEvent = const Value.absent(),
    this.dateStart = const Value.absent(),
    this.dateEnd = const Value.absent(),
    this.uid = const Value.absent(),
    this.firestoreId = const Value.absent(),
    this.rank = const Value.absent(),
  });
  PlanningEventsCompanion.insert({
    this.id = const Value.absent(),
    required String user,
    required String typeEvent,
    required DateTime dateStart,
    required DateTime dateEnd,
    this.uid = const Value.absent(),
    this.firestoreId = const Value.absent(),
    this.rank = const Value.absent(),
  })  : user = Value(user),
        typeEvent = Value(typeEvent),
        dateStart = Value(dateStart),
        dateEnd = Value(dateEnd);
  static Insertable<PlanningEvent> custom({
    Expression<int>? id,
    Expression<String>? user,
    Expression<String>? typeEvent,
    Expression<DateTime>? dateStart,
    Expression<DateTime>? dateEnd,
    Expression<String>? uid,
    Expression<String>? firestoreId,
    Expression<int>? rank,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (user != null) 'user': user,
      if (typeEvent != null) 'type_event': typeEvent,
      if (dateStart != null) 'date_start': dateStart,
      if (dateEnd != null) 'date_end': dateEnd,
      if (uid != null) 'uid': uid,
      if (firestoreId != null) 'firestore_id': firestoreId,
      if (rank != null) 'rank': rank,
    });
  }

  PlanningEventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? user,
      Value<String>? typeEvent,
      Value<DateTime>? dateStart,
      Value<DateTime>? dateEnd,
      Value<String>? uid,
      Value<String?>? firestoreId,
      Value<int?>? rank}) {
    return PlanningEventsCompanion(
      id: id ?? this.id,
      user: user ?? this.user,
      typeEvent: typeEvent ?? this.typeEvent,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      uid: uid ?? this.uid,
      firestoreId: firestoreId ?? this.firestoreId,
      rank: rank ?? this.rank,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (user.present) {
      map['user'] = Variable<String>(user.value);
    }
    if (typeEvent.present) {
      map['type_event'] = Variable<String>(typeEvent.value);
    }
    if (dateStart.present) {
      map['date_start'] = Variable<DateTime>(dateStart.value);
    }
    if (dateEnd.present) {
      map['date_end'] = Variable<DateTime>(dateEnd.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (firestoreId.present) {
      map['firestore_id'] = Variable<String>(firestoreId.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanningEventsCompanion(')
          ..write('id: $id, ')
          ..write('user: $user, ')
          ..write('typeEvent: $typeEvent, ')
          ..write('dateStart: $dateStart, ')
          ..write('dateEnd: $dateEnd, ')
          ..write('uid: $uid, ')
          ..write('firestoreId: $firestoreId, ')
          ..write('rank: $rank')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, Notification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 20),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
      'group', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 4, maxTextLength: 6),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, type, payload, group, isRead, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(Insertable<Notification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    if (data.containsKey('group')) {
      context.handle(
          _groupMeta, group.isAcceptableOrUnknown(data['group']!, _groupMeta));
    } else if (isInserting) {
      context.missing(_groupMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notification(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload']),
      group: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group'])!,
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class Notification extends DataClass implements Insertable<Notification> {
  final int id;
  final String type;
  final String? payload;
  final String group;
  final bool isRead;
  final DateTime timestamp;
  const Notification(
      {required this.id,
      required this.type,
      this.payload,
      required this.group,
      required this.isRead,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['group'] = Variable<String>(group);
    map['is_read'] = Variable<bool>(isRead);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      type: Value(type),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      group: Value(group),
      isRead: Value(isRead),
      timestamp: Value(timestamp),
    );
  }

  factory Notification.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Notification(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      payload: serializer.fromJson<String?>(json['payload']),
      group: serializer.fromJson<String>(json['group']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'payload': serializer.toJson<String?>(payload),
      'group': serializer.toJson<String>(group),
      'isRead': serializer.toJson<bool>(isRead),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  Notification copyWith(
          {int? id,
          String? type,
          Value<String?> payload = const Value.absent(),
          String? group,
          bool? isRead,
          DateTime? timestamp}) =>
      Notification(
        id: id ?? this.id,
        type: type ?? this.type,
        payload: payload.present ? payload.value : this.payload,
        group: group ?? this.group,
        isRead: isRead ?? this.isRead,
        timestamp: timestamp ?? this.timestamp,
      );
  @override
  String toString() {
    return (StringBuffer('Notification(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('group: $group, ')
          ..write('isRead: $isRead, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, payload, group, isRead, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notification &&
          other.id == this.id &&
          other.type == this.type &&
          other.payload == this.payload &&
          other.group == this.group &&
          other.isRead == this.isRead &&
          other.timestamp == this.timestamp);
}

class NotificationsCompanion extends UpdateCompanion<Notification> {
  final Value<int> id;
  final Value<String> type;
  final Value<String?> payload;
  final Value<String> group;
  final Value<bool> isRead;
  final Value<DateTime> timestamp;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.payload = const Value.absent(),
    this.group = const Value.absent(),
    this.isRead = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  NotificationsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    this.payload = const Value.absent(),
    required String group,
    this.isRead = const Value.absent(),
    this.timestamp = const Value.absent(),
  })  : type = Value(type),
        group = Value(group);
  static Insertable<Notification> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? payload,
    Expression<String>? group,
    Expression<bool>? isRead,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (payload != null) 'payload': payload,
      if (group != null) 'group': group,
      if (isRead != null) 'is_read': isRead,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  NotificationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? type,
      Value<String?>? payload,
      Value<String>? group,
      Value<bool>? isRead,
      Value<DateTime>? timestamp}) {
    return NotificationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      group: group ?? this.group,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('group: $group, ')
          ..write('isRead: $isRead, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $AirportsTable extends Airports with TableInfo<$AirportsTable, Airport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AirportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 4, maxTextLength: 4),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [code, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'airports';
  @override
  VerificationContext validateIntegrity(Insertable<Airport> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  Airport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Airport(
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $AirportsTable createAlias(String alias) {
    return $AirportsTable(attachedDatabase, alias);
  }
}

class Airport extends DataClass implements Insertable<Airport> {
  final String code;
  final String name;
  const Airport({required this.code, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    return map;
  }

  AirportsCompanion toCompanion(bool nullToAbsent) {
    return AirportsCompanion(
      code: Value(code),
      name: Value(name),
    );
  }

  factory Airport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Airport(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
    };
  }

  Airport copyWith({String? code, String? name}) => Airport(
        code: code ?? this.code,
        name: name ?? this.name,
      );
  @override
  String toString() {
    return (StringBuffer('Airport(')
          ..write('code: $code, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Airport && other.code == this.code && other.name == this.name);
}

class AirportsCompanion extends UpdateCompanion<Airport> {
  final Value<String> code;
  final Value<String> name;
  final Value<int> rowid;
  const AirportsCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AirportsCompanion.insert({
    required String code,
    required String name,
    this.rowid = const Value.absent(),
  })  : code = Value(code),
        name = Value(name);
  static Insertable<Airport> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AirportsCompanion copyWith(
      {Value<String>? code, Value<String>? name, Value<int>? rowid}) {
    return AirportsCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AirportsCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $UsersTable users = $UsersTable(this);
  late final $MissionsTable missions = $MissionsTable(this);
  late final $ChefMessagesTable chefMessages = $ChefMessagesTable(this);
  late final $ChefMessageAcksTable chefMessageAcks =
      $ChefMessageAcksTable(this);
  late final $PlanningEventsTable planningEvents = $PlanningEventsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $AirportsTable airports = $AirportsTable(this);
  late final PlanningDao planningDao = PlanningDao(this as AppDatabase);
  late final ChefMessageDao chefMessageDao =
      ChefMessageDao(this as AppDatabase);
  late final NotificationDao notificationDao =
      NotificationDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        users,
        missions,
        chefMessages,
        chefMessageAcks,
        planningEvents,
        notifications,
        airports
      ];
}
