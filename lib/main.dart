import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';            // pour rootBundle
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth; // aliasé en fbAuth
import 'package:drift/drift.dart';                // pour Value<T>
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart' hide User;        // on cache User de la BDD
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialisation de la BDD
  final db = AppDatabase();

  // Charger JSON des users
  final raw = await rootBundle.loadString('assets/users.json');
  final List<dynamic> jsonList = json.decode(raw);

  // Comptage actuel dans la BDD
  final existing = await db.select(db.users).get();
  debugPrint('DEBUG main: DB user count = ${existing.length}');
  debugPrint('DEBUG main: JSON user count = ${jsonList.length}');

  // Synchronisation conditionnelle si BDD incomplète
  if (existing.length < jsonList.length) {
    debugPrint('INFO main: synchronisation JSON -> BDD');
    // Vider la table users
    await db.delete(db.users).go();
    // Réinsérer tous les utilisateurs du JSON
    for (final u in jsonList) {
      await db.into(db.users).insert(
        UsersCompanion.insert(
          trigramme:    u['trigramme'] as String,
          passwordHash: u['passwordHash'] as String,
          fonction:     u['fonction'] as String,   // Nouvelle colonne 'fonction'
          role:         u['role'] as String,
          group:        u['group'] as String,
          fullName:     Value(u['fullName'] as String),
          phone:        Value(u['phone'] as String),
          email:        Value(u['email'] as String),
          isAdmin:      Value(u['isAdmin'] as bool),
        ),
      );
    }
  } else {
    debugPrint('INFO main: BDD déjà synchronisée');
  }

  // Lancement de l'application avec la BDD prête
  runApp(AppGAP(db: db));
}

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
    print('▶ AuthGate.initState(): currentUser = ${fbAuth.FirebaseAuth.instance.currentUser}');
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
          return const AuthScreen();
        }
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (c, prefSnap) {
            if (!prefSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return HomeScreen(db: widget.db);
          },
        );
      },
    );
  }
}
