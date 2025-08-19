// File: lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import 'register_screen.dart';
import 'home_screen.dart';

/// Écran d'authentification avec "auto-provisioning" du profil Firestore.
/// - Au login, on s'assure qu'un doc /users/{uid} existe.
/// - On stocke ensuite le profil en SharedPreferences.
class AuthScreen extends StatefulWidget {
  final AppDatabase db;
  const AuthScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
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

  // ----------------------------------------------------------------------------
  // Helper: garantit l’existence d’un /users/{uid}.
  // Si inexistant → on initialise avec email et timestamps.
  // Sinon → on renvoie tel quel.
  // ----------------------------------------------------------------------------
  Future<Map<String, dynamic>> _ensureUserDocument({
    required fbAuth.User fbUser,
    required String email,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(fbUser.uid);
    final snap = await userRef.get();

    if (!snap.exists) {
      // Ici, on NE crée plus de fallback.
      throw Exception("Profil utilisateur inexistant pour uid=${fbUser.uid}. "
          "L'inscription n'a pas correctement provisionné le compte.");
    }

    final data = snap.data()!;

    // On force la cohérence de l’email si jamais il a changé
    if (data['email'] != email) {
      await userRef.set({'email': email, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }

    debugPrint('DEBUG Auth.ensureUserDoc: loaded from Firestore -> $data');
    return {...data, 'email': email};
  }


  // ----------------------------------------------------------------------------
  // Login flow
  // ----------------------------------------------------------------------------
  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      // 1) Connexion FirebaseAuth
      final cred = await fbAuth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final fbUser = cred.user;
      if (fbUser == null) {
        throw Exception('Échec de la connexion Firebase');
      }

      // 2) Garantit le doc /users/{uid}
      final profile = await _ensureUserDocument(fbUser: fbUser, email: email);

      // 3) Stocke les infos utiles en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userUid', fbUser.uid);
      await prefs.setString('userTrigram', (profile['trigramme'] as String? ?? '---'));
      await prefs.setString('userRole', (profile['role'] as String? ?? '').toLowerCase());
      await prefs.setString('userFonction', (profile['fonction'] as String? ?? '').toLowerCase());
      await prefs.setString('userGroup', (profile['group'] as String? ?? '').toLowerCase());
      await prefs.setBool('isAdmin', (profile['isAdmin'] as bool?) ?? false);

      debugPrint(
        'DEBUG Auth.login: prefs set = '
            'trigram:${prefs.getString('userTrigram')}, '
            'group:${prefs.getString('userGroup')}, '
            'fonction:${prefs.getString('userFonction')}, '
            'role:${prefs.getString('userRole')}, '
            'isAdmin:${prefs.getBool('isAdmin')}',
      );

      // 4) Navigation vers Home
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(db: widget.db)),
            (route) => false,
      );
    } catch (e) {
      debugPrint('ERROR Auth.login: $e');
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
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Entrez un email';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Mot de passe
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Entrez un mot de passe';
                  return null;
                },
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
                    onPressed: _onLogin,
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
      ),
    );
  }
}
