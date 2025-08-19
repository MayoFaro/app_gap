// lib/main.dart
//
// Version alignée sur ta structure initiale, avec 2 améliorations:
// 1) Initialisation Firebase via firebase_options (plus robuste multi-plateforme)
// 2) Filet de sécurité dans AuthGate : si l'utilisateur est connecté mais que
//    les SharedPreferences ne contiennent pas encore trigramme/group/fonction,
//    on les récupère depuis Firestore avant d'ouvrir HomeScreen.
//
// Choc de simplification : on débranche complètement users.json.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'data/app_database.dart' hide User;
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase avec options explicites (recommandé FlutterFire)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Base locale
  final db = AppDatabase();

  // 🚫 Suppression du chargement / synchro users.json
  // Firestore est désormais l’unique source de vérité.

  runApp(AppGAP(db: db));
}

/// Widget principal
class AppGAP extends StatelessWidget {
  final AppDatabase db;
  const AppGAP({Key? key, required this.db}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'appGAP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(db: db),
    );
  }
}

/// Gère la redirection selon l'état d'authentification Firebase
/// Amélioration: si user connecté MAIS prefs vides, on regarnit depuis Firestore
class AuthGate extends StatefulWidget {
  final AppDatabase db;
  const AuthGate({Key? key, required this.db}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    debugPrint('▶ AuthGate.initState(): currentUser = ${fbAuth.FirebaseAuth.instance.currentUser}');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fbAuth.User?>(
      stream: fbAuth.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          // Pas connecté → écran de login
          return AuthScreen(db: widget.db);
        }

        // Connecté → on s'assure que les prefs ont trigramme/group/fonction/isAdmin
        return FutureBuilder<SharedPreferences>(
          future: _ensurePrefsReady(firebaseUser.uid),
          builder: (c, prefSnap) {
            if (prefSnap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final prefs = prefSnap.data!;
            final isAdmin = prefs.getBool('isAdmin') ?? false;
            return HomeScreen(db: widget.db, isAdmin: isAdmin);
          },
        );
      },
    );
  }

  /// Si les SharedPreferences ne contiennent pas encore les infos utilisateur,
  /// on les relit depuis Firestore: users/{uid}.
  Future<SharedPreferences> _ensurePrefsReady(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    final hasTrig = (prefs.getString('userTrigram') ?? '').trim().isNotEmpty;
    final hasGrp  = (prefs.getString('userGroup') ?? '').trim().isNotEmpty;
    final hasFon  = (prefs.getString('userFonction') ?? '').trim().isNotEmpty;

    if (hasTrig && hasGrp && hasFon && prefs.containsKey('isAdmin')) {
      return prefs;
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        final data = snap.data()!;
        final trigramme = (data['trigramme'] ?? '---').toString();
        final group     = (data['group'] ?? '---').toString();
        final fonction  = (data['fonction'] ?? '---').toString();

        final role = (data['role'] ?? '').toString().toLowerCase();
        final isAdmin = (data['isAdmin'] == true) || (role == 'admin');

        await prefs.setString('userTrigram', trigramme);
        await prefs.setString('userGroup', group);
        await prefs.setString('userFonction', fonction);
        await prefs.setBool('isAdmin', isAdmin);

        if (data['email'] != null) {
          await prefs.setString('userEmail', data['email'].toString());
        }
        if (data['fullName'] != null) {
          await prefs.setString('userFullName', data['fullName'].toString());
        }
      } else {
        debugPrint('⚠️ Firestore: users/$uid inexistant, prefs non complétées');
      }
    } catch (e, st) {
      debugPrint('⚠️ _ensurePrefsReady error: $e\n$st');
    }

    return prefs;
  }
}
