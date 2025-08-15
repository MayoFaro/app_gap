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
/// - Si le JSON local (Drift.Users) a été modifié, on merge les changements côté Firestore.
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
  // Helper: garantit l’existence d’un /users/{uid}, le crée depuis la table
  // locale (users.json importé) si nécessaire, et merge si le local a changé.
  // Renvoie le "profil final" utilisé pour la session.
  // ----------------------------------------------------------------------------
  Future<Map<String, dynamic>> _ensureUserDocument({
    required fbAuth.User fbUser,
    required String email,
  }) async {
    final usersColl = FirebaseFirestore.instance.collection('users');
    final userRef = usersColl.doc(fbUser.uid);

    // 1) Cherche profil "local" (table Drift.Users) par email
    final localRow = await (widget.db.select(widget.db.users)
      ..where((u) => u.email.equals(email)))
        .getSingleOrNull();

    debugPrint('DEBUG Auth.ensureUserDoc: localRow=$localRow');

    // 2) Lit le doc Firestore
    final remoteSnap = await userRef.get();
    Map<String, dynamic>? remote = remoteSnap.data();

    // 3) Si le doc Firestore n'existe pas, on tente de le créer depuis le local
    if (!remoteSnap.exists) {
      if (localRow == null) {
        // Aucun local et aucun remote: on ne sait pas provisionner ce compte
        throw Exception(
          "Profil introuvable: aucun mapping local pour l'email et aucun doc Firestore /users/${fbUser.uid}.",
        );
      }

      final toCreate = <String, dynamic>{
        'trigramme': localRow.trigramme,
        'fonction': localRow.fonction, // 'chef', 'cdt', etc.
        'role': localRow.role,         // 'pilote' | 'mecano'
        'group': localRow.group,       // 'avion' | 'helico'
        'email': email,
        'isAdmin': localRow.isAdmin,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await userRef.set(toCreate, SetOptions(merge: true));
      debugPrint('DEBUG Auth.ensureUserDoc: created /users/${fbUser.uid} from local JSON');

      return {
        ...toCreate,
        // createdAt/updatedAt seront des Timestamps côté serveur; on n’en a pas besoin ici
      };
    }

    // 4) Le doc existe: on peut
    //    - l’utiliser tel quel si pas de "localRow"
    //    - ou MERGE si le JSON local a changé (préférence: on fait confiance au local)
    if (localRow == null) {
      // Pas de mapping local (email absent de la table Drift) -> on garde le remote tel quel.
      debugPrint('DEBUG Auth.ensureUserDoc: no local row, keep remote as source of truth.');
      return remote ?? {};
    }

    // Comparaison fine champ par champ
    final patch = <String, dynamic>{};
    void _cmp(String key, String? remoteVal, String localVal) {
      if ((remoteVal ?? '') != localVal) patch[key] = localVal;
    }

    _cmp('trigramme', remote?['trigramme'] as String?, localRow.trigramme);
    _cmp('fonction',  remote?['fonction']  as String?, localRow.fonction);
    _cmp('role',      remote?['role']      as String?, localRow.role);
    _cmp('group',     remote?['group']     as String?, localRow.group);

    final remoteIsAdmin = (remote?['isAdmin'] is bool) ? (remote!['isAdmin'] as bool) : false;
    if (remoteIsAdmin != localRow.isAdmin) {
      patch['isAdmin'] = localRow.isAdmin;
    }

    // On s’assure de stocker l’email
    if ((remote?['email'] as String?) != email) {
      patch['email'] = email;
    }

    if (patch.isNotEmpty) {
      patch['updatedAt'] = FieldValue.serverTimestamp();
      await userRef.set(patch, SetOptions(merge: true));
      debugPrint('DEBUG Auth.ensureUserDoc: merged changes into /users/${fbUser.uid}: $patch');
      // met à jour "remote" pour le retour
      remote = {...?remote, ...patch};
    } else {
      debugPrint('DEBUG Auth.ensureUserDoc: no diff between local JSON and remote doc.');
    }

    return remote ?? {};
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

      // 2) Garantit le doc /users/{uid} (création/merge si besoin)
      final profile = await _ensureUserDocument(fbUser: fbUser, email: email);

      // 3) Stocke les infos utiles en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userUid', fbUser.uid);
      await prefs.setString('userTrigram', (profile['trigramme'] as String? ?? '---'));
      await prefs.setString('userRole', (profile['role'] as String? ?? '').toLowerCase());
      await prefs.setString('userFunction', (profile['fonction'] as String? ?? '').toLowerCase());
      await prefs.setString('userGroup', (profile['group'] as String? ?? '').toLowerCase());
      await prefs.setBool('isAdmin', (profile['isAdmin'] as bool?) ?? false);

      debugPrint(
        'DEBUG Auth.login: prefs set = '
            'trigram:${prefs.getString('userTrigram')}, '
            'group:${prefs.getString('userGroup')}, '
            'fonction:${prefs.getString('userFunction')}, '
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
