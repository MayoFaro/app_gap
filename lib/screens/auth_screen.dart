import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/user_dao.dart';           // DAO pour accéder à la table Users locale
import 'home_screen.dart';
import 'register_screen.dart';

/// Écran d'authentification par email/mot de passe Firebase + validation locale
class AuthScreen extends StatefulWidget {
  final AppDatabase db;
  const AuthScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Méthode principale de connexion
  Future<void> _login() async {
    final emailInput = _emailCtrl.text.trim();
    debugPrint('DEBUG Auth: tentative de connexion pour email=$emailInput');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1) Authentification Firebase par email/mot de passe
      final cred = await fbAuth.FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailInput,
        password: _passCtrl.text,
      );
      final firebaseUser = cred.user;
      if (firebaseUser == null) {
        throw Exception('Échec de l’authentification Firebase');
      }

      // 2) Vérification locale dans SQLite via UserDao
      final dao = UserDao(widget.db);
      final userRow = await dao.getUserByEmail(emailInput);
      if (userRow == null) {
        throw Exception("Aucun utilisateur trouvé pour cet email");
      }

      // 3) Stockage dans SharedPreferences (permets accès global si besoin)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userTrigram', userRow.trigramme);
      await prefs.setString('userGroup',   userRow.group);
      await prefs.setString('fonction',    userRow.fonction);
      await prefs.setString('role',        userRow.role);
      await prefs.setBool(  'isAdmin',     userRow.isAdmin);

      if (!mounted) return;

      // 4) Navigation vers HomeScreen en passant le flag isAdmin
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            db: widget.db,
            isAdmin: userRow.isAdmin, // passe la valeur lue localement
          ),
        ),
            (route) => false,
      );
    } on fbAuth.FirebaseAuthException catch (e) {
      // Gestion des erreurs Firebase (mauvais mdp, utilisateur inexistant, etc.)
      debugPrint('DEBUG Auth: FirebaseAuthException -> ${e.code}');
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      // Erreurs génériques (DAO, SQLite, logique métier, etc.)
      debugPrint('DEBUG Auth: erreur -> $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Redirection vers l'écran d'inscription
  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(db: widget.db)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
              children: [
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Se connecter'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _goToRegister,
                  child: const Text("S'inscrire"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
