// lib/models/user_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String trigramme;
  final String passwordHash;
  final String role;
  final String group;
  final String? fullName;
  final String? phone;
  final String? email;

  UserModel({
    required this.trigramme,
    required this.passwordHash,
    required this.role,
    required this.group,
    this.fullName,
    this.phone,
    this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
