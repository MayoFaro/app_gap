// lib/models/mission_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'mission_model.g.dart';

@JsonSerializable()
class MissionModel {
  final int? id;
  final DateTime date;
  final String hourStart;
  final String hourEnd;
  final String vecteur;
  final String destinationCode;
  final String? description;
  final String createdBy;
  final String pilote1;
  final String? pilote2;
  final String? mec1;
  final String? mec2;
  final DateTime? actualDeparture;
  final DateTime? actualArrival;

  MissionModel({
    this.id,
    required this.date,
    required this.hourStart,
    required this.hourEnd,
    required this.vecteur,
    required this.destinationCode,
    this.description,
    required this.createdBy,
    required this.pilote1,
    this.pilote2,
    this.mec1,
    this.mec2,
    this.actualDeparture,
    this.actualArrival,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) => _$MissionModelFromJson(json);
  Map<String, dynamic> toJson() => _$MissionModelToJson(this);
}
