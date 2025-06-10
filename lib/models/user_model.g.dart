// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  trigramme: json['trigramme'] as String,
  passwordHash: json['passwordHash'] as String,
  role: json['role'] as String,
  group: json['group'] as String,
  fullName: json['fullName'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'trigramme': instance.trigramme,
  'passwordHash': instance.passwordHash,
  'role': instance.role,
  'group': instance.group,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'email': instance.email,
};
