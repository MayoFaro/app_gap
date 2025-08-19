// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import 'home_screen.dart';

/// Inscription :
/// 1) crée le compte FirebaseAuth
/// 2) retrouve le profil existant dans la collection `users` (via email)
/// 3) crée /users/{uid} dans Firestore (copie du profil existant)
/// 4) stocke le contexte utilisateur en SharedPreferences
/// 5) navigue vers HomeScreen
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
    final psw = _passCtrl.text.trim();

    fbAuth.User? fbUser;

    try {
      debugPrint('REGISTER: start for email="$email"');

      // 1) Création FirebaseAuth
      final cred = await fbAuth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: psw);
      fbUser = cred.user;
      if (fbUser == null) {
        throw Exception('Inscription Firebase échouée (user null)');
      }
      debugPrint('REGISTER: FirebaseAuth OK, uid=${fbUser.uid}');

      // 2) Lookup profil existant dans Firestore (via email)
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("Aucun profil pré-enregistré trouvé pour cet email. Contactez l'administrateur.");
      }

      final existingProfile = query.docs.first.data();
      debugPrint('REGISTER: existing Firestore profile found -> $existingProfile');

      // 3) Écrit /users/{uid} sur Firestore (copie du profil existant)
      await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).set({
        ...existingProfile,
        'email': email, // on force l’email pour cohérence
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('REGISTER: Firestore /users/${fbUser.uid} created from existing profile');

      // 4) SharedPreferences (clés attendues ailleurs dans l’app)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userUid', fbUser.uid);
      await prefs.setString('userTrigram', (existingProfile['trigramme'] ?? '---').toString());
      await prefs.setString('userGroup', (existingProfile['group'] ?? '---').toString());
      await prefs.setString('userFunction', (existingProfile['fonction'] ?? '---').toString());
      await prefs.setString('userRole', (existingProfile['role'] ?? '').toString());
      await prefs.setBool('isAdmin', (existingProfile['isAdmin'] == true));

      debugPrint('REGISTER: prefs saved -> '
          'trig=${prefs.getString('userTrigram')}, '
          'group=${prefs.getString('userGroup')}, '
          'fonction=${prefs.getString('userFunction')}, '
          'role=${prefs.getString('userRole')}, '
          'isAdmin=${prefs.getBool('isAdmin')}');

      // 5) Navigation vers Home
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(db: widget.db)),
            (_) => false,
      );
    } on fbAuth.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'weak-password':
          msg = 'Mot de passe trop faible.';
          break;
        case 'email-already-in-use':
          msg = 'Cet email est déjà utilisé.';
          break;
        case 'invalid-email':
          msg = 'Email invalide.';
          break;
        default:
          msg = e.message ?? 'Erreur FirebaseAuth.';
      }
      debugPrint('REGISTER: FirebaseAuthException -> ${e.code} / ${e.message}');
      // si on a créé un user FB mais problème ensuite, on le supprime
      if (fbUser != null) {
        try {
          await fbUser.delete();
          debugPrint('REGISTER: fbUser deleted due to failure');
        } catch (_) {}
      }
      setState(() => _error = msg);
    } catch (e) {
      debugPrint('REGISTER: Exception -> $e');
      if (fbUser != null) {
        try {
          await fbUser.delete();
          debugPrint('REGISTER: fbUser deleted due to failure');
        } catch (_) {}
      }
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
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Entrez un email';
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
                decoration: const InputDecoration(labelText: 'Confirmez le mot de passe'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
                  if (v != _passCtrl.text) return 'Mots de passe différents';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
