import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import 'home_screen.dart';

/// Écran d'inscription d'un nouvel utilisateur (profil pré-défini dans users.json)
class RegisterScreen extends StatefulWidget {
  final AppDatabase db;
  const RegisterScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    debugPrint('DEBUG Register: tentative inscription for email=$email');

    try {
      // Création du compte Firebase
      final cred = await fbAuth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) throw Exception('Inscription Firebase échouée');

      // Debug: lister tous les emails en base JSON
      final allUsers = await widget.db.select(widget.db.users).get();
      debugPrint('DEBUG Register: users.json emails=${allUsers.map((u) => u.email).toList()}');

      // Lookup profil JSON
      final row = await (widget.db.select(widget.db.users)
        ..where((u) => u.email.equals(email)))
          .getSingleOrNull();
      debugPrint('DEBUG Register: JSON-DB lookup row=$row');

      if (row == null) {
        // Aucun profil associé, on supprime le compte Firebase
        await fbUser.delete();
        throw Exception('Aucun profil utilisateur associé à cet email.');
      }

      // Stockage des prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userTrigram', row.trigramme);
      await prefs.setString('userGroup', row.group);
      await prefs.setString('fonction', row.fonction);
      await prefs.setString('role', row.role);
      await prefs.setBool('isAdmin', row.isAdmin);

      if (!mounted) return;
      // Aller à l'écran home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(db: widget.db)),
            (route) => false,
      );
    } catch (e) {
      debugPrint('DEBUG Register: erreur -> $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,    // pas de majuscule auto
                autocorrect: false,                             // pas de correction automatique
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Entrez un email';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Entrez un mot de passe';
                  if (v.length < 6) return 'Au moins 6 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                decoration: const InputDecoration(labelText: 'Confirmez mot de passe'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
                  if (v != _passCtrl.text) return 'Les mots de passe ne correspondent pas';
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
                  : ElevatedButton(
                onPressed: _onRegister,
                child: const Text('Créer le compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
