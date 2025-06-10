// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_service.dart';
import '../data/app_database.dart';
import 'home_screen.dart';
/*
class LoginScreen extends StatefulWidget {
  final String initialEmail;
  const LoginScreen({Key? key, required this.initialEmail}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = widget.initialEmail.trim();
    final psw = _passwordController.text.trim();

    try {
      // Tentative de connexion Firebase
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: psw,
      );

      // Si connexion Firebase réussie, on tente de charger les infos JSON associées à cet email
      final userInfo = await UserService.findByEmail(email);
      if (userInfo == null) {
        // Cas très improbable si le JSON n’a pas d’entrée pour cet email
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erreur'),
            content: const Text('Aucun profil utilisateur associé à cet email.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Stocke en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userTrigram', userInfo.trigramme);
      await prefs.setString('userGroup', userInfo.group);

      // Redirection vers HomeScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            db: AppDatabase(),
            userTrigram: userInfo.trigramme,
            userGroup: userInfo.group,
            isAdmin: userInfo.isAdmin,
          ),
        ),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'wrong-password') {
        message = 'Mot de passe incorrect';
      } else if (e.code == 'user-not-found') {
        message = 'Aucun compte trouvé pour cet email';
      } else {
        message = e.message ?? 'Erreur lors de la connexion';
      }
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erreur'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
              Text('Email : ${widget.initialEmail}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Entrez votre mot de passe' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _onLogin, child: const Text('Se connecter')),
            ],
          ),
        ),
      ),
    );
  }
}
*/