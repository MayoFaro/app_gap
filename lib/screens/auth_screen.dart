import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../data/user_service.dart'; // <-- service hybride Firestore + cache
import 'register_screen.dart';
import 'home_screen.dart';

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

  Future<void> _login() async {
    final emailInput = _emailCtrl.text.trim();
    debugPrint('DEBUG Auth: Login attempt for email=$emailInput');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Authentification Firebase
      final cred = await fbAuth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: emailInput, password: _passCtrl.text);
      final firebaseUser = cred.user;
      if (firebaseUser == null) throw Exception('Échec de l’authentification');

      // Récupération de l'utilisateur (Firestore + fallback cache)
      final user = await UserService(db: widget.db).findUserByEmail(emailInput); //The static method 'findUserByEmail' can't be accessed through an instance.
      if (user == null) throw Exception("Aucun utilisateur trouvé pour cet email");

      // Sauvegarde dans les SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userTrigram', user.trigramme);//The getter 'trigramme' isn't defined for the type 'Map<String, dynamic>'.
      await prefs.setString('userGroup', user.group);//The getter 'group' isn't defined for the type 'Map<String, dynamic>'.
      await prefs.setString('fonction', user.fonction);//The getter 'fonction' isn't defined for the type 'Map<String, dynamic>'.
      await prefs.setString('role', user.role);//The getter 'role' isn't defined for the type 'Map<String, dynamic>'.
      await prefs.setBool('isAdmin', user.isAdmin);//The getter 'isAdmin' isn't defined for the type 'Map<String, dynamic>'.

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(db: widget.db)),
      );
    } catch (e) {
      debugPrint('DEBUG Auth: Login failed: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(db: widget.db)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
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
