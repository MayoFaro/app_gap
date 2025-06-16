// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MissionModel _$MissionModelFromJson(Map<String, dynamic> json) => MissionModel(
      id: (json['id'] as num?)?.toInt(),
      date: DateTime.parse(json['date'] as String),
      hourStart: json['hourStart'] as String,
      hourEnd: json['hourEnd'] as String,
      vecteur: json['vecteur'] as String,
      destinationCode: json['destinationCode'] as String,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String,
      pilote1: json['pilote1'] as String,
      pilote2: json['pilote2'] as String?,
      mec1: json['mec1'] as String?,
      mec2: json['mec2'] as String?,
      actualDeparture: json['actualDeparture'] == null
          ? null
          : DateTime.parse(json['actualDeparture'] as String),
      actualArrival: json['actualArrival'] == null
          ? null
          : DateTime.parse(json['actualArrival'] as String),
    );

Map<String, dynamic> _$MissionModelToJson(MissionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'hourStart': instance.hourStart,
      'hourEnd': instance.hourEnd,
      'vecteur': instance.vecteur,
      'destinationCode': instance.destinationCode,
      'description': instance.description,
      'createdBy': instance.createdBy,
      'pilote1': instance.pilote1,
      'pilote2': instance.pilote2,
      'mec1': instance.mec1,
      'mec2': instance.mec2,
      'actualDeparture': instance.actualDeparture?.toIso8601String(),
      'actualArrival': instance.actualArrival?.toIso8601String(),
    };
