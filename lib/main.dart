// lib/main.dart
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

  // Initialisation de la BDD et importation de users.json
  final db = AppDatabase();
  final existingUsers = await db.select(db.users).get();
  if (existingUsers.isEmpty) {
    final raw = await rootBundle.loadString('assets/users.json');
    final List<dynamic> list = json.decode(raw);
    for (var u in list) {
      await db.into(db.users).insert(
        UsersCompanion.insert(
          trigramme:    u['trigramme'] as String,
          passwordHash: u['passwordHash'] as String,
          role:         u['role'] as String,
          group:        u['group'] as String,
          fullName:     Value(u['fullName'] as String),
          phone:        Value(u['phone'] as String),
          email:        Value(u['email'] as String),
          isAdmin:      Value(u['isAdmin'] as bool),
        ),
      );
    }
  }

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
