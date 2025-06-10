
// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../data/app_database.dart';
import 'home_screen.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthMode _mode = AuthMode.signIn;
  bool _isLoading = false;
  String? _error;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pwdCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  void _toggleMode() {
    setState(() {
      _mode = (_mode == AuthMode.signIn) ? AuthMode.signUp : AuthMode.signIn;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    setState(() { _isLoading = true; _error = null; });

    try {
      UserCredential cred;
      if (_mode == AuthMode.signUp) {
        cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pwd);
      } else {
        cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pwd);
      }
      // Sauvegarde des infos en prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', email);
      // NAVIGATION vers Home
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(db: AppDatabase())),
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Erreur inattendue'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = (_mode == AuthMode.signUp);
    return Scaffold(
      appBar: AppBar(title: Text(isSignUp ? 'Inscription' : 'Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v!=null && v.contains('@')) ? null : 'Email invalide',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pwdCtrl,
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                    obscureText: true,
                    validator: (v) => (v!=null && v.length>=4) ? null : 'Au moins 4 caractères',
                  ),
                  if (isSignUp) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      decoration: const InputDecoration(labelText: 'Confirmez le mot de passe'),
                      obscureText: true,
                      validator: (v) => v==_pwdCtrl.text ? null : 'Ne correspond pas',
                    ),
                  ],
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _submit,
                    child: Text(isSignUp ? 'S’inscrire' : 'Se connecter'),
                  ),
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(isSignUp
                        ? 'Vous avez déjà un compte ?'
                        : 'Créer un compte'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
