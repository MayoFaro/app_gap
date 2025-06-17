import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';



class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 🔧 À appeler une fois Firebase initialisé
  Future<void> initFCM({required String userTrigramme}) async {
    // 🔐 Permissions
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 📲 Token
    final fcmToken = await _messaging.getToken();
    print('✅ FCM token reçu : $fcmToken');

    if (fcmToken != null) {
      print('✅ FCM token : $fcmToken');
      await _saveTokenToFirestore(userTrigramme, fcmToken);
    }

    // 🔁 Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 Nouveau token reçu : $newToken');
      _saveTokenToFirestore(userTrigramme, newToken);
    });

    // 📨 Abonnement au topic "all_users"
    await _messaging.subscribeToTopic('all_users');
    print('📬 Abonné au topic all_users');
  }


  /// ☁️ Enregistrer le token FCM dans Firestore
  Future<void> _saveTokenToFirestore(String trigramme, String token) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');

      // 🔎 On crée ou met à jour le document dont l'ID est le trigramme
      await users.doc(trigramme).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ fcmToken mis à jour dans Firestore pour $trigramme');
    } catch (e) {
      print('❌ Erreur enregistrement token Firestore : $e');
    }
  }


}
