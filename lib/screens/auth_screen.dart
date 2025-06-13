import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;

import '../data/app_database.dart';
import 'home_screen.dart';  // Import pour HomeScreen

class AuthScreen extends StatefulWidget {
  final AppDatabase? db; // Injection optionnelle de la BDD

  const AuthScreen({Key? key, this.db}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cred = await fbAuth.FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final user = cred.user;
      if (user == null) throw Exception('Échec de l’authentification');

      final email = user.email!;
      print('DEBUG Auth: connecté avec email=$email');

      // Récupération de la BDD
      final db = widget.db ?? AppDatabase();

      // Lecture de l'utilisateur en base via l'email
      final row = await (db.select(db.users)
        ..where((u) => u.email.equals(email)))
          .getSingleOrNull();
      if (row == null) {
        throw Exception('Aucun utilisateur trouvé pour l’email $email');
      }

      // Préparation des préférences
      final prefs = await SharedPreferences.getInstance();
      // Stockage des informations utiles
      await prefs.setString('userTrigram', row.trigramme);
      await prefs.setString('userGroup', row.group);
      await prefs.setString('fonction', row.fonction); //The getter 'fonction' isn't defined for the type 'User'.
      await prefs.setString('role', row.role);
      await prefs.setBool('isAdmin', row.isAdmin);
      print('DEBUG Auth: prefs stockées = trigram:${row.trigramme}, group:${row.group}, fonction:${row.fonction}, role:${row.role}, isAdmin:${row.isAdmin}');

      // Navigation vers l'écran principal
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(db: db)),
      );
    } catch (e) {
      print('ERROR Auth: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _login,
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}
