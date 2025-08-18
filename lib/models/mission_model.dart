// lib/models/mission_model.dart
import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory MissionModel.fromJson(Map<String, dynamic> json) =>
      _$MissionModelFromJson(json);

  Map<String, dynamic> toJson() => _$MissionModelToJson(this);

  /// Conversion Firestore → MissionModel
  factory MissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MissionModel(
      id: data['id'],
      date: (data['date'] as Timestamp).toDate(),
      hourStart: data['hourStart'] ?? '',
      hourEnd: data['hourEnd'] ?? '',
      vecteur: data['vecteur'] ?? '',
      destinationCode: data['destinationCode'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      pilote1: data['pilote1'] ?? '',
      pilote2: data['pilote2'],
      mec1: data['mec1'],
      mec2: data['mec2'],
      actualDeparture: data['actualDeparture'] != null
          ? (data['actualDeparture'] as Timestamp).toDate()
          : null,
      actualArrival: data['actualArrival'] != null
          ? (data['actualArrival'] as Timestamp).toDate()
          : null,
    );
  }


  /// Conversion MissionModel → Map (Firestore)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'date': date,
      'hourStart': hourStart,
      'hourEnd': hourEnd,
      'vecteur': vecteur,
      'destinationCode': destinationCode,
      'description': description,
      'createdBy': createdBy,
      'pilote1': pilote1,
      'pilote2': pilote2,
      'mec1': mec1,
      'mec2': mec2,
      'actualDeparture': actualDeparture,
      'actualArrival': actualArrival,
    };
  }
}
